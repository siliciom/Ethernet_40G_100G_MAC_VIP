//******************************************************************//
//                ETHERNET UNICAST FRAME SEQUENCE
//
// Generates unicast Ethernet frames. This is equivalent to
// the normal frame sequence but with explicit unicast addressing.
//******************************************************************//

class eth_unicast_frame_seq extends base_seq;

  `uvm_object_utils(eth_unicast_frame_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  function new(string name = "eth_unicast_frame_seq");
    super.new(name);
  endfunction

  task body();
    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      // Use random payload size like normal frame
      fixed_ethertype_item($urandom_range(46, 1500));
      req.padding_en = 1;
      finish_item(req);
    end
  endtask

endclass
