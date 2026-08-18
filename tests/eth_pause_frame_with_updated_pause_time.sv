//******************************************************************//
//        ETHERNET PAUSE FRAME WITH UPDATED PAUSE TIME TEST
//
// Defines the Ethernet PAUSE frame with updated pause time test.
// This test generates  PAUSE control frames along with normal
// traffic, using an updated (re-issued) pause time value, and
// verifies that normal traffic is correctly paused for the newly
// updated duration.
//
//******************************************************************//

class eth_pause_frame_with_updated_pause_time extends eth_base_test;
  `uvm_component_utils(eth_pause_frame_with_updated_pause_time )
  function new (string name = "eth_pause_frame_with_updated_pause_time ", uvm_component parent = null);
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
    vseq.ether_type=46;
    vseq.pause_normal_traffic=1;
    vseq.pfc_with_vlan_traffic =0;
    vseq.pause_update_time_en =1;
    vseq.start(env_h.vseqr_h); 
      wait_until_complete();
    phase.drop_objection(this);
  endtask    
endclass

