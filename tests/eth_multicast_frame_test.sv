//******************************************************************//
//             ETHERNET MULTICAST FRAME TEST
//
// Defines the Ethernet multicast frame test. This test verifies
// transmission and reception of multicast Ethernet frames to
// all receivers belonging to the configured multicast group.
//
//******************************************************************//
class eth_multicast_frame_test extends eth_base_test;
  `uvm_component_utils(eth_multicast_frame_test)

  eth_multicast_frame_seq seq0;

  function new(string name = "eth_multicast_frame_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    seq0 = eth_multicast_frame_seq::type_id::create("seq0");

    seq0.no_of_pkts = `NO_OF_PKTS;

    fork
      seq0.start(env_h.agnt_mac[0].seqr_h);
    join

    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask
endclass
