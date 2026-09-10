//******************************************************************//
//           ETHERNET MINIMUM SIZE FRAME SEQ 
//
// Defines the Ethernet minimum frame size Sequence. This seq
// verifies transmission, padding, and reception of frames
// with the minimum valid Ethernet payload.
//
//******************************************************************//

class eth_min_size_seq extends base_seq;
  `uvm_object_utils(eth_min_size_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  function new(string name = "eth_min_size_seq");
    super.new(name);
  endfunction

  task body();
    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      fixed_ethertype_item(46);
      req.padding_en = 0;
      finish_item(req);
    end
  endtask
endclass

