//******************************************************************//
//         ETHERNET PAUSE FRAME DURING VLAN TRAFFIC TEST
//
// Defines the Ethernet PAUSE frame during VLAN traffic test. This
// test enables single VLAN tagging on both TX and RX paths and
// generates PAUSE control frames along with VLAN-tagged
// normal traffic, verifying that VLAN traffic is correctly paused
// (XOFF) and resumed (XON) in response to the PAUSE frames.
//
//******************************************************************//

class eth_pause_frame_during_vlan_traffic_test extends eth_base_test;

  `uvm_component_utils(eth_pause_frame_during_vlan_traffic_test)

  eth_pause_frame_vlan_seq mac_0;
  eth_pause_frame_vlan_seq mac_1;

  function new(string name = "eth_pause_frame_during_vlan_traffic_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);

    uvm_status_e status;

    phase.raise_objection(this);

    //==============================================================
    // Wait for reset release
    //==============================================================

    wait (env_h.agnt_mac[0].drv_h.v_intf.rst == 1'b1 && env_h.agnt_mac[1].drv_h.v_intf.rst == 1'b1);
    pkt_rand_en = 1;
    if (pkt_rand_en == 0) begin
      env_h.ral_model[0].tx_pauseframe_quanta.write(status, $urandom_range(0, 10), UVM_FRONTDOOR);
      env_h.ral_model[1].tx_pauseframe_quanta.write(status, $urandom_range(0, 10), UVM_FRONTDOOR);
    end
    //==============================================================
    // MAC0 VLAN configuration
    //==============================================================

    cfg_h[0].ral_model.tx_single_vlan_enable.write(status, 32'h0000_0001, UVM_FRONTDOOR);

    cfg_h[0].ral_model.rx_single_vlan_enable.write(status, 32'h0000_0001, UVM_FRONTDOOR);
    //==============================================================
    // MAC1 VLAN configuration
    //==============================================================

    cfg_h[1].ral_model.tx_single_vlan_enable.write(status, 32'h0000_0001, UVM_FRONTDOOR);

    cfg_h[1].ral_model.rx_single_vlan_enable.write(status, 32'h0000_0001, UVM_FRONTDOOR);

    //==============================================================
    // Forwarding Pause to the Upper Layers
    //==============================================================
    cfg_h[0].ral_model.rx_frame_control.write(status, 32'h0000_0010, UVM_FRONTDOOR);

    cfg_h[1].ral_model.rx_frame_control.write(status, 32'h0000_0010, UVM_FRONTDOOR);
    //==============================================================
    // MAC0
    // VLAN + PAUSE XOFF/XON
    //==============================================================
    mac_0 = eth_pause_frame_vlan_seq::type_id::create("mac_0");
    mac_0.cfg_h = cfg_h[0];
    mac_0.no_of_pkts = `NO_OF_PKTS;
    mac_0.normal_xon_xoff_en = 1'b1;
    mac_0.pkt_rand_en = pkt_rand_en;
    mac_0.wt_dist0 = 70;
    mac_0.wt_dist1 = 30;
    //==============================================================
    // MAC1
    // VLAN only
    //==============================================================
    mac_1 = eth_pause_frame_vlan_seq::type_id::create("mac_1");
    mac_1.cfg_h = cfg_h[1];
    mac_1.no_of_pkts = `NO_OF_PKTS;
    mac_1.normal_xon_xoff_en = 1'b0;
    mac_1.pkt_rand_en = pkt_rand_en;
    mac_1.wt_dist0 = 70;
    mac_1.wt_dist1 = 30;
    //==============================================================
    // Run both MACs concurrently
    //==============================================================
    fork
      begin
        mac_0.start(env_h.agnt_mac[0].seqr_h);
      end

      begin
        mac_1.start(env_h.agnt_mac[1].seqr_h);
      end
    join
    //==============================================================
    // Drain
    //==============================================================
    #200;
    wait_until_complete();
    phase.drop_objection(this);
  endtask
endclass
