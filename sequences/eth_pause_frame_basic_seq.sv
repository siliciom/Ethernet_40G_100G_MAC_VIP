//******************************************************************//
//           ETHERNET PAUSE FRAME BASIC XOFF/XON SEQUENCE
//
// Generates PAUSE control frames along with normal traffic and
// verifies XOFF/XON functionality. Runs on a single MAC sequencer.
//******************************************************************//
class eth_pause_frame_basic_seq extends base_seq;

  `uvm_object_utils(eth_pause_frame_basic_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  bit normal_xon_xoff_en;
  int num_pkts;
  bit [15:0] pause_time;
  bit pkt_rand_en;
  int wt_dist0;
  int wt_dist1;
  uvm_status_e status;
  eth_cnfg cfg_h;

  // 0 -> Normal Packet
  // 1 -> Pause Packet
  bit pause_pkt_sel;

  function new(string name = "eth_pause_frame_basic_seq");
    super.new(name);
  endfunction

  task body();
    int pause_gap_cnt = 0;
    bit send_immediate_xon;

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
      if (pause_gap_cnt > 0) pause_gap_cnt--;

      // Immediate XON
      if (send_immediate_xon) begin
        req.pause_frame_en = 1;
        pause_time = 0;
        send_immediate_xon = 0;
      end
      else if (normal_xon_xoff_en && pause_gap_cnt == 0 && pause_pkt_sel == 1 && num_pkts < (no_of_pkts - 30)) begin // 30% Pause Packets
        req.pause_frame_en = 1;
        pause_time = $urandom_range(1, 10);

        if (pause_time % 2 == 0)  //For even pause time, sending immediate Xon frames.
          send_immediate_xon = 1;

        // Pause gap between packets
        pause_gap_cnt = $urandom_range(5, 6);
      end else begin  // 70% Normal Packets
        req.pause_frame_en = 0;
      end

      // Configure Pause Frame
      if (req.pause_frame_en) begin
        req.pause_opc  = 16'h0001;
        req.ether_type = 16'h8808;
        req.pause_time = this.pause_time;

        if ($urandom_range(0, 1)) req.da = 48'h0180c2000001;
      end

      // RAL Register Write
      cfg_h.ral_model.tx_pauseframe_enable.write(status, req.pause_frame_en, UVM_FRONTDOOR);

      if (pkt_rand_en) begin
        cfg_h.ral_model.tx_pauseframe_quanta.write(status, pause_time, UVM_FRONTDOOR);
      end

      num_pkts++;
      finish_item(req);
    end
  endtask

endclass
