//******************************************************************//
//         ETHERNET PAUSE FRAME DURING VLAN TRAFFIC SEQUENCE
//
// Generates PAUSE control frames along with VLAN-tagged normal
// traffic to verify pause functionality with VLAN frames.
//******************************************************************//
class eth_pause_frame_vlan_seq extends base_seq;
  `uvm_object_utils(eth_pause_frame_vlan_seq)
  `uvm_declare_p_sequencer(eth_seqr)
  eth_cnfg cfg_h;
  uvm_status_e status;
  uvm_reg_data_t tx_vlan_enable;
  bit normal_xon_xoff_en;
  int num_pkts;
  bit [15:0] pause_time;
  int pause_gap_cnt;
  bit send_immediate_xon;
  bit pkt_rand_en;
  bit pause_pkt_sel;
  int wt_dist0;
  int wt_dist1;

  function new(string name = "eth_pause_frame_vlan_seq");
    super.new(name);
  endfunction

  task body();
    if (cfg_h == null)
      `uvm_fatal( "CFG_NULL", "eth_cnfg handle is null in eth_pause_frame_vlan_seq")
    num_pkts          = 0;
    pause_gap_cnt     = 0;
    send_immediate_xon = 0;
      // TX starts in VLAN mode
    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      randomise_item();
      void'(std::randomize(pause_pkt_sel)  with {pause_pkt_sel dist {0:=wt_dist0,1:=wt_dist1};});
      if (pause_gap_cnt > 0)
        pause_gap_cnt--;
      //============================================================
      // Immediate XON
      //============================================================
      if (send_immediate_xon) begin
        req.pause_frame_en = 1'b1;
        req.pause_sel      = 1'b1;
        req.pause_time = 16'h0000;
        req.pause_opc  = 16'h0001;
        req.ether_type = 16'h8808;
        req.da = 48'h0180_C200_0001;
        // PAUSE frame is untagged on TX
        // RX remains VLAN enabled
        req.vlan_en = 1'b0;
        req.TPID = 16'h0000;
        req.PCP  = 0;
        req.DEI  = 0;
        req.VID  = 0;
        send_immediate_xon = 1'b0;
        // TX VLAN OFF
        // RX VLAN ON
      end
      //============================================================
      // New PAUSE frame
      //============================================================
      else if ( normal_xon_xoff_en && pause_gap_cnt == 0 && pause_pkt_sel == 1 && (num_pkts < (no_of_pkts - 30))) begin
        req.pause_frame_en = 1'b1;
        req.pause_sel      = 1'b1;
        req.pause_opc  = 16'h0001;
        req.ether_type = 16'h8808;
        req.da = 48'h0180_C200_0001;
        // ---------------------------------------------------------
        // Generate XOFF
        // ---------------------------------------------------------
        //if ($urandom_range(1,100) <= 3) begin
        //  req.pause_time = 16'h0000;
        //end
        //else begin
          req.pause_time = $urandom_range(1,10);
          if (req.pause_time % 2 == 0)
            send_immediate_xon = 1'b1;
        //end
        // ---------------------------------------------------------
        // PAUSE is untagged
        // ---------------------------------------------------------
        req.vlan_en = 1'b0;
        req.TPID = 16'h0000;
        req.PCP  = 0;
        req.DEI  = 0;
        req.VID  = 0;
        // ---------------------------------------------------------
        // RAL
        // ---------------------------------------------------------
        pause_gap_cnt = $urandom_range(5,6);
      end
      //============================================================
      // Normal VLAN packet
      //============================================================
      else begin
        req.pause_frame_en = 1'b0;
        req.pause_sel      = 1'b0;
        req.vlan_en = 1'b1;
        req.TPID = 16'h8100;
        req.PCP  = $urandom_range(0,7);
        req.DEI  = 1'b0;
        req.VID  = $urandom_range(1,4094);
        req.padding_en = 1'b1;
        // TX VLAN ON
        send_immediate_xon = 0;
      end
      req.tx_single_vlan_enable = req.vlan_en;
      cfg_h.ral_model.tx_pauseframe_enable.write(status, req.pause_frame_en, UVM_FRONTDOOR);
      cfg_h.ral_model.tx_single_vlan_enable.write( status, req.vlan_en, UVM_FRONTDOOR);
      if(pkt_rand_en) begin
        cfg_h.ral_model.tx_pauseframe_quanta.write(status, pause_time, UVM_FRONTDOOR);
      end 
      num_pkts++;
      finish_item(req);
    end
  endtask
endclass
