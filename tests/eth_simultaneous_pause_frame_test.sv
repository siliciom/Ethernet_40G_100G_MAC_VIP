//******************************************************************//
//            ETHERNET SIMULTANEOUS PAUSE FRAME TEST
//
// Defines the Ethernet simultaneous PAUSE frame test. This test
// generates PAUSE control frames simultaneously (e.g. from both
// link partners / on both directions ) along with
// normal traffic, and verifies that normal traffic is correctly
// paused and resumed even under simultaneous PAUSE conditions.
//
//******************************************************************//
class eth_simultaneous_pause_frame_test extends eth_base_test;
  `uvm_component_utils(eth_simultaneous_pause_frame_test )
  function new (string name = "eth_simultaneous_pause_frame_test ", uvm_component parent = null);
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
    vseq.payload_rand_en = 0;
    vseq.ether_type = 46;
    vseq.pause_normal_traffic = 1;
    vseq.pause_simul_en = 1;
    vseq.start(env_h.vseqr_h);
    #200;
    phase.drop_objection(this);
  endtask    
endclass

