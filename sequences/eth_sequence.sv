//******************************************************************//
//                     ETHERNET SEQUENCE FILE
//
// Implements Ethernet stimulus sequences. Sequences generate Ethernet
// frames and protocol scenarios such as data traffic, pause frames,
// control frames, error injection, VLAN packets, jumbo frames, and
// other protocol-specific test cases.
// TODO:- Need to update the features of MAC behaviour.
//
// Author: Ankitha, Sanjeev
//
//******************************************************************//
class base_seq extends uvm_sequence #(eth_seq_item);
  `uvm_object_utils(base_seq)
  
  function new (string name = "base_seq");
    super.new(name);
  endfunction
endclass

class eth_normal_frame_seq extends base_seq;
  eth_seq_item req;
  `uvm_object_utils(eth_normal_frame_seq)
  `uvm_declare_p_sequencer(eth_seqr)
  
  function new (string name = "eth_normal_frame_seq");
    super.new(name);
  endfunction
  virtual task body();
    `uvm_info(get_type_name(), "eth_normal_frame_seq: Inside Body", UVM_LOW)
    
    req = eth_seq_item::type_id::create("req");
    start_item(req);

    if (!req.randomize()) begin
      `uvm_error(get_type_name(), "Randomization failed")
    end

    finish_item(req);
  endtask
endclass
