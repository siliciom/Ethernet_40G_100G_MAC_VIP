//******************************************************************//
//                ETHERNET MULTICAST FRAME SEQUENCE
//
// Generates multicast Ethernet frames (DA with multicast bit set).
//******************************************************************//

class eth_multicast_frame_seq extends base_seq;

  `uvm_object_utils(eth_multicast_frame_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  function new(string name = "eth_multicast_frame_seq");
    super.new(name);
  endfunction

  task body();
    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      fixed_ethertype_item($urandom_range(46, 1500));
      req.custom_da = 1;
      req.da = 48'h01_50_40_30_20_10;  // Multicast destination address
      req.padding_en = 1;
      finish_item(req);
    end
  endtask

endclass
