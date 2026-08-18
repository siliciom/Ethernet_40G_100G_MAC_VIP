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
  function new (string name = "eth_multicast_frame_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;   
    phase.raise_objection(this);  
      vseq = virtual_seq::type_id::create("vseq");
      vseq.no_of_pkts = `NO_OF_PKTS;
      vseq.frame_mode = base_virtual_seq::MULTICAST;
      vseq.start(env_h.vseqr_h);    
      wait_until_complete();
    phase.drop_objection(this);
  endtask    
endclass

