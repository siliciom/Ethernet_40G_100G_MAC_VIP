//******************************************************************//
//                ETHERNET OVERSIZE FRAME SEQUENCE
//
// Generates oversized Ethernet frames (payload > 1500 bytes) to
// verify oversize frame detection and handling.
//******************************************************************//

class eth_oversize_frame_seq extends base_seq;

  eth_cnfg cfg_h;
  uvm_status_e status;
  uvm_reg_data_t tx_pad_ctrl;
  `uvm_object_utils(eth_oversize_frame_seq)
  int wt_dist0;
  int wt_dist1;
  bit oversize_en;
  `uvm_declare_p_sequencer(eth_seqr)
  function new(string name = "eth_oversize_frame_seq");
    super.new(name);
  endfunction

  task body();
    if (cfg_h == null) `uvm_fatal("CFG_NULL", "eth_cnfg handle is null in eth_single_vlan_seq")
    cfg_h.ral_model.tx_pad_control.read(status, tx_pad_ctrl, UVM_FRONTDOOR);

    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      void'(std::randomize(
          oversize_en
      ) with {
        oversize_en dist {
          0 := wt_dist0,
          1 := wt_dist1
        };
      });
      if (oversize_en) begin
        fixed_ethertype_item($urandom_range(1501, 1517));
        req.padding_en = tx_pad_ctrl;
      end else begin
        randomise_item();
      end
      finish_item(req);
    end
  endtask

endclass

