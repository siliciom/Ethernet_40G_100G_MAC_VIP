//******************************************************************//
//         ETHERNET NORMAL PAYLOAD PADDING TEST
//
// Defines the Ethernet payload padding test. This test
// verifies automatic padding of frames with payloads smaller
// than the minimum Ethernet frame size.
//
//******************************************************************// 
class eth_normal_payload_padding_test extends eth_base_test;
  `uvm_component_utils(eth_normal_payload_padding_test)
  function new (string name = "eth_normal_payload_padding_test", uvm_component parent = null);
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
      vseq.frame_mode = base_virtual_seq::NORMAL_PADDING;
      vseq.start(env_h.vseqr_h);
      wait_until_complete();
    phase.drop_objection(this);
  endtask  
endclass

