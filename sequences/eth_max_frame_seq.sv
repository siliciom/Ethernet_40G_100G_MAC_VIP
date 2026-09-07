class eth_max_size_seq extends base_seq;
  `uvm_object_utils(eth_max_size_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  function new(string name = "eth_max_size_seq");
    super.new(name);
  endfunction

  task body();
    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      fixed_ethertype_item(1500);
      req.padding_en = 1;
      finish_item(req);
    end
  endtask
endclass


