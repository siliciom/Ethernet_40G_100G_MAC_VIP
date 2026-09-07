//******************************************************************//
//         ETHERNET PFC RANDOM PRIORITY QUANTA EXPIRY TEST
//
// mac_0: eth_pfc_rand_priority_seq with basic_pfc_en=1 — actively
//        fires PFC XOFF on a randomized priority per packet.
// mac_1: eth_pfc_rand_priority_seq with basic_pfc_en=0 — never
//        fires its own PFC, but reacts by biasing its PCP to match
//        mac_0's most recently paused priority for a few packets
//        (via the static shared_pfc_prio/shared_pfc_credits fields
//        on eth_pfc_rand_priority_seq), so the correlation between
//        "mac_0 pauses prio X" and "mac_1 sends on prio X, gets
//        held" is clearly observable. No virtual_seq involved.
//******************************************************************//
`ifndef ETH_PFC_WITH_RANDOM_PRIORITY_QUANTA_EXPIRY_TEST_SV
`define ETH_PFC_WITH_RANDOM_PRIORITY_QUANTA_EXPIRY_TEST_SV 
class eth_pfc_with_random_priority_quanta_expiry_test extends eth_base_test;
  `uvm_component_utils(eth_pfc_with_random_priority_quanta_expiry_test)
  function new(string name = "eth_pfc_with_random_priority_quanta_expiry_test",
               uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction
  task run_phase(uvm_phase phase);
    eth_pfc_rand_priority_seq mac_0;
    eth_pfc_rand_priority_seq mac_1;
    uvm_status_e status;
    env_h.ipg_chkr_h.ipg_checker_en = 1;

    phase.raise_objection(this);
    wait (env_h.agnt_mac[0].drv_h.v_intf.rst == 1'b1 && env_h.agnt_mac[1].drv_h.v_intf.rst);
    // ---------------------------------------------------------
    // Enable Single VLAN through RAL
    // ---------------------------------------------------------
    env_h.ral_model[0].tx_single_vlan_enable.write(status, 32'h1, UVM_FRONTDOOR);
    env_h.ral_model[0].rx_single_vlan_enable.write(status, 32'h1, UVM_FRONTDOOR);
    env_h.ral_model[0].rx_pfc_control.write(status, 32'h0001_0000, UVM_FRONTDOOR);
    env_h.ral_model[1].rx_pfc_control.write(status, 32'h0001_0000, UVM_FRONTDOOR);
    env_h.ral_model[1].tx_single_vlan_enable.write(status, 32'h1, UVM_FRONTDOOR);
    env_h.ral_model[1].rx_single_vlan_enable.write(status, 32'h1, UVM_FRONTDOOR);

    if (quanta_ctrl == 0) begin
      env_h.ral_model[0].tx_pause_quanta_0.write(status, 1, UVM_FRONTDOOR);
      env_h.ral_model[0].tx_pause_quanta_1.write(status, 2, UVM_FRONTDOOR);
      env_h.ral_model[0].tx_pause_quanta_2.write(status, 3, UVM_FRONTDOOR);
      env_h.ral_model[0].tx_pause_quanta_3.write(status, 4, UVM_FRONTDOOR);
      env_h.ral_model[0].tx_pause_quanta_4.write(status, 5, UVM_FRONTDOOR);
      env_h.ral_model[0].tx_pause_quanta_5.write(status, 6, UVM_FRONTDOOR);
      env_h.ral_model[0].tx_pause_quanta_6.write(status, 7, UVM_FRONTDOOR);
      env_h.ral_model[0].tx_pause_quanta_7.write(status, 8, UVM_FRONTDOOR);
    end

    // Reset shared state at the start of this test in case the same
    // class was used earlier in the same simulation.
    eth_pfc_rand_priority_seq::shared_pfc_credits = 0;

    mac_0 = eth_pfc_rand_priority_seq::type_id::create("mac_0");
    mac_0.cfg_h = cfg_h[0];
    mac_0.no_of_pkts = `NO_OF_PKTS;
    mac_0.quanta_ctrl = this.quanta_ctrl;
    mac_0.basic_pfc_en = 1;  // mac_0 actively fires PFC frames
    mac_0.wt_dist0 = 20;
    mac_0.wt_dist1 = 80;

    mac_1 = eth_pfc_rand_priority_seq::type_id::create("mac_1");
    mac_1.cfg_h = cfg_h[1];
    mac_1.no_of_pkts = `NO_OF_PKTS;
    mac_1.basic_pfc_en = 0;  // mac_1 never fires its own PFC;
                             // it only reacts via the shared PCP bias

    fork
      mac_0.start(env_h.agnt_mac[0].seqr_h);
      mac_1.start(env_h.agnt_mac[1].seqr_h);
    join
    #200;
    wait_until_complete();
    phase.drop_objection(this);
  endtask
endclass
`endif
