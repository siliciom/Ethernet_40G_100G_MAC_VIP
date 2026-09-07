//******************************************************************//
//           ETHERNET PAUSE FRAME RESERVED OPCODE SEQUENCE
//
// Generates PAUSE control frames using a reserved (non-standard)
// opcode value instead of the standard PAUSE opcode (0x0001).
//******************************************************************//

class eth_pause_frame_reserved_opcode_seq extends base_seq;

  `uvm_object_utils(eth_pause_frame_reserved_opcode_seq)
  `uvm_declare_p_sequencer(eth_seqr)
  eth_cnfg cfg_h;
  uvm_status_e status;
  int num_pkts;
  bit pause_rsd_en;
  bit pkt_rand_en;
  int wt_dist0;
  int wt_dist1;
  bit pause_pkt_sel;

  function new(string name = "eth_pause_frame_reserved_opcode_seq");
    super.new(name);
  endfunction

  task body();
    if (cfg_h == null)
      `uvm_fatal("CFG_NULL", "eth_cnfg handle is null in eth_pause_frame_reserved_opcode_seq")

    cfg_h.ral_model.rx_frame_control.write(status, 32'h0000_0008, UVM_FRONTDOOR);
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

      if (pause_rsd_en && pause_pkt_sel && (num_pkts < (no_of_pkts - 30))) begin
        req.pause_frame_en        = 1'b1;
        req.pause_sel             = 1'b1;
        req.da                    = 48'h0180_C200_0001;
        req.ether_type            = 16'h8808;
        req.pause_opc             = 16'h0002;
        req.pause_time            = $urandom_range(1, 10);
        req.tx_single_vlan_enable = 1'b0;
        req.rx_single_vlan_enable = 1'b0;
        req.vlan_en               = 1'b0;
        req.TPID                  = 16'h0000;
        req.PCP                   = 0;
        req.DEI                   = 0;
        req.VID                   = 0;
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
