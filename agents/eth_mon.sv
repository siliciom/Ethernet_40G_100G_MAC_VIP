//==============================================================================
// 40G ETHERNET MONITOR
//
// Description:
// - Implements transmit (TX) and receive (RX) monitoring for the 40G Ethernet
//   XLGMII interface.
// - Includes Receive Reconciliation Sublayer (RS) functionality to convert
//   XLGMII control/data characters into MAC frames.
// - TX Monitor captures and publishes expected packets.
// - RX Monitor captures, processes through the RS layer, and publishes
//   received packets for scoreboard comparison.
//
// Current Functionality:
// - TX frame monitoring
// - RX frame monitoring
// - RS layer processing (Start, Terminate, Idle, and basic Error handling)
// - Frame extraction and transaction creation
//
// TODO:
// - Implement complete RS error handling scenarios.
// - Add Local Fault and Remote Fault processing.
// - Support double VLAN (Q-in-Q) tagged frames.
// - Verify Pause and Priority Flow Control (PFC) test cases.
// - Enhance RS layer handling for all IEEE 802.3 XLGMII control characters.
//==============================================================================
class eth_mon extends uvm_monitor;

  `uvm_component_utils(eth_mon)

  uvm_analysis_port #(eth_seq_item) tx_ap;
  uvm_analysis_port #(eth_seq_item) rx_ap;

  virtual eth_interface v_intf;

  eth_cnfg cfg;
  bit [47:0] mac_addr;
  bit multi_mac_addr[bit [47:0]];

  int rx_pkt_count;
  int tx_pkt_count;
  localparam int NUM_LANES = `DATA_WIDTH / 8;
  localparam int PREAMBLE_SFD_BYTES = 8;
  localparam bit [15:0] MAC_CTRL_ETHERTYPE = 16'h8808;
  localparam bit [15:0] PAUSE_OPCODE       = 16'h0001;
  localparam bit [15:0] PFC_OPCODE         = 16'h0101;
  localparam int FRAME_DATA_OFFSET = 8;
  localparam bit [15:0] SVLAN_TPID         = 16'h8100;
  localparam bit [15:0] DVLAN_TPID         = 16'h88A8;
 
  localparam bit [47:0] BROADCAST_MAC      = 48'hFF_FF_FF_FF_FF_FF;
 
  localparam bit [31:0] CRC_RESIDUE        = 32'hC704DD7B;

  bit [7:0] tx_frame_q[$];
  bit [7:0] rx_frame_q[$];

  bit frame_transmission;
  int count;

  function new(string name="eth_mon", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  // BUILD PHASE
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tx_ap = new("tx_ap", this);
    rx_ap = new("rx_ap", this);

    if (!uvm_config_db #(virtual eth_interface)::get(this, "", "vif", v_intf))
    `uvm_fatal("MON", "VIF CONNECTION FAILED")


    if(!uvm_config_db #(eth_cnfg)::get(this,"","cfg",cfg))
    `uvm_fatal(get_type_name(),"No cfg")
  endfunction

  // RUN PHASE
  task run_phase(uvm_phase phase);
    wait(v_intf.rst);
    fork
      tx_mon();
      rx_mon();
    join_none
  endtask
  //==============================================================================
  // RECONCILIATION SUBLAYER (RS) FUNCTIONALITY
  //==============================================================================
  //
  // rs_framer():
  // - Processes the incoming XLGMII RXD/TXD and RXC/TXC signals.
  // - Detects the Start control character (0xFB) and identifies the beginning
  //   of an Ethernet frame.
  // - Detects the Terminate control character (0xFD) and identifies the end
  //   of the frame.
  // - Filters XLGMII control characters (e.g., Idle) and stores only valid
  //   frame data bytes into the frame queue.
  // - Detects Error control characters (0xFE) and reports invalid frames to
  //   the TX/RX monitor.
  // - Supports handling of Local Fault and Remote Fault indications
  //   (to be implemented).
  //=================================================================================
  task rs_framer(
    input  bit [63:0] data,               // rxd or txd (64 bits = 8 lanes)
    input  bit [7:0]  ctrl,               // rxc or txc (8 control bits)
    inout  bit        frame_active,
    ref    bit [7:0]  frame_q[$],
    output bit        frame_done,
    ref    bit        er_seen,
    ref    bit        inv_ctrl_char_seen,
    ref    bit        pending_term_check  // Cross-cycle state variable
  );
  frame_done         = 0;
  inv_ctrl_char_seen = 0;

  // =========================================================================
  // STEP 1: Cross-Cycle Validation for /T/ (0xFD) on Lane 7 of Prev Cycle
  // =========================================================================
  if (pending_term_check) begin
    pending_term_check = 0; // Clear flag immediately

    // Check Lane 0 of the NEW cycle
    if (ctrl[0] && (data[7:0] == `IDLE_CH)) begin
      // VALID TERMINATION: Lane 7 of previous cycle was a valid /T/!
      frame_active = 0;
      frame_done   = 1;

      // FIX FOR CORNER CASE 2: Pop /T/ (0xFD) out of frame_q so payload/FCS isn't corrupted
      if (frame_q.size() > 0 && frame_q[$] == `TERMINATE_CH) begin
        void'(frame_q.pop_back());
      end

      //dump_queue(frame_q, er_seen);
      return; // Frame cleanly closed
    end else begin
      // INVALID TERMINATION: Previous 0xFD on Lane 7 was corrupt/spurious!
      er_seen            = 1;
      inv_ctrl_char_seen = 1;
      `uvm_error("RS_TERMINATE_CROSS_CYCLE_ERR", $sformatf(
        "Protocol Violation: /T/ (0xFD) on Lane 7 was NOT followed by /I/ on Lane 0 at Time %0t.",
        $time))
      // frame_active remains 1; continue processing current cycle
    end
  end

  // =========================================================================
  // STEP 2: Process Lanes 0 through 7 of Current Cycle
  // =========================================================================
  for (int lane = 0; lane < NUM_LANES; lane++) begin
    bit [7:0] lane_data = data[lane*8 +: 8];
    bit       lane_ctrl = ctrl[lane]; // MUST be 1 for control byte!

    // -----------------------------------------------------------------------
    // CASE 1: IDLE STATE -> Expecting /S/ (0xFB with ctrl == 1)
    // -----------------------------------------------------------------------
    if (!frame_active) begin
      if (lane_ctrl) begin
        if (lane_data == `START_CH) begin
          frame_active = 1;
          er_seen      = 0; // FIX FOR CORNER CASE 1: Reset er_seen for NEW frame!
          frame_q.delete();
          frame_q.push_back(lane_data);

          if (lane != 0) begin
            er_seen = 1;
            `uvm_error("RS_FRAMER_ERR", $sformatf(
              "Misaligned /S/ (0xFB) on Lane %0d at Time %0t", lane, $time))
          end
        end
        else if (lane_data != `IDLE_CH) begin
          er_seen            = 1;
          inv_ctrl_char_seen = 1;
	  frame_active = 1;
	  frame_q.delete();
          frame_q.push_back(lane_data);
          `uvm_error("RS_INVALID_CTRL_CHAR", $sformatf(
            "Invalid control byte 0x%0h on Lane %0d at Time %0t while idle",
            lane_data, lane, $time))
        end
      end
    end

    // -----------------------------------------------------------------------
    // CASE 2: ACTIVE FRAME -> Receiving Payload or Frame Boundary
    // -----------------------------------------------------------------------
    else begin
      if (lane_ctrl) begin
        case (lane_data)

          // -----------------------------------------------------------------
          // /T/ (0xFD) Control Character Handling
          // -----------------------------------------------------------------
          `TERMINATE_CH: begin
            if (lane < 7) begin
              bit [7:0] next_lane_data = data[(lane+1)*8 +: 8];
              bit       next_lane_ctrl = ctrl[lane+1];

              if (next_lane_ctrl && (next_lane_data == `IDLE_CH)) begin
                frame_active = 0;
                frame_done   = 1;
               // dump_queue(frame_q, er_seen);
                break; // Clean frame termination
              end else begin
                // Bad /T/ mid-payload
                er_seen            = 1;
                inv_ctrl_char_seen = 1;
                frame_q.push_back(lane_data);
                `uvm_error("RS_TERMINATE_ALIGN_ERR", $sformatf(
                  "Bad /T/ (0xFD) on Lane %0d at Time %0t (next byte not /I/)",
                  lane, $time))
              end
            end 
            else begin
              // /T/ on Lane 7: Defer validation to Lane 0 of NEXT cycle
              pending_term_check = 1;
              frame_q.push_back(lane_data);
            end
          end

          // -----------------------------------------------------------------
          // /E/ (0xFE) Error Character
          // -----------------------------------------------------------------
          `ERROR_CH: begin
            er_seen = 1;
            `uvm_error("RS_FRAMER_ERROR_CHAR", $sformatf(
              "Transmission Error /E/ (0xFE) on Lane %0d at Time %0t", lane, $time))
            frame_q.push_back(lane_data);
          end

          // -----------------------------------------------------------------
          // /I/ (0x07) Control Character -> Unexpected Mid-Frame Idle
          // -----------------------------------------------------------------
          `IDLE_CH: begin
            er_seen      = 1;
            frame_active = 0;
            frame_done   = 1;
            `uvm_error("RS_MISSING_TERM_ERR", $sformatf(
              "Unexpected Idle /I/ (0x07) with ctrl=1 on Lane %0d at Time %0t. Frame truncated at %0d bytes.",
              lane, $time, frame_q.size()))
            //dump_queue(frame_q, er_seen);
            break;
          end

          // -----------------------------------------------------------------
          // /S/ (0xFB) Control Character mid-frame
          // -----------------------------------------------------------------
          `START_CH: begin
            er_seen            = 1;
            inv_ctrl_char_seen = 1;
            `uvm_error("RS_UNEXPECTED_START", $sformatf(
              "Unexpected /S/ (0xFB) with ctrl=1 mid-frame on Lane %0d at Time %0t",
              lane, $time))
            frame_q.push_back(lane_data);
          end

          default: begin
            er_seen      = 1; 
            `uvm_error("RS_UNKNOWN_CTRL", $sformatf(
              "Unknown control character 0x%0h (ctrl=1) on Lane %0d at Time %0t",
              lane_data, lane, $time))
           	   frame_q.push_back(lane_data);

          end
        endcase
      end

      // ---------------------------------------------------------------------
      // Regular Payload Byte (lane_ctrl == 0)
      // ---------------------------------------------------------------------
      else begin
        frame_q.push_back(lane_data);
      end
    end
  end
endtask

  // Helper print function with pass-by-reference queue
  function automatic void dump_queue(ref bit [7:0] q[$], input bit err);
    $display("\n================ RS LAYER QUEUE DUMP ================");
    $display(" Time: %0t | Length: %0d Bytes | Errored: %0b", $time, q.size(), err);
    $display("----------------------------------------------------");
    foreach (q[k]) begin
      $write("%02h ", q[k]);
      if ((k + 1) % 16 == 0) $display("");
    end
    if (q.size() % 16 != 0) $display("");
    $display("====================================================\n");
  endfunction

  //============================================================================
  // check_preamble_sfd :  Check preamble and SFD from extracted raw queue  //============================================================================
  function automatic bit check_preamble_sfd(ref bit [7:0] frame_q[$],
                                             output bit bad_preamble,
                                             output bit bad_sfd);
    bad_preamble = 0;
    bad_sfd      = 0;

    if (frame_q.size() < PREAMBLE_SFD_BYTES) begin
      bad_preamble = 1; // runt / incomplete preamble, treat as bad
      return 0;
    end

    for (int i = 0; i < 7; i++) begin
      if ((i == 0 && frame_q[i] != `START_CH) || (i > 0 && frame_q[i] != `PREAMBLE))
        bad_preamble = 1;
    end
    if (frame_q[7] != `SFD)
      bad_sfd = 1;

    return !(bad_preamble || bad_sfd);
  endfunction

  //============================================================================
  // get_min_payload : single source of truth for min payload size selection,
  // replaces the 3-4x duplicated if/else-if chains.
  //============================================================================
  function automatic int get_min_payload(eth_seq_item tr);
    if (tr.outer_vlan_en) return `DOUBLE_VLAN_PAYLOAD_SIZE;
    if (tr.vlan_en)        return `VLAN_PAYLOAD_SIZE;
    return `MIN_PAYLOAD_SIZE;
  endfunction

  //============================================================================
  // is_da_valid : shared DA classification (unicast self / broadcast /
  // known multicast), replaces duplicated foreach+compare blocks.
  //============================================================================
  function automatic bit is_da_valid(eth_seq_item tr, bit [47:0] da);
    if (da == BROADCAST_MAC) return 1;
    foreach (tr.mac_addr[i])
      if (da == tr.mac_addr[i]) return 1;
    foreach (tr.multi_mac_addr[i])
      if (mac_addr != tr.mac_addr[i] && tr.multi_mac_addr[i].exists(da)) return 1;
    return 0;
  endfunction

  //============================================================================
  // bump_pfc_stat : isolates the only remaining "per-priority named signal"
  // hardcoding to one function instead of duplicating it in tx_mon+rx_mon.
  // If/when statistics:: is changed to array-based counters, this becomes
  // a one-line foreach and the case statement disappears entirely.
  //============================================================================
  function automatic void bump_pfc_stat(bit is_tx, bit [47:0] mac, int prio, bit xon);
    if (is_tx) begin
      if (xon) begin
        statistics::tx_pfc_xon_pending[mac]++;
        case (prio)
          0: statistics::tx_pfc_xon_prio0_pending[mac]++;
          1: statistics::tx_pfc_xon_prio1_pending[mac]++;
          2: statistics::tx_pfc_xon_prio2_pending[mac]++;
          3: statistics::tx_pfc_xon_prio3_pending[mac]++;
          4: statistics::tx_pfc_xon_prio4_pending[mac]++;
          5: statistics::tx_pfc_xon_prio5_pending[mac]++;
          6: statistics::tx_pfc_xon_prio6_pending[mac]++;
          7: statistics::tx_pfc_xon_prio7_pending[mac]++;
        endcase
      end
      else begin
        statistics::tx_pfc_xoff_pending[mac]++;
        case (prio)
          0: statistics::tx_pfc_xoff_prio0_pending[mac]++;
          1: statistics::tx_pfc_xoff_prio1_pending[mac]++;
          2: statistics::tx_pfc_xoff_prio2_pending[mac]++;
          3: statistics::tx_pfc_xoff_prio3_pending[mac]++;
          4: statistics::tx_pfc_xoff_prio4_pending[mac]++;
          5: statistics::tx_pfc_xoff_prio5_pending[mac]++;
          6: statistics::tx_pfc_xoff_prio6_pending[mac]++;
          7: statistics::tx_pfc_xoff_prio7_pending[mac]++;
        endcase
      end
    end
    else begin
      if (xon) begin
        case (prio)
          0: statistics::rx_pfc_xon_prio0_pending[mac]++;
          1: statistics::rx_pfc_xon_prio1_pending[mac]++;
          2: statistics::rx_pfc_xon_prio2_pending[mac]++;
          3: statistics::rx_pfc_xon_prio3_pending[mac]++;
          4: statistics::rx_pfc_xon_prio4_pending[mac]++;
          5: statistics::rx_pfc_xon_prio5_pending[mac]++;
          6: statistics::rx_pfc_xon_prio6_pending[mac]++;
          7: statistics::rx_pfc_xon_prio7_pending[mac]++;
        endcase
      end
      else begin
        case (prio)
          0: statistics::rx_pfc_xoff_prio0_pending[mac]++;
          1: statistics::rx_pfc_xoff_prio1_pending[mac]++;
          2: statistics::rx_pfc_xoff_prio2_pending[mac]++;
          3: statistics::rx_pfc_xoff_prio3_pending[mac]++;
          4: statistics::rx_pfc_xoff_prio4_pending[mac]++;
          5: statistics::rx_pfc_xoff_prio5_pending[mac]++;
          6: statistics::rx_pfc_xoff_prio6_pending[mac]++;
          7: statistics::rx_pfc_xoff_prio7_pending[mac]++;
        endcase
      end
    end
  endfunction

  //============================================================================
  // handle_control_frame : shared PAUSE/PFC classification + stats + log.
  // Returns 1 if this transaction was a control frame (caller must
  // 'continue' after this and NOT forward it to scoreboard).
  //============================================================================
  function automatic bit handle_control_frame(bit is_tx, eth_seq_item tr, string full_name);
    string side;
    side = is_tx ? "TX" : "RX";

    // ---------------- PAUSE ----------------
    if (tr.pause_frame_en && tr.pause_opc == PAUSE_OPCODE && tr.ether_type == MAC_CTRL_ETHERTYPE) begin
      if (tr.payload.size() < `PAUSE_PAYLOAD_SIZE && tr.padding_en) begin
        `uvm_error({"Short_Pause_pkt_", side}, $sformatf(
          "pause_frame_en=%0d ether_type=%h pause_opc=%h payload_size=%0d",
          tr.pause_frame_en, tr.ether_type, tr.pause_opc, tr.payload.size()))
        if (is_tx) statistics::tx_bad_pkt_pending[mac_addr]++;
        if (is_tx) statistics::tx_drop_pending[mac_addr]++; //TO-DO
        else begin
          statistics::rx_drop_pending[mac_addr]++;
          statistics::rx_bad_pkt_pending[mac_addr]++;
        end  
      end
      else begin
        if (is_tx) statistics::tx_good_pkt_pending[mac_addr]++;
        else begin
          statistics::pause_value[mac_addr]  = tr.pause_time;
          statistics::pause_flag[mac_addr]   = 1;
          statistics::pause_update[mac_addr] = 1;
          statistics::rx_good_pkt_pending[mac_addr]++;
          addr_classify_rx(tr);
        end

        if (tr.pause_time == 0) begin
          if (is_tx) statistics::tx_pause_xon_pending[mac_addr]++;
          else       statistics::rx_pause_xon_pending[mac_addr]++;
        end
        else begin
          if (is_tx) statistics::tx_pause_xoff_pending[mac_addr]++;
          else       statistics::rx_pause_xoff_pending[mac_addr]++;
        end

        `uvm_info({side, "_PAUSE_BLOCK"}, $sformatf(
          "pause_frame_en=%0d ether_type=%h pause_opc=%h pause_time=%0d",
          tr.pause_frame_en, tr.ether_type, tr.pause_opc, tr.pause_time), UVM_LOW)

        if (is_tx) statistics::tx_drop_pending[mac_addr]++;
        else       statistics::rx_drop_pending[mac_addr]++;
      end

      eth_packet_tracker::print_packet(side, full_name, tr);
      return 1;
    end

    // ---------------- PFC ----------------
    if (tr.pfc_frame_en && tr.pause_opc == PFC_OPCODE && tr.ether_type == MAC_CTRL_ETHERTYPE) begin
      if (tr.payload.size() < `PFC_PAYLOAD_SIZE && tr.padding_en) begin
        `uvm_error({"Short_Pfc_pkt_", side}, $sformatf(
          "pfc_frame_en=%0d ether_type=%h pause_opc=%h payload_size=%0d",
          tr.pfc_frame_en, tr.ether_type, tr.pause_opc, tr.payload.size()))
        statistics::tx_bad_pkt_pending[mac_addr]++;
        if (is_tx) statistics::tx_drop_pending[mac_addr]++;
        else       statistics::rx_drop_pending[mac_addr]++;
      end
      else begin
        if (is_tx) statistics::tx_good_pkt_pending[mac_addr]++;
        else begin
          statistics::rx_good_pkt_pending[mac_addr]++;
          addr_classify_rx(tr);
        end

        // Data-driven loop instead of separately unrolled TX/RX case blocks
        foreach (tr.priority_en_vector[i]) begin
          if (tr.priority_en_vector[i]) begin
            if (!is_tx) begin
              statistics::pfc_value[mac_addr][i]  = tr.pfc_pause_time[i];
              statistics::pfc_flag[mac_addr][i]   = 1;
              statistics::pfc_update[mac_addr][i] = 1;
            end
            bump_pfc_stat(is_tx, mac_addr, i, (tr.pfc_pause_time[i] == 0));
          end
        end
      end

      `uvm_info({side, "_PFC_BLOCK"}, "PFC frame blocked from scoreboard", UVM_LOW)
      if (is_tx) statistics::tx_drop_pending[mac_addr]++;
      else       statistics::rx_drop_pending[mac_addr]++;

      eth_packet_tracker::print_packet(side, full_name, tr);
      return 1;
    end

    // ---------------- Unknown MAC control opcode ----------------
    if (tr.ether_type == MAC_CTRL_ETHERTYPE && tr.pause_opc != PAUSE_OPCODE && tr.pause_opc != PFC_OPCODE) begin
      if (is_tx) statistics::tx_control_pkt_pending[mac_addr]++;
      else       statistics::rx_control_pkt_pending[mac_addr]++;
      `uvm_info({side, "_CONTROL"}, $sformatf(
        "Unknown control packet opcode=%h sent to scoreboard", tr.pause_opc), UVM_LOW)
      return 0; // not blocked - falls through to scoreboard as a normal pkt
    end

    return 0;
  endfunction



  //============================================================
  // TX Monitor
  // ===========================================================
  // 1. Captures XLGMII TX interface data using the RS framer.
  // 2. Reconstructs Ethernet frames from TXD/TXC.
  // 3. Validates frame fields (Preamble, SFD, DA, EtherType, CRC,
  //   length, etc.).
  // 4. Marks frames containing RS-layer Error control characters
  //   (/E/) as bad instead of dropping them.
  // 5. This allows packet statistics and counters to be updated
  //   correctly while propagating the error indication to the
  //   scoreboard.
  //==============================================================
  task tx_mon();
    eth_seq_item tr;
    bit crc_ok;
    bit da_match;
    bit [47:0] tx_da;
    bit invalid_ethertype_tx;
    bit bad_sfd_tx;
    bit bad_preamble_tx;
    bit tx_er_seen;
    bit len_mismatch_tx;
    bit pkt_bad;
    int min_payload;
    bit tx_frame_active = 0;
    bit tx_frame_done   = 0;
    bit tx_inv_char_seen;
    bit tx_pending_term_check=0;
    
    forever begin
      tx_er_seen = 0;
      // Collect data cycle by cycle using the single RS framer
      do begin
        @(v_intf.tx_mon_cb);
       rs_framer(
         v_intf.tx_mon_cb.TXD,
         v_intf.tx_mon_cb.TXC,
         tx_frame_active,
         tx_frame_q,
         tx_frame_done,
         tx_er_seen,
         tx_inv_char_seen,
         tx_pending_term_check  // <--- Passed as ref to track Lane 7 across cycles
);

       
      end while (!tx_frame_done);
      crc_ok               = 0;
      da_match             = 0;
      invalid_ethertype_tx = 0;
      bad_preamble_tx      = 0;
      bad_sfd_tx           = 0;
      len_mismatch_tx      = 0;
      pkt_bad              = tx_er_seen; // Flags bad packet if invalid control char or /E/ was seen

      // Check preamble and SFD from extracted raw queue
      void'(check_preamble_sfd(tx_frame_q, bad_preamble_tx, bad_sfd_tx));
      if (bad_preamble_tx || bad_sfd_tx) pkt_bad = 1;

      tr = eth_seq_item::type_id::create("tr", this);
      tx_pkt_count++;
      tr.tx_count = tx_pkt_count;

      if (tx_frame_q.size() < 14)
        `uvm_error("TX_SHORT_FRAME", "Frame smaller than L2 header")

      tx_da = {tx_frame_q[FRAME_DATA_OFFSET+0], tx_frame_q[FRAME_DATA_OFFSET+1], tx_frame_q[FRAME_DATA_OFFSET+2],
               tx_frame_q[FRAME_DATA_OFFSET+3], tx_frame_q[FRAME_DATA_OFFSET+4], tx_frame_q[FRAME_DATA_OFFSET+5]};
      da_match = is_da_valid(tr, tx_da);
     
      // UNPACK
      crc_ok = frame_unpack(tr, tx_frame_q, 8, 0, len_mismatch_tx, invalid_ethertype_tx);
      
      if (cfg.tx_single_vlan_enable[0]) begin
        if (!tr.vlan_en && !tr.pause_frame_en) begin
          `uvm_error("VLAN_MISSING", "Single VLAN mode enabled but frame has no VLAN tag")
          pkt_bad = 1;
        end
        else if (tr.TPID != SVLAN_TPID && !tr.pause_frame_en) begin
          `uvm_error("VLAN_TPID", $sformatf("Invalid TPID = %h", tr.TPID))
          pkt_bad = 1;
        end
	else begin
		if(!tr.pause_frame_en) statistics::tx_vlan_pending[mac_addr]++;
        end		
      end
      else if (tr.vlan_en && !tr.outer_vlan_en) begin
        pkt_bad = 1;
      end

      addr_classify_tx(tr);

      if (bad_preamble_tx) `uvm_error("TX_PREAMBLE_ERR", $sformatf("Bad Preamble frame_size=%0d", tx_frame_q.size()))
      if (bad_sfd_tx)      `uvm_error("TX_SFD_ERR", $sformatf("Bad SFD frame_size=%0d", tx_frame_q.size()))
      if (tr.outer_vlan_en && tr.outer_TPID != DVLAN_TPID)
        `uvm_error("DOUBLE_VLAN_TPID", $sformatf("Invalid Outer TPID = %h", tr.outer_TPID))
      if (!da_match)   begin
        pkt_bad = 1;
         `uvm_error("TX_INVALID_DA", $sformatf("Invalid DA=%h", tx_da))
      end
      if (invalid_ethertype_tx) begin
        pkt_bad = 1;
        `uvm_error("TX_UNDEFINED_ETHERTYPE", $sformatf("Undefined EtherType=%0d", tr.ether_type))
      end  
      if (len_mismatch_tx && tr.payload.size() >= cfg.tx_frame_minlength-`HEADER) begin
        pkt_bad = 1;
        `uvm_error("TX_LEN_DATA_MISMATCH", "Length mismatch detected")
     end
      if (!crc_ok && tr.payload.size() >= cfg.tx_frame_minlength-`HEADER) begin
        pkt_bad = 1;
        `uvm_error("TX_CRC_ERR", $sformatf("Bad CRC DA=%h SA=%h CRC=%h", tr.da, tr.sa, tr.crc))
      end
      if (!crc_ok && tr.payload.size() < cfg.tx_frame_minlength-`HEADER)
        `uvm_error("TX_FRAGMENT_CRC", $sformatf("Bad CRC DA=%h SA=%h CRC=%h", tr.da, tr.sa, tr.crc))
      if (tr.outer_vlan_en) statistics::tx_vlan_pending[mac_addr]++  ;
      if (!crc_ok) pkt_bad = 1; 

      // RUNT / FRAGMENT   
      min_payload = get_min_payload(tr);
      if (tr.payload.size() < min_payload && tr.ether_type != MAC_CTRL_ETHERTYPE) begin
        if (crc_ok) begin
          statistics::tx_runt_pending[mac_addr]++;
          `uvm_info("TX_RUNT_PKT", $sformatf("Good runt packet payload=%0d", tr.payload.size()), UVM_LOW)
        end
        else begin
          statistics::tx_fragment_pending[mac_addr]++;
          `uvm_error("TX_FRAGMENT_PKT", $sformatf("Fragment detected payload=%0d", tr.payload.size()))
        end
        pkt_bad = 1;
      end

      `ifdef JUMBO_EN
      if (tr.payload.size() > cfg.tx_frame_maxlength+`HEADER && tr.payload.size() < 16383 && crc_ok) begin
        statistics::tx_jumbo_pending[mac_addr]++;
        `uvm_info("TX_JUMBO_PKT", $sformatf("Jumbo detected payload=%0d", tr.payload.size()), UVM_LOW)
      end
`else
      if (tr.payload.size() >= 1536) begin
        if (crc_ok) begin
          `uvm_error("TX_LONG_PKT", $sformatf("Long packet payload=%0d", tr.payload.size()))
        end
        else begin
          statistics::tx_jabber_pending[mac_addr]++;
          `uvm_error("TX_JABBER_PKT", $sformatf("Jabber detected payload=%0d", tr.payload.size()))
        end
        pkt_bad = 1;
      end
  `endif

     // Control frames (PAUSE/PFC) are classified, logged, and dropped here.
      if (handle_control_frame(1, tr, this.get_full_name()))
        continue;

      tr.err_b = pkt_bad;
      if (pkt_bad) statistics::tx_bad_pkt_pending[mac_addr]++;
      else         statistics::tx_good_pkt_pending[mac_addr]++;
      
      eth_packet_tracker::print_packet("TX", this.get_full_name(), tr);
      tx_ap.write(tr);
    end
  endtask
  //=============================================================================
  // TASK: rx_mon
  //=============================================================================
  //   1. Sample RXD/RXC every clock via rs_framer() until a full frame is
  //      collected in rx_frame_q.
  //   2. Check preamble (0x55) and SFD; pop the 8 header bytes off the queue.
  //   3. Extract and validate DA (unicast/broadcast/multicast match).
  //   4. Unpack frame via frame_unpack() — gets DA/SA/VLAN/EtherType/
  //      payload/CRC.
  //   5. Validate VLAN tagging (single/double VLAN modes).
  //   6. Classify frame size — runt/fragment/jumbo/jabber.
  //   7. Check CRC (drop if bad and CRC checking enabled).
  //   8. Handle PAUSE/PFC control frames separately (stats only, not sent
  //      to scoreboard).
  //   9. Update good-packet statistics and write transaction to rx_ap.
  //===============================================================================
  task rx_mon();
    eth_seq_item tr;
    bit bad_pkt;
    bit crc_ok;
    bit da_match;
    int min_payload;
    bit [47:0] rx_da;
    bit invalid_ethertype;
    bit bad_preamble;
    bit bad_sfd;
    bit rx_er_seen;
    bit len_mismatch_rx;

    bit rx_frame_active = 0;
    bit rx_frame_done   = 0;

    bit rx_inv_char_seen;
    bit rx_pending_term_check = 0;

   
    forever begin
      rx_er_seen = 0;

      // Collect data cycle by cycle using the single RS framer
      do begin
        @(v_intf.rx_mon_cb);
        rs_framer(
  v_intf.rx_mon_cb.RXD,
  v_intf.rx_mon_cb.RXC,
  rx_frame_active,
  rx_frame_q,
  rx_frame_done,
  rx_er_seen,
  rx_inv_char_seen,
  rx_pending_term_check  // <--- RX-specific cross-cycle state
);

      end while (!rx_frame_done);

       tr = eth_seq_item::type_id::create("tr", this);
      rx_pkt_count++;
      tr.rx_count = rx_pkt_count;
      tr.agt_addr = mac_addr;

      if (rx_frame_q.size() < 22) begin
        `uvm_error("RX_SHORT_FRAME", $sformatf("Frame smaller than L2 header, size=%0d", rx_frame_q.size()))
        statistics::rx_drop_pending[mac_addr]++;
        statistics::rx_bad_pkt_pending[mac_addr]++;
        eth_packet_tracker::print_packet("RX", this.get_full_name(), tr);
        rx_frame_q.delete();
        continue;
      end

      bad_pkt           = rx_er_seen; // Set bad packet if invalid control code or /E/ (0xFE) seen
      len_mismatch_rx   = 0;
      bad_preamble      = 0;
      bad_sfd           = 0;
      invalid_ethertype = 0;

      void'(check_preamble_sfd(rx_frame_q, bad_preamble, bad_sfd));
      if (bad_preamble || bad_sfd) bad_pkt = 1;

      // POP Preamble and SFD bytes from queue so indices line up
      repeat (PREAMBLE_SFD_BYTES) void'(rx_frame_q.pop_front());

      rx_da = {rx_frame_q[0], rx_frame_q[1], rx_frame_q[2],
               rx_frame_q[3], rx_frame_q[4], rx_frame_q[5]};
      da_match = is_da_valid(tr, rx_da) || (rx_da == mac_addr) || multi_mac_addr.exists(rx_da);

      // Bad preamble / sfd / rx_er
      if (bad_pkt) begin
        addr_classify_rx(tr);
        if (bad_preamble) `uvm_error("RX_PREAMBLE_ERR", $sformatf("Bad Preamble : Dropping packet frame_size=%0d", rx_frame_q.size()))
        if (bad_sfd)      `uvm_error("RX_SFD_ERR", $sformatf("Bad SFD : Dropping packet frame_size=%0d", rx_frame_q.size()))
        statistics::rx_drop_pending[mac_addr]++;
        statistics::rx_bad_pkt_pending[mac_addr]++;
        eth_packet_tracker::print_packet("RX", this.get_full_name(), tr);
        continue;
      end

      // Invalid DA
      if (!da_match) begin
        tr.da = rx_da;
        addr_classify_rx(tr);
        statistics::rx_bad_pkt_pending[mac_addr]++;
        `uvm_error("RX_INVALID_DA", $sformatf("Invalid DA = %h", rx_da))
        statistics::rx_drop_pending[mac_addr]++;
        eth_packet_tracker::print_packet("RX", this.get_full_name(), tr);
        continue;
      end

      crc_ok = frame_unpack(tr, rx_frame_q, 0, 1, len_mismatch_rx, invalid_ethertype);

      if (invalid_ethertype) begin
        addr_classify_rx(tr);
        statistics::rx_bad_pkt_pending[mac_addr]++;
        `uvm_error("RX_UNDEFINED_ETHERTYPE", $sformatf("Dropping packet : Undefined EtherType = %0d", tr.ether_type))
        statistics::rx_drop_pending[mac_addr]++;
        eth_packet_tracker::print_packet("RX", this.get_full_name(), tr);
        continue;
      end

      if (len_mismatch_rx && tr.payload.size() >= cfg.rx_frame_minlength-`HEADER) begin
        statistics::rx_bad_pkt_pending[mac_addr]++;
        addr_classify_rx(tr);
        `uvm_error("RX_LEN_DATA_MISMATCH", $sformatf("Length mismatch DA=%h SA=%h payload=%0d", tr.da, tr.sa, tr.payload.size()))
        statistics::rx_drop_pending[mac_addr]++;
        eth_packet_tracker::print_packet("RX", this.get_full_name(), tr);
        continue;
      end

      if (cfg.rx_single_vlan_enable[0]) begin
        if (!tr.vlan_en && !tr.pause_frame_en) begin
          `uvm_error("VLAN_MISSING", "Single VLAN mode enabled but frame has no VLAN tag")
          statistics::rx_bad_pkt_pending[mac_addr]++;
          addr_classify_rx(tr);
          statistics::rx_drop_pending[mac_addr]++;
          eth_packet_tracker::print_packet("RX", this.get_full_name(), tr);
          continue;
        end
        else if (tr.TPID != SVLAN_TPID && !tr.pause_frame_en) begin
          `uvm_error("VLAN_TPID", $sformatf("Invalid TPID = %h", tr.TPID))
          statistics::rx_bad_pkt_pending[mac_addr]++;
          addr_classify_rx(tr);
          statistics::rx_drop_pending[mac_addr]++;
          eth_packet_tracker::print_packet("RX", this.get_full_name(), tr);
          continue;
        end
        else begin
		if(!tr.pause_frame_en) statistics::rx_vlan_pending[mac_addr]++;
        end      
       end
      else if (tr.vlan_en && !tr.outer_vlan_en) begin
        statistics::rx_bad_pkt_pending[mac_addr]++;
        addr_classify_rx(tr);
        statistics::rx_drop_pending[mac_addr]++;
        eth_packet_tracker::print_packet("RX", this.get_full_name(), tr);
        continue;
      end
      if (tr.outer_vlan_en) begin
        statistics::rx_vlan_pending[mac_addr]++;
        if (tr.TPID != SVLAN_TPID)
          `uvm_error("VLAN_TPID", $sformatf("Invalid TPID = %h", tr.TPID))
      end

      // RUNT / FRAGMENT
      min_payload = get_min_payload(tr);
      if (tr.payload.size() < min_payload && tr.ether_type != MAC_CTRL_ETHERTYPE) begin
        addr_classify_rx(tr);
        statistics::rx_bad_pkt_pending[mac_addr]++;
        if (cfg.rx_crccheck_control[1]) begin
          if (crc_ok) begin
            statistics::rx_runt_pending[mac_addr]++;
            `uvm_info("RX_RUNT_PKT", $sformatf("Good runt packet payload=%0d", tr.payload.size()), UVM_LOW)
          end
          else
            statistics::rx_fragment_pending[mac_addr]++;
        end
        else
          statistics::rx_runt_pending[mac_addr]++;

        statistics::rx_drop_pending[mac_addr]++;
        eth_packet_tracker::print_packet("RX", this.get_full_name(), tr);
        continue;
      end

      `ifdef JUMBO_EN
      if (tr.payload.size() >= 1536 && tr.payload.size() < 16383 && crc_ok) begin
        statistics::rx_jumbo_pending[mac_addr]++;
        `uvm_info("RX_JUMBO_PKT", $sformatf("Jumbo detected payload=%0d", tr.payload.size()), UVM_HIGH)
      end
`else
      if (tr.payload.size() >= 1536) begin
        if (crc_ok) begin
          statistics::rx_bad_pkt_pending[mac_addr]++;
          addr_classify_rx(tr);
          `uvm_error("RX_LONG_PKT", $sformatf("Long packet payload=%0d", tr.payload.size()))
          eth_packet_tracker::print_packet("RX", this.get_full_name(), tr);
          continue;
        end
        else begin
          statistics::rx_jabber_pending[mac_addr]++;
          `uvm_error("RX_JABBER_PKT", $sformatf("Jabber detected payload=%0d", tr.payload.size()))
        end
      end
`endif
      if (cfg.rx_crccheck_control[1] && !crc_ok) begin
        addr_classify_rx(tr);
        statistics::rx_bad_pkt_pending[mac_addr]++;
        `uvm_error("RX_CRC_DROP", $sformatf("Dropping packet : Bad FCS DA=%h SA=%h CRC=%h", tr.da, tr.sa, tr.crc))
        statistics::rx_drop_pending[mac_addr]++;
        eth_packet_tracker::print_packet("RX", this.get_full_name(), tr);
        continue;
      end

      // Control frames (PAUSE/PFC) are classified, logged, and dropped here.
      if (handle_control_frame(0, tr, this.get_full_name()))
        continue;

      if (tr.payload.size() > 9000)
        statistics::rx_super_jumbo_pending[mac_addr]++;

      if (!cfg.rx_crccheck_control[1] || crc_ok) begin
        statistics::rx_good_pkt_pending[mac_addr]++;
        addr_classify_rx(tr);
      end

      $display("[MON_RX_STATS] Time:%0t | MAC:%012h | RX Good Pkts:%0d | RX Unicast Pkts:%0d",
        $time, mac_addr, statistics::rx_good_pkt_pending[mac_addr], statistics::rx_unicast_pending[mac_addr]);

      eth_packet_tracker::print_packet("RX", this.get_full_name(), tr);
      rx_ap.write(tr);
    end
  endtask
  //=============================================================================
  // TASK: addr_classify_rx
  //=============================================================================
  // PURPOSE:
  //   Classifies an RX frame's destination address (DA) type and updates
  //   per-MAC statistics accordingly.
  //==============================================================================

 function automatic void addr_classify_rx(eth_seq_item tr);
    if (tr.da == BROADCAST_MAC)
      statistics::rx_broadcast_pending[mac_addr]++;
    else if (multi_mac_addr.exists(tr.da) && !tr.pause_frame_en)
      statistics::rx_multicast_pending[mac_addr]++;
    else
      statistics::rx_unicast_pending[mac_addr]++;
  endfunction

  //==============================================================================
  // TASK: addr_classify_tx
  //===============================================================================
  // PURPOSE:
  //   Classifies a TX frame's destination address (DA) type and updates
  //   per-MAC statistics accordingly.
  //===============================================================================

  function automatic void addr_classify_tx(eth_seq_item tr);
    if (tr.da == BROADCAST_MAC) begin
      statistics::tx_broadcast_pending[mac_addr]++;
    end
    else if (tr.da[40] && !tr.pause_frame_en) begin
      foreach (tr.multi_mac_addr[i]) begin
        if (mac_addr != tr.mac_addr[i] && tr.multi_mac_addr[i].exists(tr.da)) begin
          statistics::tx_multicast_pending[mac_addr]++;
          break;
        end
      end
    end
    else
      statistics::tx_unicast_pending[mac_addr]++;
  endfunction

  //=============================================================================
  // FUNCTION: frame_unpack
  //=============================================================================
  //   1. (TX only, residue_mode=0) Copy preamble + SFD bytes into tr.
  //   2. Extract DA and SA (6 bytes each).
  //   3. Detect and extract VLAN tag(s) — supports single VLAN (0x8100) and
  //      double VLAN/QinQ (0x88A8 + 0x8100), via lookahead on the tag after
  //      the first one.
  //   4. Extract EtherType/Length field.
  //   5. If EtherType = 0x8808, extract PAUSE or PFC control fields and
  //      payload accordingly.
  //   6. Compute actual payload size and validate against claimed length
  //      (min payload depends on single/double VLAN/none); flags
  //      len_mismatch or invalid_ethertype as needed.
  //   7. Extract payload bytes and CRC field (last 4 bytes).
  //   8. Compute CRC over the frame:
  //        - TX (residue_mode=0): compares computed CRC directly against
  //          tr.crc, returns match.
  //        - RX (residue_mode=1): computes CRC residue including the CRC
  //          field itself, compares against fixed residue constant
  //          (0xC704DD7B), returns match.
  //================================================================================
  function bit frame_unpack(
      eth_seq_item  tr,
      ref bit [7:0] frame_q[$],
      input int     offset,
      input bit     residue_mode,
      output bit    len_mismatch,
      output bit    invalid_ethertype
    );

    int idx = offset;
    bit [31:0] next_crc;
    int payload_size;
    int actual_payload_size;
    int min_payload;
    bit [15:0] current_tpid;//added for double vlan tags
    len_mismatch = 0;
    invalid_ethertype = 0;

    if (residue_mode == 0) begin
      for (int i = 0; i < 7; i++) begin
        tr.preamble[i] = frame_q[i];
      end
      tr.sfd = frame_q[7];
    end

    // DA extraction
    for (int i = 5; i >= 0; i--)
    tr.da[i*8 +: 8] = frame_q[idx++];

    // SA extraction
    for (int i = 5; i >= 0; i--)
    tr.sa[i*8 +: 8] = frame_q[idx++];


    // Reset VLAN flags
    tr.vlan_en       = 0;
    tr.outer_vlan_en = 0;

    // Fetch Tag Identifier right after SA
    current_tpid = {frame_q[idx], frame_q[idx+1]};
    $display("[MON_DEBUG] Time: %0t | Tag Identifier (current_tpid) = 0x%04h", $time, current_tpid);
    // =========================================================
    // FLEXIBLE DOUBLE / SINGLE VLAN EXTRACTION LOGIC
    // =========================================================
    if (current_tpid == DVLAN_TPID || current_tpid == SVLAN_TPID) begin

      // Lookahead: Check if this is a Double VLAN frame (2 consecutive VLAN tags)
      bit [15:0] next_tpid = {frame_q[idx+4], frame_q[idx+5]};
      $display("[MON_DEBUG] Time: %0t | Lookahead Tag Identifier (next_tpid) = 0x%04h", $time, next_tpid);
      if (next_tpid == DVLAN_TPID || next_tpid == SVLAN_TPID) begin
        // --- DOUBLE VLAN FRAME (QinQ) ---
        tr.outer_vlan_en   = 1;
        tr.outer_TPID      = current_tpid;
        idx               += 2;

        tr.outer_PCP       = frame_q[idx][7:5];
        tr.outer_DEI       = frame_q[idx][4];
        tr.outer_VID[11:8] = frame_q[idx][3:0];
        idx++;
        tr.outer_VID[7:0]  = frame_q[idx];
        idx++;

        // Extract Inner VLAN Tag
        tr.vlan_en         = 1;
        tr.TPID            = {frame_q[idx], frame_q[idx+1]};
        idx               += 2;

        tr.PCP             = frame_q[idx][7:5];
        tr.DEI             = frame_q[idx][4];
        tr.VID[11:8]       = frame_q[idx][3:0];
        idx++;
        tr.VID[7:0]        = frame_q[idx];
        idx++;
      end
      else begin
        // --- SINGLE VLAN FRAME ---
        tr.vlan_en         = 1;
        tr.TPID            = current_tpid;
        idx               += 2;

        tr.PCP             = frame_q[idx][7:5];
        tr.DEI             = frame_q[idx][4];
        tr.VID[11:8]       = frame_q[idx][3:0];
        idx++;
        tr.VID[7:0]        = frame_q[idx];
        idx++;
      end
    end

    // EtherType / Length
    tr.ether_type[15:8] = frame_q[idx++];
    tr.ether_type[7:0]  = frame_q[idx++];

    // Pause frame extraction
    if (tr.ether_type == MAC_CTRL_ETHERTYPE) begin
      tr.pause_opc = {frame_q[idx], frame_q[idx+1]};
      idx += 2;
      if (tr.pause_opc == PAUSE_OPCODE) begin
        tr.pause_frame_en = 1;
        tr.pfc_frame_en   = 0;
        tr.pause_time     = {frame_q[idx], frame_q[idx+1]};
        idx += 2;
        tr.payload = new[`PAUSE_PAYLOAD_SIZE];
        for (int i = 0; i < `PAUSE_PAYLOAD_SIZE; i++)
          tr.payload[i] = frame_q[idx++];
      end
      else if (tr.pause_opc == PFC_OPCODE) begin
        tr.pause_frame_en     = 0;
        tr.pfc_frame_en       = 1;
        tr.priority_en_vector = {frame_q[idx], frame_q[idx+1]};
        idx += 2;
        for (int i = 0; i < 8; i++) begin
          tr.pfc_pause_time[i] = {frame_q[idx], frame_q[idx+1]};
          idx += 2;
        end
        tr.payload = new[`PFC_PAYLOAD_SIZE];
        for (int i = 0; i < `PFC_PAYLOAD_SIZE; i++)
          tr.payload[i] = frame_q[idx++];
      end
    end

    // Actual bytes on wire = total queue - bytes consumed so far - 4 (CRC)
    actual_payload_size = int'(frame_q.size() - idx - 4);
    
    if (actual_payload_size < 0) begin
      `uvm_error("MON_TRUNCATED_FRAME", $sformatf(
        "Truncated/malformed frame: idx=%0d frame_q.size()=%0d -> negative payload, dropping",
        idx, frame_q.size()))
      actual_payload_size = 0;
      len_mismatch = 1;
    end

    // LENGTH FIELD
    if (tr.ether_type <= 16'd1500 && !tr.pause_frame_en && !tr.pfc_frame_en) begin
      payload_size = int'(tr.ether_type);
      min_payload  = get_min_payload(tr);

      `uvm_info("MON_LEN_CHECK", $sformatf("ether_type(claimed)=%0d actual_payload=%0d", payload_size, actual_payload_size), UVM_LOW)

      if (payload_size < min_payload) begin
          if (actual_payload_size != min_payload) begin
          `uvm_error("MON_PADDING_ERROR", $sformatf("Wrong padding length=%0d actual=%0d expected=%0d",
            payload_size, actual_payload_size, min_payload))
          end
      end
      else begin
        if (payload_size != actual_payload_size) begin
          len_mismatch = 1;
          `uvm_error("MON_LEN_MISMATCH", $sformatf("DA=%h SA=%h claimed=%0d actual=%0d", tr.da, tr.sa, payload_size, actual_payload_size))
        end
      end
    end
    else if (tr.ether_type > 16'd1500 && tr.ether_type < 16'd1536) begin
      invalid_ethertype = 1;
    end
    else begin
      `uvm_info("VALID_ETHERTYPE", $sformatf("EtherType frame detected = %0h", tr.ether_type), UVM_LOW)
    end

    tr.payload = new[actual_payload_size];
    for (int i = actual_payload_size - 1; i >= 0; i--)
    tr.payload[i] = frame_q[idx++];

    // CRC field: always the last 4 bytes in the queue
    tr.crc = {frame_q[idx], frame_q[idx+1], frame_q[idx+2], frame_q[idx+3]};

    // Running CRC over data bytes (offset..idx-1), skipping preamble+SFD
    next_crc = 32'hFFFF_FFFF;
    for (int i = offset; i < idx; i++)
    next_crc = tr.crc_32(next_crc, frame_q[i]);

    if (!residue_mode) begin
      next_crc = ~next_crc;
      `uvm_info("TX MON UNPACKING", $sformatf("\n\tpreamble=%0p \n\tsfd= %0h \n\tDA = %h\n\tSA = %h\n\tether_type = 0x%0h\n\tpayload = %0d bytes\n\tCRC (frame) = 0x%h\n\tCRC (calc) = 0x%h\n\tCRC match = %0b\n\tframe size = %0h\n\tVLAN_EN = %0b\n\tTPID=%h PCP=%h DEI=%h VID=%h\n\tOuter_VLAN_EN = %0b\n\tOuter_TPID=%h Outer_PCP=%h Outer_DEI=%h Outer_VID=%h\n\tpause_en=%0b pause_opc=%h pause_time=%0d",
        tr.preamble, tr.sfd, tr.da, tr.sa, tr.ether_type, tr.payload.size(), tr.crc, next_crc, (next_crc == tr.crc), frame_q.size(), tr.vlan_en, tr.TPID, tr.PCP, tr.DEI, tr.VID, tr.outer_vlan_en, tr.outer_TPID, tr.outer_PCP, tr.outer_DEI, tr.outer_VID, tr.pause_frame_en, tr.pause_opc, tr.pause_time), UVM_LOW)

      return (next_crc == tr.crc);
    end

    for (int i = 0; i < 4; i++)
    next_crc = tr.crc_32(next_crc, tr.crc[8*i +: 8]);

    next_crc = {<<{next_crc}};

    `uvm_info("RX MON UNPACKING", $sformatf("\n\tDA = %h\n\tSA = %h\n\tether_type = 0x%0h\n\tpayload = %0d bytes\n\tCRC (frame) = 0x%h\n\tresidue = 0x%h\n\tCRC OK = %0b\n\tframe size = %0h\n\tVLAN_EN = %0b\n\tTPID=%h PCP=%h DEI=%h VID=%h\n\tOuter_VLAN_EN = %0b\n\tOuter_TPID=%h Outer_PCP=%h Outer_DEI=%h Outer_VID=%h\n\tpause_en=%0b pause_opc=%h",
      tr.da, tr.sa, tr.ether_type, tr.payload.size(), tr.crc, next_crc, (next_crc == 32'hC704DD7B), frame_q.size(), tr.vlan_en, tr.TPID, tr.PCP, tr.DEI, tr.VID, tr.outer_vlan_en, tr.outer_TPID, tr.outer_PCP, tr.outer_DEI, tr.outer_VID, tr.pause_frame_en, tr.pause_opc), UVM_LOW)


    tr.crc_residue = next_crc;
    return (next_crc == CRC_RESIDUE);
  endfunction

endclass


