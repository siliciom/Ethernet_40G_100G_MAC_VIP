//******************************************************************//
//            ETHERNET SIMULTANEOUS PAUSE FRAME SEQUENCE
//
// Generates simultaneous PAUSE frames on both directions along with
// normal traffic to verify correct pause/resume under simultaneous
// PAUSE conditions.
//******************************************************************//

class eth_pause_frame_simul_seq extends base_seq;

  `uvm_object_utils(eth_pause_frame_simul_seq)
  `uvm_declare_p_sequencer(eth_seqr)
  bit pause_simul_en;
  int num_pkts;
  bit [15:0] pause_time;
  bit pkt_rand_en;
  int wt_dist0;
  int wt_dist1;
  bit pause_pkt_sel;

  eth_cnfg cfg_h;
  uvm_status_e status;

  function new(string name = "eth_pause_frame_simul_seq");
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
      // Simultaneous pause - both directions get pause
      if (pause_simul_en && pause_pkt_sel && num_pkts < (no_of_pkts - 30)) begin
        req.pause_frame_en = 1;
        pause_time = $urandom_range(1, 10);
      end else req.pause_frame_en = 0;

      if (req.pause_frame_en) begin
        req.pause_opc  = 16'h0001;
        req.ether_type = 16'h8808;
        req.pause_time = this.pause_time;
        if ($urandom_range(0, 1)) req.da = 48'h0180c2000001;
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
