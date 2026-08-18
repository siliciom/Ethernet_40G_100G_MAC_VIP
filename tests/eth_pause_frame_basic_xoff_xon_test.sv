//******************************************************************//
//           ETHERNET PAUSE FRAME BASIC XOFF/XON TEST
//
// Defines the Ethernet PAUSE frame basic XOFF/XON test. This test
// generates  PAUSE control frames along with normal traffic
// and verifies that normal traffic is correctly paused (XOFF) and
// resumed (XON) in response to the PAUSE frames.
//
//******************************************************************//
class eth_pause_frame_basic_xoff_xon_test extends eth_base_test;
  `uvm_component_utils(eth_pause_frame_basic_xoff_xon_test)
  function new (string name = "eth_pause_frame_basic_xoff_xon_test", uvm_component parent = null);
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
    vseq.ether_type = 46;
    vseq.payload_rand_en = 0;
    vseq.pause_normal_traffic = 1;
    vseq.normal_xon_xoff_en = 1;
    vseq.start(env_h.vseqr_h);
      wait_until_complete();
    phase.drop_objection(this);
  endtask    
endclass

