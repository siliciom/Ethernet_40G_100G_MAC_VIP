//******************************************************************//
//                  ETHERNET VIRTUAL SEQUENCE FILE
//
// Implements system-level Ethernet test scenarios by coordinating
// multiple lower-level sequences through the virtual sequencer. It is
// used to generate synchronized traffic and complex protocol
// interactions across multiple interfaces.
// TODO:- Need to update the MAC features and its logic
//
// Author: Ankitha, Sanjeev
//
//******************************************************************//
class base_virtual_seq extends uvm_sequence;
  `uvm_object_utils(base_virtual_seq)

  function new (string name = "base_virtual_seq");
    super.new(name);
  endfunction  
endclass

class virtual_seq extends base_virtual_seq;
  `uvm_object_utils(virtual_seq)
  `uvm_declare_p_sequencer(eth_virtual_seqr)

  eth_normal_frame_seq seq1, seq2;  

  //**************************************************************//
  // This function creates the virtual sequence object.
  //**************************************************************//
  function new (string name = "virtual_seq");
    super.new(name);
  endfunction  

  //**************************************************************//
  // This function creates and starts the required Ethernet
  // sequences on the configured MAC sequencer.
  //**************************************************************//
  task body();

      seq1 = eth_normal_frame_seq::type_id::create("seq1");
      seq2 = eth_normal_frame_seq::type_id::create("seq2");
      // configure sequences config variables received from test
      fork
	seq1.start(p_sequencer.mac_seqr_h[0]);
      join
  endtask

  
endclass


