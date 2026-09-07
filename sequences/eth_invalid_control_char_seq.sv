//******************************************************************//
//           ETHERNET INVALID CONTROL CHARACTER SEQUENCE
//
// Generates frames with invalid control characters injected into
// the interface to verify invalid control character detection.
//******************************************************************//

class eth_invalid_control_char_seq extends base_seq;

  error_cb err_cb;
  int invalid_char_pkt_cnt;
  int unsigned SKIP_FRAMES = 2;
  int wt_dist0;
  int wt_dist1;


  `uvm_object_utils(eth_invalid_control_char_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  function new(string name = "eth_invalid_control_char_seq");
    super.new(name);
  endfunction

  task body();
    if (err_cb == null) `uvm_fatal("ERR_CB", "eth_invalid_control_char_seq requires err_cb")

    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      clear_error_flags();
      if (invalid_char_pkt_cnt > SKIP_FRAMES) begin
        void'(std::randomize(
            err_cb.invalid_control_en
        ) with {
          err_cb.invalid_control_en dist {
            0 := wt_dist0,
            1 := wt_dist1
          };
        });
      end else begin
        err_cb.invalid_control_en = 0;  // force normal/clean frame
      end
      invalid_char_pkt_cnt++;
      fixed_ethertype_item($urandom_range(46, 1500));
      req.padding_en = 1;
      finish_item(req);
    end
  endtask

endclass
