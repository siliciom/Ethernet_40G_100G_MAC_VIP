//******************************************************************//
//        ETHERNET PAUSE FRAME WITH UPDATED PAUSE TIME TEST
//
// Defines the Ethernet PAUSE frame with updated pause time test.
// This test generates PAUSE control frames along with normal
// traffic, using an updated (re-issued) pause time value, and
// verifies that normal traffic is correctly paused for the newly
// updated duration.
//
//******************************************************************//

class eth_pause_frame_with_updated_pause_time extends eth_base_test;

  `uvm_component_utils(eth_pause_frame_with_updated_pause_time)

  eth_pause_frame_updated_time_seq mac_0;
  eth_pause_frame_updated_time_seq mac_1;
  uvm_status_e status;


  function new(string name = "eth_pause_frame_with_updated_pause_time",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction


  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    pkt_rand_en = 1;

    if (pkt_rand_en == 0) begin
      env_h.ral_model[0].tx_pauseframe_quanta.write(status, $urandom_range(0, 10), UVM_FRONTDOOR);
      env_h.ral_model[1].tx_pauseframe_quanta.write(status, $urandom_range(0, 10), UVM_FRONTDOOR);
    end
    //==============================================================
    // MAC0
    //==============================================================

    mac_0 = eth_pause_frame_updated_time_seq::type_id::create("mac_0");
    mac_0.no_of_pkts = `NO_OF_PKTS;
    mac_0.pause_update_time_en = 1'b1;
    mac_0.cfg_h = cfg_h[0];
    mac_0.pkt_rand_en = pkt_rand_en;
    mac_0.wt_dist0 = 70;
    mac_0.wt_dist1 = 30;

    //==============================================================
    // MAC1
    //==============================================================

    mac_1 = eth_pause_frame_updated_time_seq::type_id::create("mac_1");
    mac_1.no_of_pkts = `NO_OF_PKTS;
    mac_1.pause_update_time_en = 1'b0;
    mac_1.cfg_h = cfg_h[1];
    mac_1.pkt_rand_en = pkt_rand_en;
    mac_1.wt_dist0 = 70;
    mac_1.wt_dist1 = 30;

    //==============================================================
    // Run concurrently
    //==============================================================

    fork
      mac_0.start(env_h.agnt_mac[0].seqr_h);
      mac_1.start(env_h.agnt_mac[1].seqr_h);
    join
    #200;
    wait_until_complete();
    phase.drop_objection(this);
  endtask
endclass
