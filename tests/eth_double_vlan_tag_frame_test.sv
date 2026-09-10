//******************************************************************//
//          ETHERNET DOUBLE VLAN TAG TEST
//
// Defines the Ethernet double VLAN tag test. This test
// verifies transmission and reception of double VLAN
// (Q-in-Q) Ethernet frames.
//
//******************************************************************//
class eth_double_vlan_tag_frame_test extends eth_base_test;
  `uvm_component_utils(eth_double_vlan_tag_frame_test)

  eth_double_vlan_tag_seq seq0;
  eth_double_vlan_tag_seq seq1;

  function new(string name = "eth_double_vlan_tag_frame_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    uvm_status_e status;
    phase.raise_objection(this);

    // Enable double VLAN through RAL
    foreach (env_h.ral_model[i]) begin
      env_h.ral_model[i].tx_double_vlan_enable.write(status, 32'h1, UVM_FRONTDOOR);
      env_h.ral_model[i].rx_double_vlan_enable.write(status, 32'h1, UVM_FRONTDOOR);
    end

    // ---------------------------------------------------------
    // MAC 0
    // ---------------------------------------------------------

    seq0 = eth_double_vlan_tag_seq::type_id::create("seq0");
    seq0.cfg_h = cfg_h[0];
    seq0.no_of_pkts = `NO_OF_PKTS;

    // ---------------------------------------------------------
    // MAC 1
    // ---------------------------------------------------------

    seq1 = eth_double_vlan_tag_seq::type_id::create("seq1");
    seq1.cfg_h = cfg_h[1];
    seq1.no_of_pkts = `NO_OF_PKTS;

    fork
      seq0.start(env_h.agnt_mac[0].seqr_h);
      seq1.start(env_h.agnt_mac[1].seqr_h);
    join

    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask
endclass
