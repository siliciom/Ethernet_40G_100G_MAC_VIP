//******************************************************************//
//      ETHERNET PAUSE FRAME WITH UPDATED PAUSE TIME SEQUENCE
//
// Generates PAUSE frames with updated pause time values to verify
// that traffic pauses for the newly updated duration.
//******************************************************************//

class eth_pause_frame_updated_time_seq extends base_seq;

  `uvm_object_utils(eth_pause_frame_updated_time_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  bit pause_update_time_en;

  int num_pkts;
  bit pkt_rand_en;
  int wt_dist0;
  int wt_dist1;
  bit pause_pkt_sel;
  uvm_status_e status;
  eth_cnfg cfg_h;


  function new(string name = "eth_pause_frame_updated_time_seq");
    super.new(name);
  endfunction


  task body();

    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      randomise_item();
      void'(std::randomize(
          pause_pkt_sel
      ) with {
        pause_pkt_sel dist {
          0 := wt_dist0,
          1 := wt_dist1
        };
      });
      //============================================================
      // Default = normal frame
      //============================================================

      req.pause_frame_en = 1'b0;
      req.pause_sel      = 1'b0;


      //============================================================
      // Generate updated PAUSE frame
      //============================================================

      if (pause_update_time_en && pause_pkt_sel == 1 && (num_pkts < (no_of_pkts - 30))) begin

        req.pause_frame_en = 1'b1;
        req.pause_sel      = 1'b1;

        // MAC control PAUSE
        req.da             = 48'h0180_C200_0001;
        req.pause_opc      = 16'h0001;
        req.ether_type     = 16'h8808;

        // Updated pause time
        req.pause_time     = $urandom_range(1, 10);
      end else begin
        req.pause_frame_en = 1'b0;
        req.pause_sel      = 1'b0;
      end

      cfg_h.ral_model.tx_pauseframe_enable.write(status, req.pause_frame_en, UVM_FRONTDOOR);
      if (pkt_rand_en) begin
        cfg_h.ral_model.tx_pauseframe_quanta.write(status, pause_time, UVM_FRONTDOOR);
      end
      num_pkts++;
      finish_item(req);
    end
  endtask

endclass
