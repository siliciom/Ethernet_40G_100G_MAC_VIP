//******************************************************************//
//                 ETHERNET SCOREBOARD FILE
//
// Implements the Ethernet UVM scoreboard. The scoreboard compares
// expected and observed Ethernet transactions, verifies protocol
// correctness, checks frame integrity, and reports functional
// mismatches and data inconsistencies.
//
// Author: Arun
//******************************************************************//

`uvm_analysis_imp_decl(_ap_1)
`uvm_analysis_imp_decl(_ap_2)

class eth_scb extends uvm_scoreboard;
  `uvm_component_utils(eth_scb)

  uvm_analysis_imp_ap_1#(eth_seq_item, eth_scb) ai_1[`NO_OF_AGENTS];
  uvm_analysis_imp_ap_2#(eth_seq_item, eth_scb) ai_2[`NO_OF_AGENTS];

  eth_seq_item   tx_tr;
  eth_seq_item   rx_tr;
  eth_reg_block  ral_model_1;   // handle, not value

  // TX ARRAY [source_agent_id][destination_agent_id][transaction_number]
  eth_seq_item tx_aa[int][int][int];

  // RX ARRAY [source_agent_id][destination_agent_id][transaction_number]
  eth_seq_item rx_aa[int][int][int];

  int matched_pkt_count = 0;
  bit mac_addr_arr[bit[47:0]];
  bit k;  

  function new(string name = "eth_scb", uvm_component parent = null);
    super.new(name, parent);
    foreach (ai_1[i])
      ai_1[i] = new($sformatf("ai_1[%0d]", i), this);
    foreach (ai_2[i])
      ai_2[i] = new($sformatf("ai_2[%0d]", i), this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  //----------------------------------------------------------------------
  // Receives transmitted Ethernet packets from the monitor.
  // Decodes the source and destination information and stores
  // transactions for future comparison with received packets.
  //----------------------------------------------------------------------
function void write_ap_1(eth_seq_item tx_tr);
    int             src_id;
    int             dst_id;
    int             txn_no;
    uvm_reg_data_t  val;
    uvm_reg_data_t  rx_pfc_ctrl_val;
    eth_seq_item    tx_tr_clone;
    eth_seq_item    tx_tr_clone_mc;

    src_id = source_address(tx_tr);
    txn_no = tx_tr.tx_count;
    val             = ral_model_1.rx_frame_control.get_mirrored_value();
    rx_pfc_ctrl_val = ral_model_1.rx_pfc_control.get_mirrored_value();

    `uvm_info("SCB_ERR_B", $sformatf("err_b flag state: %0d", tx_tr.err_b), UVM_LOW)
    `uvm_info("SCB_RX_FC",
              $sformatf("rx_frame_control mirrored value = 0x%0h (bit4 = %0b)", val, val[4]),
              UVM_LOW)

    if (!(mac_addr_arr.exists(tx_tr.sa)))
      mac_addr_arr[tx_tr.sa] = 1;

    if (val[4] == 1'b1) begin
      `uvm_info("SCB_RX_FC", "Pause-frame processing ENABLED — checking XOFF/XON behavior", UVM_MEDIUM)
    end

    // ------------------------------------------------------------------
    // Print RX_FRAME_CONTROL register value
    // ------------------------------------------------------------------
    `uvm_info("SCB_RX_FRAME_CTRL",
              $sformatf("MAC[1] rx_frame_control = 0x%08h", val),
              UVM_LOW)

    // ------------------------------------------------------------------
    // Print fwd_pause if this is a MAC Control PAUSE frame
    // ------------------------------------------------------------------
    if (tx_tr.ether_type == `MAC_CTRL_ETHERTYPE && tx_tr.pause_opc == `PAUSE_OPCODE) begin
      `uvm_info("SCB_TX_PAUSE", $sformatf(
                "TX PAUSE Packet Received | MAC[%0d] | fwd_pause=%0b | pause_time=%0d | TX_NO=%0d",
                src_id, tx_tr.fwd_pause, tx_tr.pause_time, txn_no), UVM_LOW)
    end

    // ------------------------------------------------------------------
    // Broadcast handling
    // ------------------------------------------------------------------
    if (is_broadcast_addr(tx_tr.da)) begin
      foreach (ai_2[i]) begin
        if (i == src_id) continue;
        tx_aa[src_id][i][txn_no] = tx_tr;
        `uvm_info("SCB_BROADCAST_TX", $sformatf(
                  "Stored BROADCAST TX : TX_MAC[%0d] --> RX_MAC[%0d] | TX_NO=%0d",
                  src_id, i, txn_no), UVM_LOW)
      end
      return;
    end

    // ------------------------------------------------------------------
    // Multicast handling
    // ------------------------------------------------------------------
    if (is_multicast_addr(tx_tr)) begin
      foreach (ai_2[i]) begin
        if (i == src_id) continue;
        if (tx_tr.multi_mac_addr[i].exists(tx_tr.da)) begin

          // Only set fwd_pause for MAC control frames; leave default (0) for normal data traffic
          if (tx_tr.ether_type == `MAC_CTRL_ETHERTYPE) begin
            if (tx_tr.pause_opc == `PAUSE_OPCODE) begin
              tx_tr.fwd_pause = val[4];               // PAUSE frame -> rx_frame_control bit
            end
            else if (tx_tr.pause_opc == `PFC_OPCODE) begin
              tx_tr.fwd_pause = rx_pfc_ctrl_val[16];  // PFC frame -> rx_pfc_control bit
            end
            else begin
              tx_tr.fwd_pause = val[3];               // other MAC control frame type
            end
          end

          $cast(tx_tr_clone_mc, tx_tr.clone());
          tx_aa[src_id][i][txn_no] = tx_tr_clone_mc;

          `uvm_info("SCB_MULTICAST_TX", $sformatf(
                    "Stored MULTICAST TX : TX_MAC[%0d] --> RX_MAC[%0d] | TX_NO=%0d | fwd_pause=%0b",
                    src_id, i, txn_no, tx_aa[src_id][i][txn_no].fwd_pause), UVM_LOW)
        end
      end
      return;
    end

    // ------------------------------------------------------------------
    // Unicast handling
    // ------------------------------------------------------------------
    dst_id = destination_address(tx_tr);

    // Only set fwd_pause for MAC control frames; leave default (0) for normal data traffic
    if (tx_tr.ether_type == `MAC_CTRL_ETHERTYPE) begin
      if (tx_tr.pause_opc == `PAUSE_OPCODE) begin
        tx_tr.fwd_pause = val[4];               // PAUSE frame -> rx_frame_control bit
      end
      else if (tx_tr.pause_opc == `PFC_OPCODE) begin
        tx_tr.fwd_pause = rx_pfc_ctrl_val[16];  // PFC frame -> rx_pfc_control bit
      end
      else begin
        tx_tr.fwd_pause = val[3];               // other MAC control frame type
      end
    end

    $cast(tx_tr_clone, tx_tr.clone());
    tx_aa[src_id][dst_id][txn_no] = tx_tr_clone;

    `uvm_info("SCB_TX_1", $sformatf(
              "Stored TX Packet : TX_MAC[%0d] --> RX_MAC[%0d] | TX_NO=%0d | fwd_pause=%0b | err_b=%0b",
              src_id, dst_id, txn_no,
              tx_aa[src_id][dst_id][txn_no].fwd_pause,
              tx_aa[src_id][dst_id][txn_no].err_b),
              UVM_LOW)
endfunction

  function bit is_error_pkt(eth_seq_item tr);
    if (tr.err_b)
      return 1;
    return 0;
  endfunction

  function bit is_broadcast_addr(bit [47:0] da);
    return (da == 48'hFFFF_FFFF_FFFF);
  endfunction

  function bit is_multicast_addr(eth_seq_item tr);
    foreach (tr.multi_mac_addr[i]) begin
      if (tr.multi_mac_addr[i].exists(tr.da))
        return 1;
    end
    return 0;
  endfunction

  //----------------------------------------------------------------------
  // Receives Ethernet packets from the RX monitor.
  //----------------------------------------------------------------------
  function void write_ap_2(eth_seq_item rx_tr);
    int src_id;
    int dst_id;
    int txn_no;

    // Decode SOURCE (SA -> src_id)
    src_id = source_address(rx_tr);
    txn_no = rx_tr.rx_count;

    // BROADCAST / MULTICAST / UNICAST Routing
    if (is_broadcast_addr(rx_tr.da)) begin
      dst_id = broad_cast(rx_tr);
    end
    else if (is_multicast_addr(rx_tr)) begin
      dst_id = multi_cast(rx_tr);
    end
    else begin
      dst_id = destination_address(rx_tr);
    end

    // TX existence check
    if (!tx_aa.exists(src_id) || !tx_aa[src_id].exists(dst_id) || !tx_aa[src_id][dst_id].exists(txn_no)) begin
      `uvm_error("SCB_EXTRA_RX", $sformatf(
                 "RX received but matching TX not found : TX_MAC[%0d] --> RX_MAC[%0d] | TX_NO=%0d",
                 src_id, dst_id, txn_no))
      rx_aa[src_id][dst_id][txn_no] = rx_tr;
      return;
    end

    // BAD PACKET HANDLING
    if (is_error_pkt(tx_aa[src_id][dst_id][txn_no])) begin
      `uvm_error("SCB_BAD_PKT", $sformatf(
                 "Bad packet reached RX | TX_MAC[%0d]->RX_MAC[%0d] TX_NO=%0d",
                 src_id, dst_id, txn_no))
      rx_aa[src_id][dst_id][txn_no] = rx_tr;
      return;
    end

    // PAUSE FRAME FORWARDING CHECK (fwd_pause == 0 expected at RX)
    if (rx_tr.ether_type == `MAC_CTRL_ETHERTYPE && rx_tr.pause_opc == `PAUSE_OPCODE) begin
      if (tx_aa[src_id][dst_id][txn_no].fwd_pause == 0) begin
        `uvm_error("SCB_UNEXPECTED_RX_PAUSE", $sformatf(
                   "PAUSE packet reached RX but fwd_pause=0 (was expected to be dropped on TX) | TX_MAC[%0d]->RX_MAC[%0d] TX_NO=%0d",
                   src_id, dst_id, txn_no))
        rx_aa[src_id][dst_id][txn_no] = rx_tr;
        return;
      end
    end
    // --- Unrecognized opcode on a MAC control frame ---
    else if (rx_tr.ether_type == `MAC_CTRL_ETHERTYPE &&
             rx_tr.pause_opc != `PAUSE_OPCODE && rx_tr.pause_opc != `PFC_OPCODE) begin
      if (tx_aa[src_id][dst_id][txn_no].fwd_pause == 0) begin
        `uvm_error("SCB_FWD_CTRL_FRM", $sformatf(
                   "rx_frame_ctrl[3] is disable, but sending control to scoreboard (TX_MAC[%0d]->RX_MAC[%0d], TX_NO=%0d)",
                   src_id, dst_id, txn_no))
        rx_aa[src_id][dst_id][txn_no] = rx_tr;
        return;
      end
    end

    // PFC FRAME FORWARDING CHECK (fwd_pause == 0 expected at RX)
    if (rx_tr.ether_type == `MAC_CTRL_ETHERTYPE && rx_tr.pause_opc == `PFC_OPCODE) begin
      if (tx_aa[src_id][dst_id][txn_no].fwd_pause == 0) begin
        `uvm_error("SCB_UNEXPECTED_RX_PFC", $sformatf(
                   "PFC packet reached RX but fwd_pause=0 (was expected to be dropped on TX) | TX_MAC[%0d]->RX_MAC[%0d] TX_NO=%0d",
                   src_id, dst_id, txn_no))
        rx_aa[src_id][dst_id][txn_no] = rx_tr;
        return;
      end
    end

    // GOOD PACKET -> COMPARE
    compare_packet(src_id, dst_id, txn_no, rx_tr.rx_count, tx_aa[src_id][dst_id][txn_no], rx_tr);

    // DELETE TX AFTER SUCCESSFUL COMPARISON
    tx_aa[src_id][dst_id].delete(txn_no);
  endfunction

  //----------------------------------------------------------------------
  // Verifies all expected packets in check phase.
  // Checks for bad packets, dropped PAUSE frames, or missing frames.
  //----------------------------------------------------------------------
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);

    foreach (tx_aa[src_id]) begin
      foreach (tx_aa[src_id][dst_id]) begin
        foreach (tx_aa[src_id][dst_id][txn_no]) begin

          // Case 1: BAD PACKET DROPPED
          if (is_error_pkt(tx_aa[src_id][dst_id][txn_no])) begin
            `uvm_info("SCB_BAD_PKT_PASS",
               $sformatf({
               "\n========================================================",
               "\nPASS : Bad Packet Correctly Dropped",
               "\n--------------------------------------------------------",
               "\nTX_MAC          : %0d",
               "\nRX_MAC          : %0d",
               "\nTRANSACTION     : %0d",
               "\nDA              : %012h",
               "\nSA              : %012h",
               "\n========================================================"
               }, src_id, dst_id, txn_no,
                  tx_aa[src_id][dst_id][txn_no].da,
                  tx_aa[src_id][dst_id][txn_no].sa), UVM_LOW)
            tx_aa[src_id][dst_id].delete(txn_no);
          end

          // Case 2: PAUSE FRAME DROPPED INTENTIONALLY AT RX (FWD_PAUSE = 0)
          else if (tx_aa[src_id][dst_id][txn_no].ether_type == `MAC_CTRL_ETHERTYPE &&
                   tx_aa[src_id][dst_id][txn_no].pause_opc  == `PAUSE_OPCODE &&
                   tx_aa[src_id][dst_id][txn_no].fwd_pause  == 0) begin
            `uvm_info("SCB_PAUSE_RX_DROPPED_PASS",
               $sformatf({
               "\n========================================================",
               "\nPASS : Pause Frame Correctly Dropped at RX (fwd_pause=0)",
               "\n--------------------------------------------------------",
               "\nTX_MAC          : %0d",
               "\nRX_MAC          : %0d",
               "\nTRANSACTION     : %0d",
               "\nPAUSE TIME      : %0d",
               "\n========================================================"
               }, src_id, dst_id, txn_no,
                  tx_aa[src_id][dst_id][txn_no].pause_time), UVM_LOW)
            tx_aa[src_id][dst_id].delete(txn_no);
          end

          // Case 3: PAUSE FRAME MISSING AT RX (FWD_PAUSE = 1, but RX never received it)
          else if (tx_aa[src_id][dst_id][txn_no].ether_type == `MAC_CTRL_ETHERTYPE &&
                   tx_aa[src_id][dst_id][txn_no].pause_opc  == `PAUSE_OPCODE &&
                   tx_aa[src_id][dst_id][txn_no].fwd_pause  == 1) begin
            `uvm_error("SCB_MISSING_PAUSE_RX",
               $sformatf({
               "\n========================================================",
               "\nFAIL : Pause Frame Missing At RX (fwd_pause=1)",
               "\n--------------------------------------------------------",
               "\nTX_MAC          : %0d",
               "\nRX_MAC          : %0d",
               "\nTRANSACTION     : %0d",
               "\nPAUSE TIME      : %0d",
               "\nDA              : %012h",
               "\nSA              : %012h",
               "\n========================================================"
               }, src_id, dst_id, txn_no,
                  tx_aa[src_id][dst_id][txn_no].pause_time,
                  tx_aa[src_id][dst_id][txn_no].da,
                  tx_aa[src_id][dst_id][txn_no].sa))
          end

          // Case 4: PAUSE FRAME DROPPED INTENTIONALLY AT RX (FWD_PAUSE = 0)
          else if (tx_aa[src_id][dst_id][txn_no].ether_type == `MAC_CTRL_ETHERTYPE &&
                   tx_aa[src_id][dst_id][txn_no].pause_opc  == `PFC_OPCODE &&
                   tx_aa[src_id][dst_id][txn_no].fwd_pause  == 0) begin
            `uvm_info("SCB_PFC_RX_DROPPED_PASS",
               $sformatf({
               "\n========================================================",
               "\nPASS : Pfc Frame Correctly Dropped at RX (fwd_pause=0)",
               "\n--------------------------------------------------------",
               "\nTX_MAC          : %0d",
               "\nRX_MAC          : %0d",
               "\nTRANSACTION     : %0d",
               "\nPAUSE TIME      : %0d",
               "\n========================================================"
               }, src_id, dst_id, txn_no,
                  tx_aa[src_id][dst_id][txn_no].pause_time), UVM_LOW)
            tx_aa[src_id][dst_id].delete(txn_no);
          end

          // Case 5: PAUSE FRAME MISSING AT RX (FWD_PAUSE = 1, but RX never received it)
          else if (tx_aa[src_id][dst_id][txn_no].ether_type == `MAC_CTRL_ETHERTYPE &&
                   tx_aa[src_id][dst_id][txn_no].pause_opc  == `PFC_OPCODE &&
                   tx_aa[src_id][dst_id][txn_no].fwd_pause  == 1) begin
            `uvm_error("SCB_MISSING_PFC_RX",
               $sformatf({
               "\n========================================================",
               "\nFAIL : Pfc Frame Missing At RX (fwd_pause=1)",
               "\n--------------------------------------------------------",
               "\nTX_MAC          : %0d",
               "\nRX_MAC          : %0d",
               "\nTRANSACTION     : %0d",
               "\nPAUSE TIME      : %0d",
               "\nDA              : %012h",
               "\nSA              : %012h",
               "\n========================================================"
               }, src_id, dst_id, txn_no,
                  tx_aa[src_id][dst_id][txn_no].pause_time,
                  tx_aa[src_id][dst_id][txn_no].da,
                  tx_aa[src_id][dst_id][txn_no].sa))
          end

          // Case 6: PAUSE FRAME DROPPED INTENTIONALLY AT RX (FWD_PAUSE = 0)
          else if (tx_aa[src_id][dst_id][txn_no].ether_type == `MAC_CTRL_ETHERTYPE &&
                   tx_aa[src_id][dst_id][txn_no].pause_opc  != `PAUSE_OPCODE &&
                   tx_aa[src_id][dst_id][txn_no].pause_opc  != `PAUSE_OPCODE && `PFC_OPCODE &&
                   tx_aa[src_id][dst_id][txn_no].fwd_pause  == 0) begin
            `uvm_info("SCB_PAUSE_RESERVED_OPCODE_RX_DROPPED_PASS",
               $sformatf({
               "\n========================================================",
               "\nPASS : Pause Frame Correctly Dropped at RX (fwd_pause=0)",
               "\n--------------------------------------------------------",
               "\nTX_MAC          : %0d",
               "\nRX_MAC          : %0d",
               "\nTRANSACTION     : %0d",
               "\nPAUSE TIME      : %0d",
               "\n========================================================"
               }, src_id, dst_id, txn_no,
                  tx_aa[src_id][dst_id][txn_no].pause_time), UVM_LOW)
            tx_aa[src_id][dst_id].delete(txn_no);
          end

          // Case 7: PAUSE FRAME MISSING AT RX (FWD_PAUSE = 1, but RX never received it)
          else if (tx_aa[src_id][dst_id][txn_no].ether_type == `MAC_CTRL_ETHERTYPE &&
                   tx_aa[src_id][dst_id][txn_no].pause_opc  != `PAUSE_OPCODE && `PFC_OPCODE &&
                   tx_aa[src_id][dst_id][txn_no].fwd_pause  == 1) begin
            `uvm_error("SCB_MISSING_PAUSE_RESERVED_OPCODE_RX",
               $sformatf({
               "\n========================================================",
               "\nFAIL : Pause Frame Missing At RX (fwd_pause=1)",
               "\n--------------------------------------------------------",
               "\nTX_MAC          : %0d",
               "\nRX_MAC          : %0d",
               "\nTRANSACTION     : %0d",
               "\nPAUSE TIME      : %0d",
               "\nDA              : %012h",
               "\nSA              : %012h",
               "\n========================================================"
               }, src_id, dst_id, txn_no,
                  tx_aa[src_id][dst_id][txn_no].pause_time,
                  tx_aa[src_id][dst_id][txn_no].da,
                  tx_aa[src_id][dst_id][txn_no].sa))
          end

          // Case 8: MISSING REGULAR DATA PACKET AT RX
          else begin
            `uvm_error("SCB_MISSING_RX",
               $sformatf({
               "\n========================================================",
               "\nFAIL : Good Packet Missing At RX",
               "\n--------------------------------------------------------",
               "\nTX_MAC          : %0d",
               "\nRX_MAC          : %0d",
               "\nTRANSACTION     : %0d",
               "\nDA              : %012h",
               "\nSA              : %012h",
               "\n========================================================"
               }, src_id, dst_id, txn_no,
                  tx_aa[src_id][dst_id][txn_no].da,
                  tx_aa[src_id][dst_id][txn_no].sa))
          end

        end
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    string test_name;
    string agent_status;
    int    tx_left;
    int    rx_left;
    int    tx_pkt_left;
    int    rx_pkt_left;

    super.report_phase(phase);

    if (`NO_OF_AGENTS == 2) begin
      for (int i = 0; i < `NO_OF_AGENTS; i++)
        compare_counters(i);
    end

    if (!$value$plusargs("UVM_TESTNAME=%s", test_name))
      test_name = "UNKNOWN_TEST";

    agent_status = "";
    tx_left       = 0;
    rx_left       = 0;

    for (int i = 0; i < `NO_OF_AGENTS; i++) begin
      tx_pkt_left = 0;
      if (tx_aa.exists(i)) begin
        foreach (tx_aa[i][dst])
          tx_pkt_left += tx_aa[i][dst].num();
      end
      tx_left      += tx_pkt_left;
      agent_status  = {agent_status, $sformatf("\n tx_array[%0d] : packets_left = %0d", i, tx_pkt_left)};
    end

    for (int i = 0; i < `NO_OF_AGENTS; i++) begin
      rx_pkt_left = 0;
      if (rx_aa.exists(i)) begin
        foreach (rx_aa[i][dst])
          rx_pkt_left += rx_aa[i][dst].num();
      end
      rx_left      += rx_pkt_left;
      agent_status  = {agent_status, $sformatf("\n rx_array[%0d] : packets_left = %0d", i, rx_pkt_left)};
    end

    if ((tx_left == 0) && (rx_left == 0)) begin
      `uvm_info("SCB_REPORT",
        $sformatf({
          "\n============================================================",
          "\n                  ETH SCOREBOARD REPORT",
          "\n============================================================",
          "\n TESTCASE         : %s",
          "\n PACKETS COMPARED : %0d",
          "\n",
          "\n MAC STATUS",
          "\n -----------------------------------------------------------",
          "%s",
          "\n -----------------------------------------------------------",
          "\n TOTAL TX PACKETS LEFT    : %0d",
          "\n TOTAL RX PACKETS LEFT    : %0d",
          "\n",
          "\n FINAL RESULT     : PASS",
          "\n============================================================"
        },
        test_name, matched_pkt_count, agent_status, tx_left, rx_left), UVM_NONE)
    end
    else begin
      `uvm_error("SCB_REPORT",
        $sformatf({
          "\n============================================================",
          "\n                  ETH SCOREBOARD REPORT",
          "\n============================================================",
          "\n TESTCASE         : %s",
          "\n PACKETS COMPARED : %0d",
          "\n",
          "\n MAC STATUS",
          "\n -----------------------------------------------------------",
          "%s",
          "\n -----------------------------------------------------------",
          "\n TOTAL TX PACKETS LEFT    : %0d",
          "\n TOTAL RX PACKETS LEFT    : %0d",
          "\n",
          "\n FINAL RESULT     : FAIL",
          "\n REASON           : %0d TX and %0d RX packets remain unmatched",
          "\n============================================================"
        },
        test_name, matched_pkt_count, agent_status, tx_left, rx_left, tx_left, rx_left))
    end
  endfunction

  function void compare_packet(
      int          tx_id,
      int          rx_id,
      int          tx_no,
      int          rx_no,
      eth_seq_item tx_tr,
      eth_seq_item rx_tr);

    bit pass = 1;

    // --- Destination & Source MAC Comparison ---
    if (tx_tr.da !== rx_tr.da) begin
      `uvm_error("SCB_DA", $sformatf("DA mismatch: TX=%012h RX=%012h", tx_tr.da, rx_tr.da))
      pass = 0;
    end

    if (tx_tr.sa !== rx_tr.sa) begin
      `uvm_error("SCB_SA", $sformatf("SA mismatch: TX=%012h RX=%012h", tx_tr.sa, rx_tr.sa))
      pass = 0;
    end

    // --- EtherType Comparison ---
    if (tx_tr.ether_type !== rx_tr.ether_type) begin
      `uvm_error("SCB_ETHERTYPE", $sformatf("EtherType mismatch: TX=%04h RX=%04h", tx_tr.ether_type, rx_tr.ether_type))
      pass = 0;
    end

    // --- Payload Comparison ---
    if (tx_tr.payload.size() != rx_tr.payload.size()) begin
      `uvm_error("SCB_PAYLOAD_SIZE", $sformatf("Payload size mismatch: TX=%0d RX=%0d", tx_tr.payload.size(), rx_tr.payload.size()))
      pass = 0;
    end
    else begin
      foreach (tx_tr.payload[i]) begin
        if (tx_tr.payload[i] !== rx_tr.payload[i]) begin
          `uvm_error("SCB_PAYLOAD", $sformatf("Payload mismatch byte[%0d]: TX=%0h RX=%0h", i, tx_tr.payload[i], rx_tr.payload[i]))
          pass = 0;
        end
      end
    end

    // ------------------------------------------------------------------
    // --- MAC Control Frame Identification (wire content only) ---
    // A frame is a MAC control frame if ether_type == MAC_CTRL_ETHERTYPE
    // AND da matches the reserved MAC control multicast address. Within
    // that, pause_opc distinguishes plain 802.3x PAUSE from PFC.
    // ------------------------------------------------------------------
    if (tx_tr.ether_type == `MAC_CTRL_ETHERTYPE) begin

      // --- Plain 802.3x PAUSE frame (opcode 0x0001) ---
      if (tx_tr.pause_opc == `PAUSE_OPCODE) begin
        if (tx_tr.pause_opc !== rx_tr.pause_opc) begin
          `uvm_error("SCB_PAUSE_OPC", $sformatf(
            "Pause opcode mismatch: TX=%04h RX=%04h (TX_MAC[%0d]->RX_MAC[%0d], TX_NO=%0d)",
            tx_tr.pause_opc, rx_tr.pause_opc, tx_id, rx_id, tx_no))
          pass = 0;
        end

        if (tx_tr.pause_time !== rx_tr.pause_time) begin
          `uvm_error("SCB_PAUSE_TIME", $sformatf(
            "Pause time mismatch: TX=%0d RX=%0d (TX_MAC[%0d]->RX_MAC[%0d], TX_NO=%0d)",
            tx_tr.pause_time, rx_tr.pause_time, tx_id, rx_id, tx_no))
          pass = 0;
        end
      end

      // --- PFC frame (opcode 0x0101) ---
      else if (tx_tr.pause_opc == `PFC_OPCODE) begin
        if (tx_tr.pause_opc !== rx_tr.pause_opc) begin
          `uvm_error("SCB_PFC_OPC", $sformatf(
            "PFC opcode mismatch: TX=%04h RX=%04h (TX_MAC[%0d]->RX_MAC[%0d], TX_NO=%0d)",
            tx_tr.pause_opc, rx_tr.pause_opc, tx_id, rx_id, tx_no))
          pass = 0;
        end

        if (tx_tr.priority_en_vector !== rx_tr.priority_en_vector) begin
          `uvm_error("SCB_PFC_PRIO_VECTOR", $sformatf(
            "PFC priority_en_vector mismatch: TX=%04h RX=%04h (TX_MAC[%0d]->RX_MAC[%0d], TX_NO=%0d)",
            tx_tr.priority_en_vector, rx_tr.priority_en_vector, tx_id, rx_id, tx_no))
          pass = 0;
        end

        // Per-priority pause time vector -- only meaningful for
        // priorities actually enabled in priority_en_vector, but
        // compared across all 8 since disabled entries should be 0
        // on both sides regardless.
        for (int p = 0; p < 8; p++) begin
          if (tx_tr.pfc_pause_time[p] !== rx_tr.pfc_pause_time[p]) begin
            `uvm_error("SCB_PFC_PAUSE_TIME", $sformatf(
              "PFC pfc_pause_time[%0d] mismatch: TX=%0d RX=%0d (TX_MAC[%0d]->RX_MAC[%0d], TX_NO=%0d)",
              p, tx_tr.pfc_pause_time[p], rx_tr.pfc_pause_time[p], tx_id, rx_id, tx_no))
            pass = 0;
          end
        end
      end

      // --- Unrecognized opcode on a MAC control frame ---
      else if (tx_tr.pause_opc !== rx_tr.pause_opc) begin
        `uvm_error("SCB_CTRL_OPC_MISMATCH", $sformatf(
          "MAC control frame with unrecognized pause_opc=%04h (TX_MAC[%0d]->RX_MAC[%0d], TX_NO=%0d)",
          tx_tr.pause_opc, tx_id, rx_id, tx_no))
        pass = 0;
      end
    end

    // --- Outer VLAN Field Comparisons (wire content: outer_TPID) ---
    if (tx_tr.outer_TPID == `OUTER_VLAN_TPID) begin
      if (tx_tr.outer_TPID !== rx_tr.outer_TPID) begin
        `uvm_error("SCB_OUTER_TPID", $sformatf("Outer TPID mismatch: TX=%04h RX=%04h", tx_tr.outer_TPID, rx_tr.outer_TPID))
        pass = 0;
      end
      if (tx_tr.outer_PCP !== rx_tr.outer_PCP) begin
        `uvm_error("SCB_OUTER_PCP", $sformatf("Outer PCP mismatch: TX=%0d RX=%0d", tx_tr.outer_PCP, rx_tr.outer_PCP))
        pass = 0;
      end
      if (tx_tr.outer_DEI !== rx_tr.outer_DEI) begin
        `uvm_error("SCB_OUTER_DEI", $sformatf("Outer DEI mismatch: TX=%0b RX=%0b", tx_tr.outer_DEI, rx_tr.outer_DEI))
        pass = 0;
      end
      if (tx_tr.outer_VID !== rx_tr.outer_VID) begin
        `uvm_error("SCB_OUTER_VID", $sformatf("Outer VID mismatch: TX=%0d RX=%0d", tx_tr.outer_VID, rx_tr.outer_VID))
        pass = 0;
      end
    end

    // --- Inner VLAN Field Comparisons (wire content: TPID) ---
    if (tx_tr.TPID == `SINGLE_VLAN_TPID) begin
      if (tx_tr.TPID !== rx_tr.TPID) begin
        `uvm_error("SCB_TPID", $sformatf("TPID mismatch: TX=%04h RX=%04h", tx_tr.TPID, rx_tr.TPID))
        pass = 0;
      end
      if (tx_tr.PCP !== rx_tr.PCP) begin
        `uvm_error("SCB_PCP", $sformatf("PCP mismatch: TX=%0d RX=%0d", tx_tr.PCP, rx_tr.PCP))
        pass = 0;
      end
      if (tx_tr.DEI !== rx_tr.DEI) begin
        `uvm_error("SCB_DEI", $sformatf("DEI mismatch: TX=%0b RX=%0b", tx_tr.DEI, rx_tr.DEI))
        pass = 0;
      end
      if (tx_tr.VID !== rx_tr.VID) begin
        `uvm_error("SCB_VID", $sformatf("VID mismatch: TX=%0d RX=%0d", tx_tr.VID, rx_tr.VID))
        pass = 0;
      end
    end

    // --- Final Reporting Block ---
    if (pass) begin
      matched_pkt_count++;
      `uvm_info("SCB_TRANS_NUM", $sformatf("\nTX_TRANSACTION_NO = %0d\nRX_TRANSACTION_NO = %0d", tx_no, rx_no), UVM_LOW)

      `uvm_info("SCB_COMPARE",
        $sformatf({
          "\n==============================================================================",
          "\n%-18s : %-18s | %-18s : %-18s",
          "\n==============================================================================",
          "\n%-18s : %-18d | %-18s : %-18d",
          "\n%-18s : %012h       | %-18s : %012h",
          "\n%-18s : %012h       | %-18s : %012h",
          "\n%-18s : %04h         | %-18s : %04h",
          "\n%-18s : %-18d | %-18s : %-18d",
          "\n%-18s : %08h       | %-18s : %08h",
          "\n=============================================================================="
        },
        "EXPECTED (TX)", "", "ACTUAL (RX)", "",
        "TX_AGENT",     tx_id,               "RX_AGENT",     rx_id,
        "DA",           tx_tr.da,            "DA",           rx_tr.da,
        "SA",           tx_tr.sa,            "SA",           rx_tr.sa,
        "ETHER_TYPE",   tx_tr.ether_type,    "ETHER_TYPE",   rx_tr.ether_type,
        "PAYLOAD_SIZE", tx_tr.payload.size(),"PAYLOAD_SIZE", rx_tr.payload.size(),
        "CRC",          tx_tr.crc,           "CRC",          rx_tr.crc
        ), UVM_LOW)

      // Print pause info if this was a plain pause frame
      if (tx_tr.ether_type == `MAC_CTRL_ETHERTYPE && tx_tr.pause_opc == `PAUSE_OPCODE) begin
        `uvm_info("SCB_PAUSE_INFO",
          $sformatf({
            "\n================ PAUSE INFO ================",
            "\nTX_PAUSE_OPC  : %04h | RX_PAUSE_OPC  : %04h",
            "\nTX_PAUSE_TIME : %0d   | RX_PAUSE_TIME : %0d",
            "\n=============================================="
          }, tx_tr.pause_opc, rx_tr.pause_opc, tx_tr.pause_time, rx_tr.pause_time), UVM_LOW)
      end

      // Print PFC info if this was a PFC frame
      if (tx_tr.ether_type == `MAC_CTRL_ETHERTYPE && tx_tr.pause_opc == `PFC_OPCODE) begin
        `uvm_info("SCB_PFC_INFO",
          $sformatf({
            "\n================ PFC INFO ================",
            "\nTX_PRIO_VECTOR : %04h | RX_PRIO_VECTOR : %04h",
            "\nTX_PAUSE_TIME[0..7] : %p",
            "\nRX_PAUSE_TIME[0..7] : %p",
            "\n============================================"
          }, tx_tr.priority_en_vector, rx_tr.priority_en_vector,
             tx_tr.pfc_pause_time, rx_tr.pfc_pause_time), UVM_LOW)
      end

      // Print Inner VLAN info if this was a single-tagged frame
      if (tx_tr.TPID == `SINGLE_VLAN_TPID) begin
        `uvm_info("SCB_VLAN_INFO",
          $sformatf({
            "\n================ VLAN INFO ================",
            "\nTX_TPID    : %04h  | RX_TPID    : %04h",
            "\nTX_PCP     : %0d   | RX_PCP     : %0d",
            "\nTX_DEI     : %0b   | RX_DEI     : %0b",
            "\nTX_VID     : %0d   | RX_VID     : %0d",
            "\n==========================================="
          }, tx_tr.TPID, rx_tr.TPID, tx_tr.PCP, rx_tr.PCP, tx_tr.DEI, rx_tr.DEI, tx_tr.VID, rx_tr.VID), UVM_LOW)
      end

      // Print Outer VLAN info if this was a double-tagged frame
      if (tx_tr.outer_TPID == `OUTER_VLAN_TPID) begin
        `uvm_info("SCB_OUTER_VLAN_INFO",
          $sformatf({
            "\n================ OUTER VLAN INFO ================",
            "\nTX_OUTER_TPID    : %04h | RX_OUTER_TPID    : %04h",
            "\nTX_OUTER_PCP     : %0d    | RX_OUTER_PCP     : %0d",
            "\nTX_OUTER_DEI     : %0b    | RX_OUTER_DEI     : %0b",
            "\nTX_OUTER_VID     : %0h    | RX_OUTER_VID     : %0h",
            "\n================================================="
          },
          tx_tr.outer_TPID, rx_tr.outer_TPID,
          tx_tr.outer_PCP,  rx_tr.outer_PCP,
          tx_tr.outer_DEI,  rx_tr.outer_DEI,
          tx_tr.outer_VID,  rx_tr.outer_VID
          ), UVM_LOW)
      end

      `uvm_info("SCB_RX_COUNT", $sformatf("RX packet count received in SB = %0d", rx_tr.rx_count), UVM_LOW)
    end
    else begin
      `uvm_error("SCB_FAIL", $sformatf("Packet mismatch: TX agent[%0d] (Pkt #%0d) -> RX agent[%0d] (Pkt #%0d)", tx_id, tx_no, rx_id, rx_no))
    end
  endfunction

  function int source_address(eth_seq_item tx_tr);
    for (int i = 0; i < `NO_OF_AGENTS; i++) begin
      if (tx_tr.sa == tx_tr.mac_addr[i]) return i;
    end
    `uvm_error("SB_INVALID_SA", $sformatf("Invalid Source Address Detected : SA=%012h", tx_tr.sa))
    return -1;
  endfunction

  function int destination_address(eth_seq_item tx_tr);
    for (int i = 0; i < `NO_OF_AGENTS; i++) begin
      if (tx_tr.da == tx_tr.mac_addr[i]) return i;
    end
    `uvm_error("SB_INVALID_DA", $sformatf("Invalid Destination Address Detected : DA=%012h", tx_tr.da))
    return -1;
  endfunction

  function int broad_cast(eth_seq_item rx_tr);
    for (int i = 0; i < `NO_OF_AGENTS; i++) begin
      if (rx_tr.agt_addr == rx_tr.mac_addr[i]) return i;
    end
  endfunction

  function int multi_cast(eth_seq_item rx_tr);
    for (int i = 0; i < `NO_OF_AGENTS; i++) begin
      if (rx_tr.mac_addr[i] == rx_tr.agt_addr && rx_tr.multi_mac_addr[i].exists(rx_tr.da)) return i;
    end
  endfunction

  function void compare_counters(int i);
    bit [47:0] mac0_addr;
    bit [47:0] mac1_addr;
    bit        j;
    bit [47:0] index;

    j = ~(bit'(i));
    mac_addr_arr.first(index);
    mac0_addr = index;
    mac_addr_arr.last(index);
    mac1_addr = index;

    `COMPARE_COUNTER(tx_good_pkt_pending,       rx_good_pkt_pending,       "GOOD_PKT")
    `COMPARE_COUNTER(tx_bad_pkt_pending,        rx_bad_pkt_pending,        "BAD_PKT")
    `COMPARE_COUNTER(tx_unicast_pending,        rx_unicast_pending,        "UNICAST")
    `COMPARE_COUNTER(tx_multicast_pending,      rx_multicast_pending,      "MULTICAST")
    `COMPARE_COUNTER(tx_broadcast_pending,      rx_broadcast_pending,      "BROADCAST")
    `COMPARE_COUNTER(tx_runt_pending,           rx_runt_pending,           "RUNT")
    `COMPARE_COUNTER(tx_fragment_pending,       rx_fragment_pending,       "FRAGMENT")
    `COMPARE_COUNTER(tx_jumbo_pending,          rx_jumbo_pending,          "JUMBO")
    `COMPARE_COUNTER(tx_super_jumbo_pending,    rx_super_jumbo_pending,    "SUPER_JUMBO")
    `COMPARE_COUNTER(tx_jabber_pending,         rx_jabber_pending,         "JABBER")
    `COMPARE_COUNTER(tx_pause_pending,          rx_pause_pending,          "PAUSE")
    `COMPARE_COUNTER(tx_vlan_pending,           rx_vlan_pending,           "VLAN")
    `COMPARE_COUNTER(tx_ipg_violation_pending,  rx_ipg_violation_pending,  "IPG_VIOLATION")
    `COMPARE_COUNTER(tx_pfc_xon_pending,        rx_pfc_xon_pending,        "PFC_XON")
    `COMPARE_COUNTER(tx_pfc_xoff_pending,       rx_pfc_xoff_pending,       "PFC_XOFF")
    `COMPARE_COUNTER(tx_carrier_ext_pending,    rx_carrier_ext_pending,    "CARRIER_EXT")
    `COMPARE_COUNTER(tx_pause_xon_pending,      rx_pause_xon_pending,      "PAUSE_XON")
    `COMPARE_COUNTER(tx_pause_xoff_pending,     rx_pause_xoff_pending,     "PAUSE_XOFF")
    `COMPARE_COUNTER(tx_control_pkt_pending,    rx_control_pkt_pending,    "CONTROL_PKT")
    `COMPARE_COUNTER(tx_pfc_xon_prio0_pending,  rx_pfc_xon_prio0_pending,  "PFC_XON_PRIO0")
    `COMPARE_COUNTER(tx_pfc_xon_prio1_pending,  rx_pfc_xon_prio1_pending,  "PFC_XON_PRIO1")
    `COMPARE_COUNTER(tx_pfc_xon_prio2_pending,  rx_pfc_xon_prio2_pending,  "PFC_XON_PRIO2")
    `COMPARE_COUNTER(tx_pfc_xon_prio3_pending,  rx_pfc_xon_prio3_pending,  "PFC_XON_PRIO3")
    `COMPARE_COUNTER(tx_pfc_xon_prio4_pending,  rx_pfc_xon_prio4_pending,  "PFC_XON_PRIO4")
    `COMPARE_COUNTER(tx_pfc_xon_prio5_pending,  rx_pfc_xon_prio5_pending,  "PFC_XON_PRIO5")
    `COMPARE_COUNTER(tx_pfc_xon_prio6_pending,  rx_pfc_xon_prio6_pending,  "PFC_XON_PRIO6")
    `COMPARE_COUNTER(tx_pfc_xon_prio7_pending,  rx_pfc_xon_prio7_pending,  "PFC_XON_PRIO7")
    `COMPARE_COUNTER(tx_pfc_xoff_prio0_pending, rx_pfc_xoff_prio0_pending, "PFC_XOFF_PRIO0")
    `COMPARE_COUNTER(tx_pfc_xoff_prio1_pending, rx_pfc_xoff_prio1_pending, "PFC_XOFF_PRIO1")
    `COMPARE_COUNTER(tx_pfc_xoff_prio2_pending, rx_pfc_xoff_prio2_pending, "PFC_XOFF_PRIO2")
    `COMPARE_COUNTER(tx_pfc_xoff_prio3_pending, rx_pfc_xoff_prio3_pending, "PFC_XOFF_PRIO3")
    `COMPARE_COUNTER(tx_pfc_xoff_prio4_pending, rx_pfc_xoff_prio4_pending, "PFC_XOFF_PRIO4")
    `COMPARE_COUNTER(tx_pfc_xoff_prio5_pending, rx_pfc_xoff_prio5_pending, "PFC_XOFF_PRIO5")
    `COMPARE_COUNTER(tx_pfc_xoff_prio6_pending, rx_pfc_xoff_prio6_pending, "PFC_XOFF_PRIO6")
    `COMPARE_COUNTER(tx_pfc_xoff_prio7_pending, rx_pfc_xoff_prio7_pending, "PFC_XOFF_PRIO7")
    `COMPARE_COUNTER(tx_idle_fault_seq_cnt,     rx_idle_fault_seq_cnt,     "IDLE_FAULT_SEQ")
    `COMPARE_COUNTER(tx_remote_fault_seq_cnt,   rx_remote_fault_seq_cnt,   "REMOTE_FAULT_SEQ")
    `COMPARE_COUNTER(tx_oversized_pending,      rx_oversized_pending,      "OVERSIZE_FRAME")
  endfunction
endclass

