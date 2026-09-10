class eth_single_vlan_tag_frame_test extends eth_base_test;

  `uvm_component_utils(eth_single_vlan_tag_frame_test)

  eth_single_vlan_seq seq0;
  eth_single_vlan_seq seq1;

  function new(string name = "eth_single_vlan_tag_frame_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);

    uvm_status_e status;
    phase.raise_objection(this);
    wait (env_h.agnt_mac[0].drv_h.v_intf.rst == 1'b1 && env_h.agnt_mac[1].drv_h.v_intf.rst);

    // ---------------------------------------------------------
    // Enable Single VLAN through RAL
    // ---------------------------------------------------------
    foreach (env_h.ral_model[i]) begin
      env_h.ral_model[i].tx_single_vlan_enable.write(status, 32'h0, UVM_FRONTDOOR);
      env_h.ral_model[i].rx_single_vlan_enable.write(status, 32'h0, UVM_FRONTDOOR);
    end

    // ---------------------------------------------------------
    // MAC 0
    // ---------------------------------------------------------
    seq0 = eth_single_vlan_seq::type_id::create("seq0");
    seq0.cfg_h = cfg_h[0];
    seq0.no_of_pkts = `NO_OF_PKTS;

    // ---------------------------------------------------------
    // MAC 1
    // ---------------------------------------------------------
    seq1 = eth_single_vlan_seq::type_id::create("seq1");
    seq1.cfg_h = cfg_h[1];
    seq1.no_of_pkts = `NO_OF_PKTS;

    // ---------------------------------------------------------
    // Run both MAC agents concurrently
    // ---------------------------------------------------------
    fork
      seq0.start(env_h.agnt_mac[0].seqr_h);
      seq1.start(env_h.agnt_mac[1].seqr_h);
    join

    wait_until_complete();
    #200;
    phase.drop_objection(this);

  endtask

endclass

