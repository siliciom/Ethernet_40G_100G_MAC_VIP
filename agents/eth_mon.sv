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
      input  bit [`DATA_WIDTH-1:0] data,         // TXD / RXD bus (8 lanes x 8 bits)
      input  bit [`CTRL_WIDTH-1:0]  ctrl,         // TXC / RXC control bits
      inout  bit        frame_active,
      ref    bit [7:0]  frame_q[$],
      output bit        frame_done,
      ref bit        er_seen,
      ref bit        inv_ctrl_char_seen
    );
    frame_done = 0;
    inv_ctrl_char_seen =0;

    for (int lane = 0; lane < NUM_LANES; lane++) begin
      bit [7:0] lane_data = data[lane*8 +: 8];
      bit       lane_ctrl = ctrl[lane];

      // =========================================================
      // CASE 1: NOT currently in a frame -> Look for /S/ (0xFB)
      // =========================================================
      if (!frame_active) begin
        if (lane_ctrl && (lane_data == `START_CH)) begin
          frame_active = 1;
          frame_q.delete();          // Clear queue for new frame
          frame_q.push_back(lane_data);  // Standardize /S/ to preamble 0x55

          if (lane != 0) begin
            er_seen = 1;             // Flag misaligned start error
            `uvm_error("RS_FRAMER_ERR", $sformatf(
              "Misaligned /S/ (0xFB) on Lane %0d at Time %0t : recording bad packet",
              lane, $time))
          end
        end
        /*
      else if (lane_ctrl && (lane_data != `IDLE_CH)) begin
      // Control character asserted, but it's neither a valid /S/ nor /I/ (idle)
      er_seen = 1;
      frame_active       = 1;
      inv_ctrl_char_seen = 1;
        frame_q.delete();          // Clear queue for new frame
       frame_q.push_back(lane_data);
      `uvm_error("RS_INVALID_CTRL_CHAR", $sformatf(
         "Invalid control character 0x%0h on Lane %0d at Time %0t while idle (expected /S/=0xFB or /I/)",
         lane_data, lane, $time))
    end
    */
      end

      // =========================================================
      // CASE 2: Currently in an ACTIVE frame
      // =========================================================
      else begin
        if (lane_ctrl) begin
          case (lane_data)
            // Normal Frame Terminate /T/
            `TERMINATE_CH: begin
              frame_active = 0;
              frame_done   = 1;
             // dump_queue(frame_q, er_seen);
              break; // Done with current packet
            end

            // Transmission Error /E/ mid-frame
            `ERROR_CH: begin
              er_seen = 1;
              `uvm_error("RS_FRAMER_ERROR_CHAR", $sformatf(
                "Transmission Error /E/ (0xFE) detected on Lane %0d at Time %0t",
                lane, $time))

              frame_q.push_back(lane_data); // Push error symbol to queue

            end

            // New Start /S/ mid-frame without prior /T/ (Protocol Abort)
            `START_CH: begin
              er_seen    = 1;
              frame_done = 1; // Complete current bad packet for rx_mac
             // dump_queue(frame_q, er_seen);

              // Reset state to start the NEXT frame on this same byte
              frame_active = 1;
              frame_q.delete();
              frame_q.push_back(8'h55); // Fixed syntax error here
              if (lane != 0) begin
                `uvm_error("RS_FRAMER_ERR", $sformatf(
                  "Nested misaligned /S/ on Lane %0d at Time %0t", lane, $time))
              end
            end

            // Idle or unexpected control code mid-frame -> Abort & complete bad pkt
            default: begin
              er_seen      = 1;
              frame_active = 0;
              frame_done   = 1; // Flush bad frame to rx_mac
              //dump_queue(frame_q, er_seen);
              break;
            end
          endcase
        end
        else begin
          // Normal Payload Byte
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
          tx_inv_char_seen
        );

        if (tx_inv_char_seen) begin
          `uvm_error("TX_INVALID_CHAR", "Invalid control character detected on TX bus")
        end
      end while (!tx_frame_done);
      crc_ok               = 0;
      da_match             = 0;
      invalid_ethertype_tx = 0;
      bad_preamble_tx      = 0;
      bad_sfd_tx           = 0;
      len_mismatch_tx      = 0;
      pkt_bad              = tx_er_seen; // Flags bad packet if invalid control char or /E/ was seen

      // Check preamble and SFD from extracted raw queue
      if (tx_frame_q.size() >= 8) begin
        for (int i = 0; i < 7; i++) begin
          if ((i == 0 && tx_frame_q[i] != `START_CH) || (i > 0 && tx_frame_q[i] != `PREAMBLE))begin
            pkt_bad = 1;
            bad_preamble_tx = 1;
          end
        end
        if (tx_frame_q[7] != `SFD) begin
          pkt_bad = 1;
          bad_sfd_tx = 1;
        end
      end
      else begin
        pkt_bad = 1; // Runt / incomplete preamble
      end
      // CREATE TR
      tr = eth_seq_item::type_id::create("tr", this);
      tx_pkt_count++;
      tr.tx_count = tx_pkt_count;

      if (tx_frame_q.size() < 14) begin
        `uvm_error("TX_SHORT_FRAME", "Frame smaller than L2 header")
        //continue;
      end

      // DA EXTRACTION
      tx_da = {
        tx_frame_q[8],
        tx_frame_q[9],
        tx_frame_q[10],
        tx_frame_q[11],
        tx_frame_q[12],
        tx_frame_q[13]
      };

      // DA MATCH
      foreach (tr.mac_addr[i]) begin
        if (tx_da == tr.mac_addr[i]) begin
          da_match = 1;
          break;
        end
      end

      if (tx_da == 48'hFF_FF_FF_FF_FF_FF)
      da_match = 1;

      foreach(tr.multi_mac_addr[i]) begin
        if(mac_addr!=tr.mac_addr[i] && tr.multi_mac_addr[i].exists(tx_da))
        da_match = 1;
      end

      // UNPACK
      crc_ok = frame_unpack(tr, tx_frame_q, 8, 0, len_mismatch_tx, invalid_ethertype_tx);

      if (cfg.tx_single_vlan_enable[0] ) begin
        //Single VLAN mode enabled
        if(!tr.vlan_en) begin
          `uvm_error("VLAN_MISSING", "Single VLAN mode enabled but frame has no VLAN tag")
          pkt_bad=1;
        end
        else begin
          if (tr.TPID != 16'h8100) begin
            `uvm_error("VLAN_TPID", $sformatf("Invalid TPID = %h", tr.TPID))
            pkt_bad=1;
          end
          else begin
            statistics::tx_vlan_pending[mac_addr]++;
            //  addr_classify_tx(tr);
          end
        end
      end
      else begin
        //Single VLAN mode disabled
        if (tr.vlan_en && !tr.outer_vlan_en) begin
          //`uvm_error("VLAN_UNEXPECTED", $sformatf("VLAN tag present but single_vlan_enable=0, TPID=%h", tr.TPID))
          //statistics::tx_vlan_pending[mac_addr]++;
          //addr_classify_tx(tr);
          pkt_bad=1;
        end
      end
      addr_classify_tx(tr);

      //added for double vlan frames
      if (tr.outer_vlan_en) begin
        if (tr.outer_TPID != 16'h88A8) begin
          `uvm_error("DOUBLE_VLAN_TPID", $sformatf("Invalid Inner TPID = %h", tr.outer_TPID))
        end
      end

      if (!da_match)
      pkt_bad = 1;

      if (invalid_ethertype_tx)
      pkt_bad = 1;

      if (len_mismatch_tx && cfg.tx_frame_minlength-`HEADER >=46)
      pkt_bad = 1;

      if (!crc_ok) begin
        pkt_bad = 1;
        // `uvm_error("TX_FRAGMENT_CRC", $sformatf("Bad CRC DA=%h SA=%h CRC=%h", tr.da, tr.sa, tr.crc))
      end
      // ERROR PRINTS
      /* if (tx_er_seen) begin
        `uvm_error("TX_ERR", $sformatf("TX RS Error or Invalid Control Code detected. frame_size=%0d", tx_frame_q.size()))
      end  */

      if (bad_preamble_tx) begin
        `uvm_error("TX_PREAMBLE_ERR", $sformatf("Bad Preamble frame_size=%0d", tx_frame_q.size()))
      end

      if (bad_sfd_tx) begin
        `uvm_error("TX_SFD_ERR", $sformatf("Bad SFD frame_size=%0d", tx_frame_q.size()))
      end

      if (!da_match) begin
        `uvm_error("TX_INVALID_DA", $sformatf("Invalid DA=%h", tx_da))
      end

      if (invalid_ethertype_tx) begin
        `uvm_error("TX_UNDEFINED_ETHERTYPE", $sformatf("Undefined EtherType=%0d", tr.ether_type))
      end

      if (len_mismatch_tx && tr.payload.size() >= cfg.tx_frame_minlength-`HEADER) begin //TO-DO
        `uvm_error("TX_LEN_DATA_MISMATCH", $sformatf("Length mismatch detected"))
      end

      if (!crc_ok && tr.payload.size() >= cfg.tx_frame_minlength-`HEADER) begin //TO-DO
        `uvm_error("TX_CRC_ERR", $sformatf("Bad CRC DA=%h SA=%h CRC=%h", tr.da, tr.sa, tr.crc))
      end

      if (!crc_ok && tr.payload.size() < cfg.tx_frame_minlength-`HEADER) begin
        `uvm_error("TX_FRAGMENT_CRC", $sformatf("Bad CRC DA=%h SA=%h CRC=%h", tr.da, tr.sa, tr.crc))
      end
      //addr_classify_tx(tr);
      // VLAN
      /* if (cfg.tx_single_vlan_enable[0] && tr.vlan_en)
        statistics::tx_vlan_pending[mac_addr]++;
      else if(!cfg.tx_single_vlan_enable[0] && tr.vlan_en)
         statistics::tx_bad_pkt_pending[mac_addr]++; */

      if (tr.outer_vlan_en)//added for double vlan
      statistics::tx_vlan_pending[mac_addr]++;


      // RUNT / FRAGMENT
      // min_payload = (tr.vlan_en) ? `VLAN_PAYLOAD_SIZE : cfg.tx_frame_minlength-`HEADER;
      if (tr.outer_vlan_en)//added for double vlan tags
      min_payload = `DOUBLE_VLAN_PAYLOAD_SIZE; // Typically 38 bytes
      else if (tr.vlan_en)
      min_payload = `VLAN_PAYLOAD_SIZE;        // 42 bytes
      else
      min_payload = `MIN_PAYLOAD_SIZE;         // 46 bytes

      if (tr.payload.size() < min_payload && tr.ether_type != 16'h8808) begin
        if (crc_ok) begin
          statistics::tx_runt_pending[mac_addr]++;
          `uvm_info("TX_RUNT_PKT", $sformatf("Good runt packet payload=%0d", tr.payload.size()), UVM_LOW)
          pkt_bad = 1;
        end
        else begin
          statistics::tx_fragment_pending[mac_addr]++;
          pkt_bad = 1;
          `uvm_error("TX_FRAGMENT_PKT", $sformatf("Fragment detected payload=%0d", tr.payload.size()))
        end
      end
      `ifdef JUMBO_EN
      if (tr.payload.size() > cfg.tx_frame_maxlength+`HEADER && tr.payload.size()<16383) begin
        if (crc_ok) begin
          statistics::tx_jumbo_pending[mac_addr]++;
          `uvm_info("TX_JUMBO_PKT", $sformatf("Jumbo detected payload=%0d", tr.payload.size()), UVM_LOW)
        end
      end
      `else
      if(tr.payload.size() >= 1536) begin
        if(crc_ok) begin
          pkt_bad=1;
          `uvm_error("TX_LONG_PKT", $sformatf( "Long packet payload=%0d", tr.payload.size()))
        end
        else begin
          statistics::tx_jabber_pending[mac_addr]++;
          `uvm_error("TX_JABBER_PKT",$sformatf("Jabber detected payload=%0d",tr.payload.size()))
          pkt_bad=1;
        end
      end
      `endif
      // BLOCK PAUSE TO SCOREBOARD
      if (tr.pause_frame_en && tr.pause_opc == 16'h0001 && tr.ether_type == 16'h8808) begin
        if (tr.payload.size() < 42 && tr.padding_en) begin
          `uvm_error("Short Pause_pkt", $sformatf("pause_frame_en=%0d ether_type=%h pause_opc=%h payload_size=%0d",
            tr.pause_frame_en, tr.ether_type, tr.pause_opc, tr.payload.size()))
          statistics::tx_bad_pkt_pending[mac_addr]++;
          statistics::tx_drop_pending[mac_addr]++;
          continue;

        end
        else begin
          statistics::tx_good_pkt_pending[mac_addr]++;
          `uvm_info("monnnnn",$sforamatf("good_count=%d", statistics::tx_good_pkt_pending[mac_addr]),UVM_LOW)
          if (tr.pause_time == 0)
          statistics::tx_pause_xon_pending[mac_addr]++;
          else
          statistics::tx_pause_xoff_pending[mac_addr]++;

          `uvm_info("RX_PAUSE_BLOCK", $sformatf("pause_frame_en=%0d ether_type=%h pause_opc=%h pause_time=%0d",
            tr.pause_frame_en, tr.ether_type, tr.pause_opc, tr.pause_time), UVM_LOW)
          statistics::tx_drop_pending[mac_addr]++;

          continue;
        end
      end
      else if (tr.pfc_frame_en && tr.pause_opc == 16'h0101 && tr.ether_type == 16'h8808) begin
        if (tr.payload.size() < 26 && tr.padding_en) begin
          `uvm_error("Short Pfc_pkt", $sformatf("pause_frame_en=%0d ether_type=%h pause_opc=%h payload_size=%0d",
            tr.pause_frame_en, tr.ether_type, tr.pause_opc, tr.payload.size()))
          statistics::tx_bad_pkt_pending[mac_addr]++;
          statistics::tx_drop_pending[mac_addr]++;

          continue;
        end
        else begin
          statistics::tx_good_pkt_pending[mac_addr]++;
          for (int i = 0; i < 8; i++) begin
            if (tr.priority_en_vector[i]) begin
              if (tr.pfc_pause_time[i] == 0) begin
                statistics::tx_pfc_xon_pending[mac_addr]++;
                case (i)
                  0: statistics::tx_pfc_xon_prio0_pending[mac_addr]++;
                  1: statistics::tx_pfc_xon_prio1_pending[mac_addr]++;
                  2: statistics::tx_pfc_xon_prio2_pending[mac_addr]++;
                  3: statistics::tx_pfc_xon_prio3_pending[mac_addr]++;
                  4: statistics::tx_pfc_xon_prio4_pending[mac_addr]++;
                  5: statistics::tx_pfc_xon_prio5_pending[mac_addr]++;
                  6: statistics::tx_pfc_xon_prio6_pending[mac_addr]++;
                  7: statistics::tx_pfc_xon_prio7_pending[mac_addr]++;
                endcase
              end
              else begin
                statistics::tx_pfc_xoff_pending[mac_addr]++;
                case (i)
                  0: statistics::tx_pfc_xoff_prio0_pending[mac_addr]++;
                  1: statistics::tx_pfc_xoff_prio1_pending[mac_addr]++;
                  2: statistics::tx_pfc_xoff_prio2_pending[mac_addr]++;
                  3: statistics::tx_pfc_xoff_prio3_pending[mac_addr]++;
                  4: statistics::tx_pfc_xoff_prio4_pending[mac_addr]++;
                  5: statistics::tx_pfc_xoff_prio5_pending[mac_addr]++;
                  6: statistics::tx_pfc_xoff_prio6_pending[mac_addr]++;
                  7: statistics::tx_pfc_xoff_prio7_pending[mac_addr]++;
                endcase
              end
            end
          end
        end
        `uvm_info("RX_PFC_BLOCK", "PFC frame blocked from scoreboard", UVM_LOW)
        statistics::tx_drop_pending[mac_addr]++;
        //statistics::tx_drop_pending[mac_addr]++;
        continue;
      end
      else if (tr.ether_type == 16'h8808 && tr.pause_opc != 16'h0001 && tr.pause_opc != 16'h0101) begin
        statistics::tx_control_pkt_pending[mac_addr]++;
        `uvm_info("RX_CONTROL", $sformatf("Unknown control packet opcode=%h sent to scoreboard", tr.pause_opc), UVM_LOW)
      end
      else begin
        `uvm_info("RX_NORMAL_PKT", "RX packet", UVM_LOW)
      end

      if (pkt_bad)
      tr.err_b = 1;

      if (pkt_bad) begin
        statistics::tx_bad_pkt_pending[mac_addr]++;
      end
      else begin
        statistics::tx_good_pkt_pending[mac_addr]++;
        `uvm_info("monnnnn",$sforamatf("good_count=%d", statistics::tx_good_pkt_pending[mac_addr]),UVM_LOW)
      end
      // Print counters after updating
      $display("[MON_STATS] Time:%0t | MAC:%012h | TX Good Pkts:%0d | TX Unicast Pkts:%0d",
        $time, mac_addr,
        statistics::tx_good_pkt_pending[mac_addr],
        statistics::tx_unicast_pending[mac_addr]);
      eth_packet_tracker::print_packet("TX",this.get_full_name(),tr);
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
          rx_inv_char_seen
        );
        if (rx_inv_char_seen) begin
          `uvm_error("RX_INVALID_CHAR", "Invalid control character detected on TX bus")
        end

      end while (!rx_frame_done);

      if (rx_frame_q.size() < 22) begin
        `uvm_error("RX_SHORT_FRAME",
          $sformatf("Frame smaller than L2 header, size=%0d", rx_frame_q.size()))
        statistics::rx_drop_pending[mac_addr]++;
        statistics::rx_bad_pkt_pending[mac_addr]++;
        rx_frame_q.delete();
        continue;
      end

      bad_pkt           = rx_er_seen; // Set bad packet if invalid control code or /E/ (0xFE) seen
      len_mismatch_rx   = 0;
      bad_preamble      = 0;
      bad_sfd           = 0;
      invalid_ethertype = 0;

      // Check preamble and SFD from extracted queue
      if (rx_frame_q.size() >= 8) begin
        for (int i = 0; i < 7; i++) begin
          if ((i == 0 && rx_frame_q[i] != `START_CH) || (i > 0 && rx_frame_q[i] != `PREAMBLE)) begin
            bad_pkt = 1;
            bad_preamble = 1;
          end
        end
        if (rx_frame_q[7] != `SFD) begin
          bad_pkt = 1;
          bad_sfd = 1;
        end
      end else begin
        bad_pkt = 1;
      end

      // Create transaction
      tr = eth_seq_item::type_id::create("tr", this);
      rx_pkt_count++;
      tr.rx_count = rx_pkt_count;
      tr.agt_addr = mac_addr;

      // DROP / POP Preamble and SFD bytes from queue so indices line up
      repeat (8) void'(rx_frame_q.pop_front());
      // DA extraction
      rx_da = {
        rx_frame_q[0],
        rx_frame_q[1],
        rx_frame_q[2],
        rx_frame_q[3],
        rx_frame_q[4],
        rx_frame_q[5]
      };

      // DA validation
      da_match = 0;

      if (rx_da == mac_addr)
      da_match = 1;

      if (rx_da == 48'hFF_FF_FF_FF_FF_FF)
      da_match = 1;

      if (multi_mac_addr.exists(rx_da))
      da_match = 1;

      // Bad preamble / sfd / rx_er
      if (bad_pkt) begin
        addr_classify_rx(tr);

        if (bad_preamble) begin
          `uvm_error("RX_PREAMBLE_ERR", $sformatf("Bad Preamble detected : Dropping packet frame_size=%0d", rx_frame_q.size()))
        end
        if (bad_sfd) begin
          `uvm_error("RX_SFD_ERR", $sformatf("Bad SFD detected : Dropping packet frame_size=%0d", rx_frame_q.size()))
        end

        statistics::rx_drop_pending[mac_addr]++;
        statistics::rx_bad_pkt_pending[mac_addr]++;
        eth_packet_tracker::print_packet("RX",this.get_full_name(),tr);
        continue;

      end

      // Invalid DA
      if (!da_match) begin
        tr.da = rx_da;
        addr_classify_rx(tr);
        statistics::rx_bad_pkt_pending[mac_addr]++;
        `uvm_error("RX_INVALID_DA", $sformatf("Invalid DA = %h", rx_da))
        statistics::rx_drop_pending[mac_addr]++;
        eth_packet_tracker::print_packet("RX",this.get_full_name(),tr);
        continue;
      end

      crc_ok = frame_unpack(tr, rx_frame_q, 0, 1, len_mismatch_rx, invalid_ethertype);

      if (invalid_ethertype) begin
        addr_classify_rx(tr);
        statistics::rx_bad_pkt_pending[mac_addr]++;
        `uvm_error("RX_UNDEFINED_ETHERTYPE", $sformatf("Dropping packet : Undefined EtherType = %0d", tr.ether_type))
        statistics::rx_drop_pending[mac_addr]++;
        eth_packet_tracker::print_packet("RX",this.get_full_name(),tr);
        continue;
      end

      if (len_mismatch_rx && tr.payload.size() >= cfg.rx_frame_minlength-`HEADER) begin
        statistics::rx_bad_pkt_pending[mac_addr]++;
        addr_classify_rx(tr);
        `uvm_error("RX_LEN_DATA_MISMATCH", $sformatf("Length mismatch DA=%h SA=%h payload=%0d", tr.da, tr.sa, tr.payload.size()))
        statistics::rx_drop_pending[mac_addr]++;

        eth_packet_tracker::print_packet("RX",this.get_full_name(),tr);
        continue;
      end

      if(cfg.rx_single_vlan_enable[0] ) begin
        //Single VLAN mode enabled
        if (!tr.vlan_en) begin
          `uvm_error("VLAN_MISSING", "Single VLAN mode enabled but frame has no VLAN tag")
          statistics::rx_bad_pkt_pending[mac_addr]++;
          addr_classify_rx(tr);
          statistics::rx_drop_pending[mac_addr]++;
          eth_packet_tracker::print_packet("RX",this.get_full_name(),tr);
          continue;
        end
        else begin
          if(tr.TPID != 16'h8100) begin
            `uvm_error("VLAN_TPID", $sformatf("Invalid TPID = %h", tr.TPID))
            statistics::rx_bad_pkt_pending[mac_addr]++;
            addr_classify_rx(tr);
            statistics::rx_drop_pending[mac_addr]++;
            eth_packet_tracker::print_packet("RX",this.get_full_name(),tr);
            continue;
          end
          else begin
            statistics::rx_vlan_pending[mac_addr]++;
            // addr_classify_rx(tr);
          end

        end
      end
      else begin
        // Single VLAN mode disabled
        if (tr.vlan_en && !(tr.outer_vlan_en)) begin
          // `uvm_error("VLAN_UNEXPECTED", $sformatf("VLAN tag present but single_vlan_enable=0, TPID=%h", tr.TPID))
          // statistics::rx_vlan_pending[mac_addr]++;
          statistics::rx_bad_pkt_pending[mac_addr]++;
          addr_classify_rx(tr);
          statistics::rx_drop_pending[mac_addr]++;
          eth_packet_tracker::print_packet("RX",this.get_full_name(),tr);
          continue;
        end
      end
      if (tr.outer_vlan_en) begin//added for double vlan
        statistics::rx_vlan_pending[mac_addr]++;
        if (tr.TPID != 16'h8100) begin
          `uvm_error("VLAN_TPID", $sformatf("Invalid TPID = %h", tr.TPID))
        end
      end

      // RUNT / FRAGMENT
      // min_payload = (tr.vlan_en) ? `VLAN_PAYLOAD_SIZE : cfg.rx_frame_minlength-`HEADER;

      if (tr.outer_vlan_en)//added for double vlan tag
      min_payload = `DOUBLE_VLAN_PAYLOAD_SIZE;
      else if (tr.vlan_en)
      min_payload = `VLAN_PAYLOAD_SIZE;
      else
      min_payload = `MIN_PAYLOAD_SIZE;


      if (tr.payload.size() < min_payload && tr.ether_type != 16'h8808) begin
        addr_classify_rx(tr);
        statistics::rx_bad_pkt_pending[mac_addr]++;
        if(cfg.rx_crccheck_control[1]) begin
          //CRC Checking enabled
          if(crc_ok) begin
            statistics::rx_runt_pending[mac_addr]++;
            `uvm_info("RX_RUNT_PKT", $sformatf("Good runt packet payload=%0d", tr.payload.size()), UVM_LOW)
          end
          else begin
            statistics::rx_fragment_pending[mac_addr]++;
          end
        end

        else begin
          //CRC checking disabled
          statistics::rx_runt_pending[mac_addr]++;
        end

        statistics::rx_drop_pending[mac_addr]++;
        eth_packet_tracker::print_packet("RX",this.get_full_name(),tr);
        continue;
      end

      `ifdef JUMBO_EN
      if(tr.payload.size()>=1536 && tr.payload.size()<16383) begin
        if(crc_ok) begin
          statistics::rx_jumbo_pending[mac_addr]++;
          `uvm_info("RX_JUMBO_PKT",$sformatf("Jumbo detected payload=%0d",tr.payload.size()),UVM_HIGH)
        end
      end
      `else
      if(tr.payload.size() >= 1536) begin
        if(crc_ok) begin
          bad_pkt = 1;
          statistics::rx_bad_pkt_pending[mac_addr]++;
          addr_classify_rx(tr);
          `uvm_error("RX_LONG_PKT", $sformatf( "Long packet payload=%0d", tr.payload.size()))
          continue;
        end
        else begin
          statistics::rx_jabber_pending[mac_addr]++;
          `uvm_error("RX_JABBER_PKT",$sformatf("Jabber detected payload=%0d",tr.payload.size()))

        end
      end
      `endif
      if (cfg.rx_crccheck_control[1] && !crc_ok) begin
        addr_classify_rx(tr);
        statistics::rx_bad_pkt_pending[mac_addr]++;
        `uvm_error("RX_CRC_DROP", $sformatf("Dropping packet : Bad FCS DA=%h SA=%h CRC=%h", tr.da, tr.sa, tr.crc))
        statistics::rx_drop_pending[mac_addr]++;

        eth_packet_tracker::print_packet("RX",this.get_full_name(),tr);
        continue;
      end

      // PAUSE FRAME
      if (tr.pause_frame_en && tr.pause_opc == 16'h0001 && tr.ether_type == 16'h8808) begin
        if (tr.payload.size() < 42 && tr.padding_en) begin
          `uvm_error("Short Pause_pkt", $sformatf("pause_frame_en=%0d ether_type=%h pause_opc=%h payload_size=%0d",
            tr.pause_frame_en, tr.ether_type, tr.pause_opc, tr.payload.size()))
          statistics::tx_bad_pkt_pending[mac_addr]++;
          statistics::rx_drop_pending[mac_addr]++;

          eth_packet_tracker::print_packet("RX",this.get_full_name(),tr);
          continue;
        end
        else begin
          statistics::pause_value[mac_addr]  = tr.pause_time;
          statistics::pause_flag[mac_addr]   = 1;
          statistics::pause_update[mac_addr] = 1;
          statistics::rx_good_pkt_pending[mac_addr]++;
          addr_classify_rx(tr);
          if (tr.pause_time == 0)
          statistics::rx_pause_xon_pending[mac_addr]++;
          else
          statistics::rx_pause_xoff_pending[mac_addr]++;

          `uvm_info("RX_PAUSE_BLOCK", $sformatf("pause_frame_en=%0d ether_type=%h pause_opc=%h pause_time=%0d",
            tr.pause_frame_en, tr.ether_type, tr.pause_opc, tr.pause_time), UVM_LOW)
          statistics::rx_drop_pending[mac_addr]++;

          continue;
        end
      end

      // PFC FRAME
      else if (tr.pfc_frame_en && tr.pause_opc == 16'h0101 && tr.ether_type == 16'h8808) begin
        if (tr.payload.size() < 26 && tr.padding_en) begin
          `uvm_error("Short Pfc_pkt", $sformatf("pause_frame_en=%0d ether_type=%h pause_opc=%h payload_size=%0d",
            tr.pfc_frame_en, tr.ether_type, tr.pause_opc, tr.payload.size()))
          statistics::tx_bad_pkt_pending[mac_addr]++;
          statistics::rx_drop_pending[mac_addr]++;

          eth_packet_tracker::print_packet("RX",this.get_full_name(),tr);
          continue;
        end
        else begin
          statistics::rx_good_pkt_pending[mac_addr]++;
          addr_classify_rx(tr);
          for (int i = 0; i < 8; i++) begin
            if (tr.priority_en_vector[i]) begin
              statistics::pfc_value[mac_addr][i] = tr.pfc_pause_time[i];
              statistics::pfc_flag[mac_addr][i] = 1;
              statistics::pfc_update[mac_addr][i] = 1;
              if (tr.pfc_pause_time[i] == 0) begin
                case (i)
                  0: statistics::rx_pfc_xon_prio0_pending[mac_addr]++;
                  1: statistics::rx_pfc_xon_prio1_pending[mac_addr]++;
                  2: statistics::rx_pfc_xon_prio2_pending[mac_addr]++;
                  3: statistics::rx_pfc_xon_prio3_pending[mac_addr]++;
                  4: statistics::rx_pfc_xon_prio4_pending[mac_addr]++;
                  5: statistics::rx_pfc_xon_prio5_pending[mac_addr]++;
                  6: statistics::rx_pfc_xon_prio6_pending[mac_addr]++;
                  7: statistics::rx_pfc_xon_prio7_pending[mac_addr]++;
                endcase
              end
              else begin
                case (i)
                  0: statistics::rx_pfc_xoff_prio0_pending[mac_addr]++;
                  1: statistics::rx_pfc_xoff_prio1_pending[mac_addr]++;
                  2: statistics::rx_pfc_xoff_prio2_pending[mac_addr]++;
                  3: statistics::rx_pfc_xoff_prio3_pending[mac_addr]++;
                  4: statistics::rx_pfc_xoff_prio4_pending[mac_addr]++;
                  5: statistics::rx_pfc_xoff_prio5_pending[mac_addr]++;
                  6: statistics::rx_pfc_xoff_prio6_pending[mac_addr]++;
                  7: statistics::rx_pfc_xoff_prio7_pending[mac_addr]++;
                endcase
              end
              `uvm_info("MON_PFFFFC", $sformatf("pfc_flag[%h][%h]=%d", mac_addr, i, statistics::pfc_flag[mac_addr][i]), UVM_LOW)
            end
          end
        end
        `uvm_info("RX_PFC_BLOCK", "PFC frame blocked from scoreboard", UVM_LOW)
        statistics::rx_drop_pending[mac_addr]++;

        eth_packet_tracker::print_packet("RX",this.get_full_name(),tr);
        continue;
      end
      else if (tr.ether_type == 16'h8808 && tr.pause_opc != 16'h0001 && tr.pause_opc != 16'h0101) begin
        statistics::rx_control_pkt_pending[mac_addr]++;
        `uvm_info("RX_CONTROL", $sformatf("Unknown control packet opcode=%h sent to scoreboard", tr.pause_opc), UVM_LOW)
      end
      else begin
        `uvm_info("RX_NORMAL_PKT", "RX packet", UVM_LOW)
      end

      if (tr.payload.size() > 9000) begin
        statistics::rx_super_jumbo_pending[mac_addr]++;
      end

      if(cfg.rx_crccheck_control[1]) begin
        if (!bad_pkt && crc_ok) begin
          statistics::rx_good_pkt_pending[mac_addr]++;
          addr_classify_rx(tr);
        end
      end
      else begin
        if(!bad_pkt) begin
          statistics::rx_good_pkt_pending[mac_addr]++;
          addr_classify_rx(tr);
        end
      end

      $display("[MON__RX_STATS] Time:%0t | MAC:%012h | RX Good Pkts:%0d | RX Unicast Pkts:%0d",
        $time, mac_addr,
        statistics::rx_good_pkt_pending[mac_addr],
        statistics::rx_unicast_pending[mac_addr]);

      eth_packet_tracker::print_packet("RX",this.get_full_name(),tr);
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

  task addr_classify_rx(eth_seq_item tr);
    if (tr.da == 48'hFF_FF_FF_FF_FF_FF)
    statistics::rx_broadcast_pending[mac_addr]++;
    else if (multi_mac_addr.exists(tr.da))
    statistics::rx_multicast_pending[mac_addr]++;
    else
    statistics::rx_unicast_pending[mac_addr]++;
  endtask
  //==============================================================================
  // TASK: addr_classify_tx
  //===============================================================================
  // PURPOSE:
  //   Classifies a TX frame's destination address (DA) type and updates
  //   per-MAC statistics accordingly.
  //===============================================================================

  task addr_classify_tx(eth_seq_item tr);
    if (tr.da == 48'hFF_FF_FF_FF_FF_FF)
    statistics::tx_broadcast_pending[mac_addr]++;
    else if (tr.da[40]) begin
      foreach (tr.multi_mac_addr[i]) begin
        if (mac_addr != tr.mac_addr[i] && tr.multi_mac_addr[i].exists(tr.da)) begin
          statistics::tx_multicast_pending[mac_addr]++;
          break;
        end
      end
    end
    else
    statistics::tx_unicast_pending[mac_addr]++;
  endtask

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
    if (current_tpid == 16'h88A8 || current_tpid == 16'h8100) begin

      // Lookahead: Check if this is a Double VLAN frame (2 consecutive VLAN tags)
      bit [15:0] next_tpid = {frame_q[idx+4], frame_q[idx+5]};
      $display("[MON_DEBUG] Time: %0t | Lookahead Tag Identifier (next_tpid) = 0x%04h", $time, next_tpid);
      if (next_tpid == 16'h88A8 || next_tpid == 16'h8100) begin
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
    if (tr.ether_type == 16'h8808) begin
      tr.pause_opc = {frame_q[idx], frame_q[idx+1]};
      idx += 2;
      if (tr.pause_opc == 16'h0001) begin
        tr.pause_frame_en = 1;
        tr.pfc_frame_en   = 0;
        tr.pause_time     = {frame_q[idx], frame_q[idx+1]};
        idx += 2;
        tr.payload        = new[`PAUSE_PAYLOAD_SIZE];
        for (int i = 0; i < `PAUSE_PAYLOAD_SIZE; i++)
        tr.payload[i]   = frame_q[idx++];
      end
      else if (tr.pause_opc == 16'h0101) begin
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

    // LENGTH FIELD
    if (tr.ether_type <= 16'd1500 && !tr.pause_frame_en && !tr.pfc_frame_en) begin
      payload_size = int'(tr.ether_type);
      if (tr.outer_vlan_en)
      min_payload = `DOUBLE_VLAN_PAYLOAD_SIZE;//added for double vlan
      else if (tr.vlan_en)
      min_payload = `VLAN_PAYLOAD_SIZE;
      else
      min_payload = `MIN_PAYLOAD_SIZE;

      `uvm_info("MON_LEN_CHECK", $sformatf("ether_type(claimed)=%0d actual_payload=%0d", payload_size, actual_payload_size), UVM_LOW)

      if (payload_size < min_payload) begin
        $display("aaaaaaaaaaaactual=%d, min_payload=%d",actual_payload_size,min_payload);
        if (actual_payload_size != min_payload) begin
          // len_mismatch = 1;
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
    return (next_crc == 32'hC704DD7B);
  endfunction

endclass

