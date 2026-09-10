//******************************************************************//
//                  ETHERNET PFC SIMULTANEOUS OPERATION TEST
//
// Starts the standalone PFC sequence on mac_seqr_h[0] and runs
// the same PFC sequence on mac_seqr_h[1].
// Follows the working eth_pfc_frame_test setup:
//   - wait for reset release
//   - enable Single VLAN through RAL
//   - assign cfg_h to every PFC sequence
//   - run both agents concurrently
//******************************************************************//

`ifndef ETH_PFC_SIMULTANEOUS_OPERATION_TEST_SV
`define ETH_PFC_SIMULTANEOUS_OPERATION_TEST_SV 

class eth_pfc_simultaneous_operation_test extends eth_base_test;

  `uvm_component_utils(eth_pfc_simultaneous_operation_test)


  function new(string name = "eth_pfc_simultaneous_operation_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);

    super.build_phase(phase);

  endfunction


  task run_phase(uvm_phase phase);

    eth_pfc_simultaneous_seq mac_0;
    eth_pfc_simultaneous_seq mac_1;
    // eth_single_vlan_seq mac_1; 

    uvm_status_e status;
    env_h.ipg_chkr_h.ipg_checker_en = 1;
    phase.raise_objection(this);
    //=============================================================
    // Wait for reset release
    //=============================================================
    wait (env_h.agnt_mac[0].drv_h.v_intf.rst == 1'b1 && env_h.agnt_mac[1].drv_h.v_intf.rst == 1'b1);

    // ---------------------------------------------------------
    // Enable Single VLAN through RAL
    // ---------------------------------------------------------
    env_h.ral_model[0].tx_single_vlan_enable.write(status, 32'h1, UVM_FRONTDOOR);
    env_h.ral_model[0].rx_single_vlan_enable.write(status, 32'h1, UVM_FRONTDOOR);
    env_h.ral_model[0].rx_pfc_control.write(status, 32'h0001_0000, UVM_FRONTDOOR);
    env_h.ral_model[1].tx_single_vlan_enable.write(status, 32'h1, UVM_FRONTDOOR);
    env_h.ral_model[1].rx_single_vlan_enable.write(status, 32'h1, UVM_FRONTDOOR);
    env_h.ral_model[1].rx_pfc_control.write(status, 32'h0001_0000, UVM_FRONTDOOR);

    if (quanta_ctrl == 0) begin
      env_h.ral_model[0].tx_pause_quanta_0.write(status, 1, UVM_FRONTDOOR);
      env_h.ral_model[0].tx_pause_quanta_1.write(status, 2, UVM_FRONTDOOR);
      env_h.ral_model[0].tx_pause_quanta_2.write(status, 3, UVM_FRONTDOOR);
      env_h.ral_model[0].tx_pause_quanta_3.write(status, 4, UVM_FRONTDOOR);
      env_h.ral_model[0].tx_pause_quanta_4.write(status, 5, UVM_FRONTDOOR);
      env_h.ral_model[0].tx_pause_quanta_5.write(status, 6, UVM_FRONTDOOR);
      env_h.ral_model[0].tx_pause_quanta_6.write(status, 7, UVM_FRONTDOOR);
      env_h.ral_model[0].tx_pause_quanta_7.write(status, 8, UVM_FRONTDOOR);
      env_h.ral_model[1].tx_pause_quanta_0.write(status, 1, UVM_FRONTDOOR);
      env_h.ral_model[1].tx_pause_quanta_1.write(status, 2, UVM_FRONTDOOR);
      env_h.ral_model[1].tx_pause_quanta_2.write(status, 3, UVM_FRONTDOOR);
      env_h.ral_model[1].tx_pause_quanta_3.write(status, 4, UVM_FRONTDOOR);
      env_h.ral_model[1].tx_pause_quanta_4.write(status, 5, UVM_FRONTDOOR);
      env_h.ral_model[1].tx_pause_quanta_5.write(status, 6, UVM_FRONTDOOR);
      env_h.ral_model[1].tx_pause_quanta_6.write(status, 7, UVM_FRONTDOOR);
      env_h.ral_model[1].tx_pause_quanta_7.write(status, 8, UVM_FRONTDOOR);
    end
    //=============================================================
    // MAC0 sequence
    //=============================================================

    mac_0              = eth_pfc_simultaneous_seq::type_id::create("mac_0");
    mac_0.cfg_h        = cfg_h[0];
    mac_0.no_of_pkts   = `NO_OF_PKTS;
    mac_0.quanta_ctrl  = this.quanta_ctrl;
    mac_0.pfc_simul_en = 1;
    mac_0.wt_dist0     = 20;
    mac_0.wt_dist1     = 80;

    //=============================================================
    // MAC1 sequence
    //=============================================================

    mac_1              = eth_pfc_simultaneous_seq::type_id::create("mac_1");
    mac_1.cfg_h        = cfg_h[1];
    mac_1.no_of_pkts   = `NO_OF_PKTS;
    mac_1.quanta_ctrl  = this.quanta_ctrl;
    mac_1.pfc_simul_en = 1;
    mac_1.wt_dist0     = 20;
    mac_1.wt_dist1     = 80;

    //=============================================================
    // Run both MACs concurrently
    //=============================================================

    fork
      begin
        mac_0.start(env_h.agnt_mac[0].seqr_h);
      end
      begin
        //	#0.0001;      
        mac_1.start(env_h.agnt_mac[1].seqr_h);
      end
    join

    //=============================================================
    // Allow monitor / scoreboard to drain
    //=============================================================
    #200;
    wait_until_complete();
    phase.drop_objection(this);

  endtask

endclass

`endif
