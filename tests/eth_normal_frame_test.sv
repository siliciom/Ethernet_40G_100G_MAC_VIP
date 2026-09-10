//******************************************************************//
//              ETHERNET NORMAL FRAME TEST
//
// Defines the Ethernet normal frame test. This test verifies
// successful transmission and reception of valid Ethernet
// frames under normal operating conditions.
//
//******************************************************************//
class eth_normal_frame_test extends eth_base_test;

  `uvm_component_utils(eth_normal_frame_test)

  eth_normal_frame_seq seq0;
  eth_normal_frame_seq seq1;

  uvm_status_e status;
  uvm_reg_data_t tx_vlan_enable;
  uvm_reg_data_t rx_vlan_enable;

  function new(string name = "eth_normal_frame_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    env_h.ipg_chkr_h.ipg_checker_en = 1;

    phase.raise_objection(this);
    
    wait (env_h.agnt_mac[0].drv_h.v_intf.rst == 1'b1 && env_h.agnt_mac[1].drv_h.v_intf.rst);
    foreach (env_h.ral_model[i]) begin
      env_h.ral_model[i].tx_single_vlan_enable.write(status, 32'h0, UVM_FRONTDOOR);
      env_h.ral_model[i].rx_single_vlan_enable.write(status, 32'h0, UVM_FRONTDOOR);
    end

    // Create separate sequence objects for each MAC agent
    seq0 = eth_normal_frame_seq::type_id::create("seq0");
    seq1 = eth_normal_frame_seq::type_id::create("seq1");

    

    // Number of packets
    seq0.no_of_pkts = `NO_OF_PKTS;
    seq1.no_of_pkts = `NO_OF_PKTS;

    // Run traffic concurrently on both MAC agents
    fork
      seq0.start(env_h.agnt_mac[0].seqr_h);
      seq1.start(env_h.agnt_mac[1].seqr_h);
    join
    wait_until_complete();
    #200;
    phase.drop_objection(this);
  endtask

endclass

