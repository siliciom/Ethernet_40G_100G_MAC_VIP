//******************************************************************//
//              ETHERNET UNICAST FRAME TEST
//
// Defines the Ethernet unicast frame test. This test verifies
// successful transmission and reception of unicast Ethernet
// frames between the intended source and destination MACs.
//
//******************************************************************//
class eth_unicast_frame_test extends eth_base_test;
  `uvm_component_utils(eth_unicast_frame_test)

  eth_unicast_frame_seq seq0;
  eth_unicast_frame_seq seq1;

  function new(string name = "eth_unicast_frame_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    seq0 = eth_unicast_frame_seq::type_id::create("seq0");
    seq1 = eth_unicast_frame_seq::type_id::create("seq1");

    seq0.no_of_pkts = `NO_OF_PKTS;
    seq1.no_of_pkts = `NO_OF_PKTS;

    fork
      seq0.start(env_h.agnt_mac[0].seqr_h);
      seq1.start(env_h.agnt_mac[1].seqr_h);
    join

    wait_until_complete();
    #200;
    phase.drop_objection(this);
  endtask
endclass
