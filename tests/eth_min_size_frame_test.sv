//******************************************************************//
//           ETHERNET MINIMUM SIZE FRAME TEST
//
// Defines the Ethernet minimum frame size test. This test
// verifies transmission, padding, and reception of frames
// with the minimum valid Ethernet payload.
//
//******************************************************************//
class eth_min_size_frame_test extends eth_base_test;
  `uvm_component_utils(eth_min_size_frame_test)
  function new (string name = "eth_min_size_frame_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction  
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this); 
      vseq = virtual_seq::type_id::create("vseq");
      vseq.no_of_pkts = `NO_OF_PKTS;
      vseq.use_frame_mode_logic =0;
      vseq.ether_type = 46;
      vseq.payload_rand_en = 0;
      vseq.start(env_h.vseqr_h);    
      wait_until_complete();
    phase.drop_objection(this);
  endtask  
endclass

