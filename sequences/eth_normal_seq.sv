//------------------------------------------------------------------------------
//                        ETH_NORMAL_FRAME_SEQ
// Normal frame sequence.
// Generates an Ethernet frame using the configured packet parameters.
//------------------------------------------------------------------------------
class eth_normal_frame_seq extends base_seq;

  eth_cnfg cfg_h;

  `uvm_object_utils(eth_normal_frame_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  function new(string name = "eth_normal_frame_seq");
    super.new(name);
  endfunction

  task body();

    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      randomise_item();
      finish_item(req);

    end
  endtask
endclass
