class eth_error_detection_seq extends base_seq;
  int unsigned wt_dist0 = 40;
  int unsigned wt_dist1 = 60;
  error_cb err_cb;

  `uvm_declare_p_sequencer(eth_seqr)
  `uvm_object_utils(eth_error_detection_seq)

  function new(string name = "eth_error_detection_seq");
    super.new(name);
  endfunction

  task body();
    if (err_cb == null) `uvm_fatal("ERR_CB", "eth_error_detection_seq requires err_cb")

    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      clear_error_flags();
      void'(std::randomize(
          err_cb.ctrl_error_en
      ) with {
        err_cb.ctrl_error_en dist {
          0 := wt_dist0,
          1 := wt_dist1
        };
      });

      randomise_item();
      finish_item(req);
    end
  endtask
endclass
