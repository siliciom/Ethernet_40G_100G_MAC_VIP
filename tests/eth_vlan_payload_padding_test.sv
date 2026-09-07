//******************************************************************//
//          ETHERNET VLAN PAYLOAD PADDING TEST
//
// Defines the Ethernet VLAN payload padding test. This test
// verifies correct payload padding for VLAN-tagged Ethernet
// frames.
//
//******************************************************************//
class eth_vlan_payload_padding_test extends eth_base_test;
  `uvm_component_utils(eth_vlan_payload_padding_test)
  function new(string name = "eth_vlan_payload_padding_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction
  task run_phase(uvm_phase phase);
    uvm_status_e status;
    eth_vlan_payload_padding_seq seq0;
    eth_vlan_payload_padding_seq seq1;

    phase.raise_objection(this);

    // ---------------------------------------------------------
    // Enable Single VLAN through RAL (required for VLAN frames)
    // ---------------------------------------------------------
    foreach (env_h.ral_model[i]) begin
      env_h.ral_model[i].tx_single_vlan_enable.write(status, 32'h1, UVM_FRONTDOOR);
      env_h.ral_model[i].rx_single_vlan_enable.write(status, 32'h1, UVM_FRONTDOOR);
      env_h.ral_model[i].tx_pad_control.write(status, 1, UVM_FRONTDOOR);
    end

    // Create separate sequence objects for each MAC agent
    seq0 = eth_vlan_payload_padding_seq::type_id::create("seq0");
    seq1 = eth_vlan_payload_padding_seq::type_id::create("seq1");

    // Number of packets
    seq0.no_of_pkts = `NO_OF_PKTS;
    seq1.no_of_pkts = `NO_OF_PKTS;

    seq0.cfg_h = cfg_h[0];
    seq1.cfg_h = cfg_h[1];
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
