//******************************************************************//
//                ETHERNET BROADCAST FRAME SEQUENCE
//
// Generates broadcast Ethernet frames (DA = FF:FF:FF:FF:FF:FF).
//******************************************************************//

class eth_broadcast_frame_seq extends base_seq;

  `uvm_object_utils(eth_broadcast_frame_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  function new(string name = "eth_broadcast_frame_seq");
    super.new(name);
  endfunction

  task body();
    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      fixed_ethertype_item($urandom_range(46, 1500));
      req.custom_da = 1;
      req.da = 48'hFF_FF_FF_FF_FF_FF;
      req.padding_en = 1;
      finish_item(req);
    end
  endtask

endclass
