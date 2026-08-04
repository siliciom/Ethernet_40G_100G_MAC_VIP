//******************************************************************//
//                       ETHERNET DRIVER FILE
//
// Implements the Ethernet UVM driver. The driver receives Ethernet
// sequence items from the sequencer and converts them into pin-level
// signal activity on the configured Ethernet interface.
// It is responsible for transmitting frames, idles,
// control characters, errors, and protocol-specific signaling.
// TODO:- Need to update the pause and pfc scenarios.
//
// Author: Ankitha, Sanjeev
//
//******************************************************************//
class eth_drv extends uvm_driver#(eth_seq_item);
  `uvm_component_utils(eth_drv);
  `uvm_register_cb(eth_drv, error_cb)  
 
  eth_seq_item tr;
  eth_cnfg cfg;
  virtual eth_interface v_intf;
   bit [`DATA_WIDTH-1:0] frame_q[$];
  bit [`CRC-1:0] next_crc32;
  localparam int NUM_LANES = `DATA_WIDTH / 8;
  int idx;
  logic [`DATA_WIDTH-1:0] tx_word;
  int tx_idx;
 int deficit_cnt = 0;
 //int ipg_bytes;
 //int pad;
 //int actual_idle;
 int pad_cnt;
 
 bit [`MAC_ADDR-1:0] mac_addr;
  
  typedef struct packed {
    logic [`DATA_WIDTH-1:0] txd;
    logic [`CTRL_WIDTH-1:0]  txc;
} xlgmii_word_t;
 
xlgmii_word_t xlgmii_q[$];
 

  function new(string name = "eth_drv", uvm_component parent = null);
    super.new(name,parent);
  endfunction   


  function void build_phase(uvm_phase phase);
    super.build_phase(phase); 
    if(!uvm_config_db#(virtual eth_interface)::get(this,"","vif",v_intf))
      `uvm_fatal(get_type_name(),"CONNECTION_FAILED")
    else
      `uvm_info(get_type_name(),"CONNECTION_PASSED",UVM_LOW)
    
    if(!uvm_config_db #(eth_cnfg)::get(this,"","cfg",cfg))
       `uvm_fatal(get_type_name(),"No cfg")
 
    
  endfunction    

  //**********************************************************//
  // This task do the handshake mechanism and get the data
  // from sequence.
  //**********************************************************// 
task run_phase(uvm_phase phase);
    drive_reset();
    reset_counters();
    wait(v_intf.rst);
    // repeat($urandom_range(3,5)) begin
        send_idle();
	repeat($urandom_range(3,5)) @(v_intf.drv_cb);
     //end
      	fork
	update_counters();
        join_none

    forever begin
        seq_item_port.get_next_item(tr);
        frame_pack(tr);
        rs_encode();
        drive_frame();
	eth_packet_tracker::print_packet("TX",this.get_full_name(),tr);
        seq_item_port.item_done();
    end
endtask

  //**********************************************************//
  // This tasks do the reset of all signals. 
  // it just drive zero all signals
  //**********************************************************// 
  task drive_reset();
    v_intf.drv_cb.TXD  <= 0;
    v_intf.drv_cb.TXC  <= 0;
  endtask

  //**********************************************************//
  // This task packs an eth_seq_item transaction into frame_q
  // as a byte stream (preamble, SFD, DA, SA, VLAN tags,
  // ether_type, payload, padding, CRC) ready to be driven.
  //**********************************************************//
 
   task frame_pack(ref eth_seq_item tr);
    idx = 0;
      frame_q.delete();
 `uvm_do_callbacks(eth_drv, error_cb, inject_error(tr));

    //Preamble packing
    foreach(tr.preamble[i])
      frame_q[idx++] = tr.preamble[i];
    //SFD Packing
    frame_q[idx++] = tr.sfd[7:0];
    //DA packing
    for(int i = 5; i >= 0; i--)
      frame_q[idx++] = tr.da[i*8 +: 8];
    //SA packing
    for(int i = 5; i >= 0; i--) //6 bytes of Source Address
      frame_q[idx++] = tr.sa[i*8 +: 8];

     //Outer (Service) VLAN tag — only if double-tagging enabled
    if(tr.outer_vlan_en == 1) begin
      frame_q[idx++] = tr.outer_TPID[15:8];
      frame_q[idx++] = tr.outer_TPID[7:0];
      frame_q[idx++] = {tr.outer_PCP, tr.outer_DEI, tr.outer_VID[11:8]};
      frame_q[idx++] = tr.outer_VID[7:0];
    end

     //If VLAN TAG is Enable, vlan fields packing
    if(tr.vlan_en == 1) begin
      frame_q[idx++] = tr.TPID[15:8];
      frame_q[idx++] = tr.TPID[7:0];      
      frame_q[idx++] = {tr.PCP, tr.DEI, tr.VID[11:8]};
      frame_q[idx++] = tr.VID[7:0];      
    end 

    //Type/Length packing
    frame_q[idx++] = tr.ether_type[15:8];    
    frame_q[idx++] = tr.ether_type[7:0];
    //Payload packing
      for(int i = (tr.payload.size()- 1);i >= 0 ;i--)
        frame_q[idx++] = tr.payload[i];
        //Zero Padding if payload is less than 46 bytes for normal frame and
	// bytes for vlan tagged frame
      
      if(tr.outer_vlan_en == 1 && tr.vlan_en == 1)
         pad_cnt = 38;
      else if(tr.vlan_en == 1)
        pad_cnt = 42;
      else
        pad_cnt = 46;

       if(tr.payload.size() < pad_cnt && tr.padding_en == 1) begin
        for(int i = tr.payload.size(); i < pad_cnt; i++)
          frame_q[idx++] = 0;
      end
      
    //CRC packing
    next_crc32 = 32'hFFFFFFFF;
    for(int i = 0;i < idx;i++) begin
      if(i > 7) //Avoiding the Preamble and SFD Bytes
        next_crc32 = tr.crc_32(next_crc32, frame_q[i]);
    end
    next_crc32 = ~next_crc32;
    tr.crc = next_crc32;
    //BAD FCS 
    if(tr.corrupt_fcs_en==1) begin
	    next_crc32[7:0] = ~next_crc32[7:0];
	    `uvm_info("BAD_FCS",$sformatf("Transmitting incorrect CRC=%h",next_crc32),UVM_LOW)
    end
  //  tr.CRC =next_crc32;
    for(int i = 3;i >= 0;i--)
      frame_q[idx++] = next_crc32[8*i +: 8]; 
    tx_idx=0;
    // Print full frame format always
    $display("*****************************ETH_DRIVER***********************************");
    `uvm_info("DRIVER PACKING", $sformatf("\n\t preamble = %p\n\t sfd = 0x%0h\n\t DA = %h\n\t SA = %h\n\t ether_type = 0x%0h\n\t payload = %h bytes\n\t crc = 0x%h\n\t Total frame size = %0d, Frame size from DA = %0d\n\t Payload size = %0d\n\n\t VLAN_EN = %b\n\t VLAN_TPID = %h\n\t PCP = %h, DEI = %h, VID = %h ,OUTER_TPID =%h,OUTER_PCP =%h,OUTER_DEI =%h,OUTER_VID =%h ,",tr.preamble, tr.sfd, tr.da, tr.sa,tr.ether_type, tr.payload.size(), next_crc32,idx,idx - 8,tr.payload.size(),tr.vlan_en, tr.TPID, tr.PCP,tr.DEI,tr.VID,tr.outer_TPID,tr.outer_PCP,tr.outer_DEI,tr.outer_VID), UVM_LOW)
    
    `uvm_info("DRIVING DATA", $sformatf("Frame size = %0d, CRC = %h",idx,next_crc32),UVM_LOW);
  endtask

   //**********************************************************//
  // This task drives XLGMII idle characters (0x07 on every
  // lane) with TXC all high, indicating no valid data on the
  // bus, then waits for one clock edge on the driver clocking
  // block.
  //**********************************************************// 
  task send_idle();
    v_intf.drv_cb.TXD <= {NUM_LANES{`IDLE_CH}};
    v_intf.drv_cb.TXC <= {NUM_LANES{1'b1}};
    @(v_intf.drv_cb);
 
  endtask

  //**********************************************************//
  // This task encodes the packed frame (frame_q) into XLGMII
  // words: adds START/TERMINATE control chars, pads/aligns
  // idle per Deficit Idle Count rules, packs into 8-byte words
  // (xlgmii_q).
  //**********************************************************// 
task rs_encode();

    byte rs_frame[$];
    bit  rs_ctrl[$];
    xlgmii_word_t word;
    int idx;
    int bytes_used_in_word;
    int fd_lane;
    int pad_within_word;
    int natural_idle;
    int surplus;
    int shortfall;

    rs_frame.delete();
    rs_ctrl.delete();
    xlgmii_q.delete();

    //--------------------------------------------------
    // 1. START character (FB)
    //--------------------------------------------------
    rs_frame.push_back(`START_CH );
    rs_ctrl.push_back(1'b1);

    //--------------------------------------------------
    // 2. Remaining Ethernet frame (skip preamble byte 0)
    //--------------------------------------------------
    for(int i=1;i<frame_q.size();i++) begin
        rs_frame.push_back(frame_q[i]);
        rs_ctrl.push_back(0);
    end

    //--------------------------------------------------
    // 3. TERMINATE
    //--------------------------------------------------
    if(!tr.missing_terminate) begin
    rs_frame.push_back(`TERMINATE_CH );
    rs_ctrl.push_back(1'b1);
    end
    else begin
    `uvm_info(get_type_name(), "Skipping Terminate character (0xFD)", UVM_LOW)
   end

    //--------------------------------------------------
    // 4. Find which lane FD landed on
    //--------------------------------------------------
    bytes_used_in_word = rs_frame.size() % NUM_LANES;      // 1..8 (never 0 exactly here since FD just pushed)
    if (bytes_used_in_word == 0)
        fd_lane = NUM_LANES-1;                                // FD exactly filled last lane
    else
        fd_lane = bytes_used_in_word - 1;

    pad_within_word = (NUM_LANES - rs_frame.size()%NUM_LANES) % NUM_LANES;  // bytes left in the FD's own word

    //--------------------------------------------------
    // 5. Fill rest of FD's word with idle
    //--------------------------------------------------
    repeat(pad_within_word) begin
        rs_frame.push_back(`IDLE_CH);
        rs_ctrl.push_back(1);
    end

    //--------------------------------------------------
    // 6. Mandatory one full idle word so next frame's
    //    FB starts at lane0 of a fresh word
    //--------------------------------------------------
    if(pad_within_word<5) begin
    repeat(NUM_LANES) begin
        rs_frame.push_back(`IDLE_CH);
        rs_ctrl.push_back(1);
    end

    natural_idle = pad_within_word+NUM_LANES;
  end
  else begin
      natural_idle = pad_within_word;

  end

    //--------------------------------------------------
    // 7. Deficit Idle Count bookkeeping
    //--------------------------------------------------
    if (natural_idle >= 12) begin
        surplus = natural_idle - 12;
        if (deficit_cnt > 0) begin
            if (surplus >= deficit_cnt) begin
                surplus     = surplus - deficit_cnt; // fully repay
                deficit_cnt = 0;
            end else begin
                deficit_cnt = deficit_cnt - surplus; // partial repay
                surplus     = 0;
            end
        end
        // remaining surplus (if any) is simply not banked further
    end
    else begin
        shortfall   = 12 - natural_idle;
        deficit_cnt = deficit_cnt + shortfall;
       if (deficit_cnt > 7) begin
            repeat(NUM_LANES) begin
                rs_frame.push_back(`IDLE_CH);
                rs_ctrl.push_back(1);
            end
            deficit_cnt  = deficit_cnt - 8;
            natural_idle = natural_idle + 8;   // reflect actual IPG sent
	    `uvm_info("DIC_OVERFLOW", $sformatf(" Inserted extra 8-byte idle word DEFICIT_CNT reduced to %0d", deficit_cnt), UVM_LOW)
        end
    end
    
   `uvm_info("FD_LANE_INFO",  $sformatf("FD_LANE=%0d NATURAL_IDLE=%0d DEFICIT_CNT=%0d",fd_lane, natural_idle,  deficit_cnt),UVM_LOW)

    //--------------------------------------------------
    // 8. Convert to XLGMII words
    //--------------------------------------------------
    idx = 0;
    while(idx < rs_frame.size()) begin
        word.txd = 0;
        word.txc = 0;
        for(int lane=0; lane<NUM_LANES; lane++) begin
            word.txd[lane*8 +:8] = rs_frame[idx];
            word.txc[lane]       = rs_ctrl[idx];
            idx++;
        end
        xlgmii_q.push_back(word);
    end

    // NEW - inject a single invalid control char at a chosen word/lane,
    // AFTER the frame is fully encoded, so only one lane is corrupted
    if (tr.invalid) begin
        xlgmii_q[0].txd[0*8 +: 8] = 8'h1E;
        xlgmii_q[0].txc[0]        = 1'b1;

        `uvm_info(get_type_name(), "Driving INVALID ctrl char=0x1E at word=0 lane=0", UVM_LOW)
    end




   
endtask

  //**********************************************************//
  // This task drives the encoded XLGMII words onto the
  // interface, optionally injecting an ERROR control char at
  // a chosen byte offset, and logs each driven word for
  // tracing.
  //**********************************************************//
task drive_frame();

    xlgmii_word_t word;
    int byte_cnt = 0;

    foreach(xlgmii_q[i]) begin
        word = xlgmii_q[i];
        for(int lane=0; lane<NUM_LANES; lane++) begin
            // Count only DATA bytes
            if(word.txc[lane] == 0) begin
                if(tr.err_b && (byte_cnt == tr.err_offset)) begin
                    // Replace data byte with ERROR control character
                    word.txd[lane*8 +:8] = 8'hFE;
                    word.txc[lane]       = 1'b1;

                    `uvm_info("ERROR_INJECT",$sformatf("Inserted FE at Word=%0d Lane=%0d Byte=%0d", i,lane,byte_cnt),UVM_LOW)
                end
                  // Inject START control character in payload
              if(tr.start_char && (byte_cnt == tr.start_offset)) begin
                   word.txd[lane*8 +:8] = `START_CH;
                   word.txc[lane]       = 1'b1;
		   `uvm_info("START_IN_PAYLOAD", $sformatf("Inserted START(0xFB) at Word=%0d Lane=%0d Byte=%0d",i, lane, byte_cnt),UVM_LOW)
              end

	      if(tr.end_char && (byte_cnt == tr.end_offset)) begin
                   word.txd[lane*8 +:8] = `TERMINATE_CH;
                   word.txc[lane]       = 1'b1;
		   `uvm_info("END_IN_PAYLOAD", $sformatf("Inserted END(0xFD) at Word=%0d Lane=%0d Byte=%0d",i, lane, byte_cnt),UVM_LOW)
              end

	      if(tr.data_txc_error && (byte_cnt == tr.data_txc_offset)) begin
		      word.txc[lane] = 1'b1;
		      `uvm_info("DATA_TXC_ERROR",$sformatf("Forced TXC=1 for DATA byte at Word=%0d Lane=%0d Byte=%0d Data=0x%02h",i, lane, byte_cnt, word.txd[lane*8 +:8]), UVM_LOW)
	      end
                byte_cnt++;
            end
        end
        v_intf.drv_cb.TXD <= word.txd;
        v_intf.drv_cb.TXC <= word.txc;
        tr.tx_trace_q.push_back('{t: $time, txd: word.txd, txc: word.txc});
        @(v_intf.drv_cb);
    end
endtask

  //**********************************************************//
  // This task runs forever and, on every clock edge, updates
  // all the TX and RX statistics counters for this mac_addr
  // from their pending values into the visible interface
  // counters.
  //**********************************************************//

 task update_counters();
    forever begin
       @(v_intf.drv_cb);
       statistics::v_uif[mac_addr].tx_good_pkt_count      = statistics::tx_good_pkt_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_bad_pkt_count       = statistics::tx_bad_pkt_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_unicast_count       = statistics::tx_unicast_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_multicast_count     = statistics::tx_multicast_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_broadcast_count     = statistics::tx_broadcast_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_fragment_count      = statistics::tx_fragment_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_runt_count          = statistics::tx_runt_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pause_count         = statistics::tx_pause_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_vlan_count          = statistics::tx_vlan_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_jumbo_count         = statistics::tx_jumbo_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_jabber_count        = statistics::tx_jabber_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_ipg_violation_count = statistics::tx_ipg_violation_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xon_count       = statistics::tx_pfc_xon_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_count      = statistics::tx_pfc_xoff_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_carrier_ext_count   = statistics::tx_carrier_ext_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pause_xon_count     = statistics::tx_pause_xon_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pause_xoff_count    = statistics::tx_pause_xoff_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_control_pkt_count   = statistics::tx_control_pkt_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xon_prio0_count = statistics::tx_pfc_xon_prio0_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xon_prio1_count = statistics::tx_pfc_xon_prio1_pending[mac_addr]; 
       statistics::v_uif[mac_addr].tx_pfc_xon_prio2_count = statistics::tx_pfc_xon_prio2_pending[mac_addr]; 
       statistics::v_uif[mac_addr].tx_pfc_xon_prio3_count = statistics::tx_pfc_xon_prio3_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xon_prio4_count = statistics::tx_pfc_xon_prio4_pending[mac_addr]; 
       statistics::v_uif[mac_addr].tx_pfc_xon_prio5_count = statistics::tx_pfc_xon_prio5_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xon_prio6_count = statistics::tx_pfc_xon_prio6_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xon_prio7_count = statistics::tx_pfc_xon_prio7_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_prio0_count= statistics::tx_pfc_xoff_prio0_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_prio1_count= statistics::tx_pfc_xoff_prio1_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_prio2_count= statistics::tx_pfc_xoff_prio2_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_prio3_count= statistics::tx_pfc_xoff_prio3_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_prio4_count= statistics::tx_pfc_xoff_prio4_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_prio5_count= statistics::tx_pfc_xoff_prio5_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_prio6_count= statistics::tx_pfc_xoff_prio6_pending[mac_addr];
       statistics::v_uif[mac_addr].tx_pfc_xoff_prio7_count= statistics::tx_pfc_xoff_prio7_pending[mac_addr];


       statistics::v_uif[mac_addr].rx_good_pkt_count      = statistics::rx_good_pkt_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_bad_pkt_count       = statistics::rx_bad_pkt_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_unicast_count       = statistics::rx_unicast_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_multicast_count     = statistics::rx_multicast_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_broadcast_count     = statistics::rx_broadcast_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_fragment_count      = statistics::rx_fragment_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_runt_count          = statistics::rx_runt_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pause_count         = statistics::rx_pause_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_vlan_count          = statistics::rx_vlan_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_jumbo_count         = statistics::rx_jumbo_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_jabber_count        = statistics::rx_jabber_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_ipg_violation_count = statistics::rx_ipg_violation_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xon_count       = statistics::rx_pfc_xon_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_count      = statistics::rx_pfc_xoff_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_carrier_ext_count   = statistics::rx_carrier_ext_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pause_xon_count     = statistics::rx_pause_xon_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pause_xoff_count    = statistics::rx_pause_xoff_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_control_pkt_count   = statistics::rx_control_pkt_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xon_prio0_count = statistics::rx_pfc_xon_prio0_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xon_prio1_count = statistics::rx_pfc_xon_prio1_pending[mac_addr]; 
       statistics::v_uif[mac_addr].rx_pfc_xon_prio2_count = statistics::rx_pfc_xon_prio2_pending[mac_addr]; 
       statistics::v_uif[mac_addr].rx_pfc_xon_prio3_count = statistics::rx_pfc_xon_prio3_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xon_prio4_count = statistics::rx_pfc_xon_prio4_pending[mac_addr]; 
       statistics::v_uif[mac_addr].rx_pfc_xon_prio5_count = statistics::rx_pfc_xon_prio5_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xon_prio6_count = statistics::rx_pfc_xon_prio6_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xon_prio7_count = statistics::rx_pfc_xon_prio7_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_prio0_count= statistics::rx_pfc_xoff_prio0_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_prio1_count= statistics::rx_pfc_xoff_prio1_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_prio2_count= statistics::rx_pfc_xoff_prio2_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_prio3_count= statistics::rx_pfc_xoff_prio3_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_prio4_count= statistics::rx_pfc_xoff_prio4_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_prio5_count= statistics::rx_pfc_xoff_prio5_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_prio6_count= statistics::rx_pfc_xoff_prio6_pending[mac_addr];
       statistics::v_uif[mac_addr].rx_pfc_xoff_prio7_count= statistics::rx_pfc_xoff_prio7_pending[mac_addr];
    end
  endtask

   //**********************************************************//
  // This function resets all TX and RX statistics counters
  // for this mac_addr back to zero.
  //**********************************************************//
  function void reset_counters();
    statistics::v_uif[mac_addr].tx_good_pkt_count      = 0;
    statistics::v_uif[mac_addr].tx_bad_pkt_count       = 0;
    statistics::v_uif[mac_addr].tx_unicast_count       = 0;
    statistics::v_uif[mac_addr].tx_multicast_count     = 0;
    statistics::v_uif[mac_addr].tx_broadcast_count     = 0;
    statistics::v_uif[mac_addr].tx_fragment_count      = 0;
    statistics::v_uif[mac_addr].tx_runt_count          = 0;
    statistics::v_uif[mac_addr].tx_pause_count         = 0;
    statistics::v_uif[mac_addr].tx_vlan_count          = 0;
    statistics::v_uif[mac_addr].tx_jumbo_count         = 0;
    statistics::v_uif[mac_addr].tx_jabber_count        = 0;
    statistics::v_uif[mac_addr].tx_ipg_violation_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_count       = 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_count      = 0;
    statistics::v_uif[mac_addr].tx_carrier_ext_count   = 0;
    statistics::v_uif[mac_addr].tx_pause_xon_count     = 0;
    statistics::v_uif[mac_addr].tx_pause_xoff_count    = 0;
    statistics::v_uif[mac_addr].tx_control_pkt_count   = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio0_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio1_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio2_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio3_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio4_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio5_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio6_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio7_count = 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio0_count= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio1_count= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio2_count= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio3_count= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio4_count= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio5_count= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio6_count= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio7_count= 0;

    statistics::v_uif[mac_addr].rx_good_pkt_count      = 0;
    statistics::v_uif[mac_addr].rx_bad_pkt_count       = 0;
    statistics::v_uif[mac_addr].rx_unicast_count       = 0;
    statistics::v_uif[mac_addr].rx_multicast_count     = 0;
    statistics::v_uif[mac_addr].rx_broadcast_count     = 0;
    statistics::v_uif[mac_addr].rx_fragment_count      = 0;
    statistics::v_uif[mac_addr].rx_runt_count          = 0;
    statistics::v_uif[mac_addr].rx_pause_count         = 0;
    statistics::v_uif[mac_addr].rx_vlan_count          = 0;
    statistics::v_uif[mac_addr].rx_jumbo_count         = 0;
    statistics::v_uif[mac_addr].rx_jabber_count        = 0;
    statistics::v_uif[mac_addr].rx_ipg_violation_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_count       = 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_count      = 0;
    statistics::v_uif[mac_addr].rx_carrier_ext_count   = 0;
    statistics::v_uif[mac_addr].rx_pause_xon_count     = 0;
    statistics::v_uif[mac_addr].rx_pause_xoff_count    = 0;
    statistics::v_uif[mac_addr].rx_control_pkt_count   = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio0_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio1_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio2_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio3_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio4_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio5_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio6_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio7_count = 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio0_count= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio1_count= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio2_count= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio3_count= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio4_count= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio5_count= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio6_count= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio7_count= 0;

  endfunction 


  //**********************************************************//
  // This function returns the index of this mac_addr within
  // the eth_seq_item's mac_addr list.
  //**********************************************************//
  function int mac_no(bit [47:0] mac_t);
    eth_seq_item tr;
    tr = eth_seq_item::type_id::create("tr", this);
    foreach(tr.mac_addr[i]) begin
      if(tr.mac_addr[i] == mac_addr)
	      return i;
    end
  endfunction

  //**********************************************************//
  // This function builds and prints a formatted TX/RX counter
  // summary report for this mac_addr at the end of the test.
  //**********************************************************//
  
function void report_phase(uvm_phase phase);
    string tx_rx_report;

    tx_rx_report = $sformatf(
      "\n================ COUNTER SUMMARY =================\nMAC_ADDR=%h\n",
      mac_addr);

    tx_rx_report = {tx_rx_report, $sformatf(
      "\n---------------- MAC %0d : TX COUNTERS ----------------\n", mac_no(mac_addr))};

    tx_rx_report = {tx_rx_report, $sformatf("TX Good Packets          = %0d\n", statistics::v_uif[mac_addr].tx_good_pkt_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Bad Packets           = %0d\n", statistics::v_uif[mac_addr].tx_bad_pkt_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Unicast               = %0d\n", statistics::v_uif[mac_addr].tx_unicast_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Multicast             = %0d\n", statistics::v_uif[mac_addr].tx_multicast_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Broadcast             = %0d\n", statistics::v_uif[mac_addr].tx_broadcast_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Runt                  = %0d\n", statistics::v_uif[mac_addr].tx_runt_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Fragment              = %0d\n", statistics::v_uif[mac_addr].tx_fragment_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Jumbo                 = %0d\n", statistics::v_uif[mac_addr].tx_jumbo_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Jabber                = %0d\n", statistics::v_uif[mac_addr].tx_jabber_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Pause                 = %0d\n", statistics::v_uif[mac_addr].tx_pause_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX VLAN                  = %0d\n", statistics::v_uif[mac_addr].tx_vlan_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX IPG Violation         = %0d\n", statistics::v_uif[mac_addr].tx_ipg_violation_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC XON               = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC XOFF              = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX_carrier_ext_cnt       = %0d\n", statistics::v_uif[mac_addr].tx_carrier_ext_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX Pause XON             = %0d\n", statistics::v_uif[mac_addr].tx_pause_xon_count)};
    tx_rx_report = {tx_rx_report, $sformatf("Tx Pause XOFF            = %0d\n", statistics::v_uif[mac_addr].tx_pause_xoff_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX control pkt           = %0d\n", statistics::v_uif[mac_addr].tx_control_pkt_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XON_PRIO[0]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio0_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XON_PRIO[1]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio1_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XON_PRIO[2]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio2_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XON_PRIO[3]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio3_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XON_PRIO[4]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio4_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XON_PRIO[5]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio5_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XON_PRIO[6]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio6_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XON_PRIO[7]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio7_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XOFF_PRIO[0]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio0_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XOFF_PRIO[1]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio1_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XOFF_PRIO[2]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio2_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XOFF_PRIO[3]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio3_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XOFF_PRIO[4]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio4_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XOFF_PRIO[5]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio5_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XOFF_PRIO[6]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio6_count)};
    tx_rx_report = {tx_rx_report, $sformatf("TX PFC_XOFF_PRIO[7]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio7_count)};


    tx_rx_report = {tx_rx_report, $sformatf(
      "---------------- MAC %0d : RX COUNTERS ----------------\n", mac_no(mac_addr))};

    tx_rx_report = {tx_rx_report, $sformatf("RX Good Packets          = %0d\n", statistics::v_uif[mac_addr].rx_good_pkt_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Bad Packets           = %0d\n", statistics::v_uif[mac_addr].rx_bad_pkt_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Unicast               = %0d\n", statistics::v_uif[mac_addr].rx_unicast_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Multicast             = %0d\n", statistics::v_uif[mac_addr].rx_multicast_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Broadcast             = %0d\n", statistics::v_uif[mac_addr].rx_broadcast_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Runt                  = %0d\n", statistics::v_uif[mac_addr].rx_runt_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Fragment              = %0d\n", statistics::v_uif[mac_addr].rx_fragment_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Jumbo                 = %0d\n", statistics::v_uif[mac_addr].rx_jumbo_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Jabber                = %0d\n", statistics::v_uif[mac_addr].rx_jabber_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Pause                 = %0d\n", statistics::v_uif[mac_addr].rx_pause_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX VLAN                  = %0d\n", statistics::v_uif[mac_addr].rx_vlan_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC XON               = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC XOFF              = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX IPG Violation         = %0d\n", statistics::v_uif[mac_addr].rx_ipg_violation_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX_carrier_ext_cnt       = %0d\n", statistics::v_uif[mac_addr].rx_carrier_ext_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX Pause XON             = %0d\n", statistics::v_uif[mac_addr].rx_pause_xon_count)};
    tx_rx_report = {tx_rx_report, $sformatf("Rx Pause XOFF            = %0d\n", statistics::v_uif[mac_addr].rx_pause_xoff_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX control pkt           = %0d\n", statistics::v_uif[mac_addr].rx_control_pkt_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XON_PRIO[0]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio0_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XON_PRIO[1]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio1_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XON_PRIO[2]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio2_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XON_PRIO[3]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio3_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XON_PRIO[4]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio4_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XON_PRIO[5]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio5_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XON_PRIO[6]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio6_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XON_PRIO[7]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio7_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XOFF_PRIO[0]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio0_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XOFF_PRIO[1]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio1_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XOFF_PRIO[2]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio2_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XOFF_PRIO[3]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio3_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XOFF_PRIO[4]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio4_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XOFF_PRIO[5]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio5_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XOFF_PRIO[6]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio6_count)};
    tx_rx_report = {tx_rx_report, $sformatf("RX PFC_XOFF_PRIO[7]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio7_count)};
    tx_rx_report = {tx_rx_report, "\n================================================"};

    `uvm_info("COUNTER_REPORT", tx_rx_report, UVM_NONE)

  endfunction


 
endclass


