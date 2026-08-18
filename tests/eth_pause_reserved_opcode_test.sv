//******************************************************************//
//            ETHERNET PAUSE RESERVED OPCODE TEST
//
// Defines the Ethernet PAUSE reserved opcode test. This test
// generates PAUSE control frames using a reserved (non-standard)
// opcode value instead of the standard PAUSE opcode (0x0001), and
// verifies that such frames are correctly identified/handled
// (e.g. ignored or flagged) rather than being treated as valid
// PAUSE frames.
//
//******************************************************************//
class eth_pause_reserved_opcode_test extends eth_base_test;
  `uvm_component_utils(eth_pause_reserved_opcode_test)
  function new (string name = "eth_pause_reserved_opcode_test", uvm_component parent = null);
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
      vseq.pause_normal_traffic=1;
      vseq.pfc_with_vlan_traffic =0;
      vseq.pause_rsd_en=1;
      vseq.start(env_h.vseqr_h);
      wait_until_complete();
    phase.drop_objection(this);
  endtask    
endclass

