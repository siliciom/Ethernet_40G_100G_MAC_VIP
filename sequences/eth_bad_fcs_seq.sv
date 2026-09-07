//******************************************************************//
//                   ETHERNET BAD FCS SEQUENCE
//
// Generates frames with corrupted FCS (CRC) to verify detection
// and discarding of bad CRC frames.
//******************************************************************//

class eth_bad_fcs_seq extends base_seq;

  error_cb err_cb;
  int wt_dist0;
  int wt_dist1;

  `uvm_object_utils(eth_bad_fcs_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  function new(string name = "eth_bad_fcs_seq");
    super.new(name);
  endfunction

  task body();
    if (err_cb == null) `uvm_fatal("ERR_CB", "eth_bad_fcs_seq requires err_cb")

    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      clear_error_flags();
      void'(std::randomize(
          err_cb.bad_fcs_en
      ) with {
        err_cb.bad_fcs_en dist {
          0 := wt_dist0,
          1 := wt_dist1
        };
      });
      fixed_ethertype_item($urandom_range(46, 1500));
      req.padding_en = 1;
      finish_item(req);
    end
  endtask

endclass
