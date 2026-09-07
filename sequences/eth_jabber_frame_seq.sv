//******************************************************************//
//                ETHERNET JABBER FRAME SEQUENCE
//
// Generates jabber frames (oversized frames with bad FCS) to verify
// jabber frame detection.
//******************************************************************//

class eth_jabber_frame_seq extends base_seq;

  eth_cnfg cfg_h;
  `uvm_object_utils(eth_jabber_frame_seq)
  uvm_status_e status;
  uvm_reg_data_t tx_disable_pad;
  int wt_dist0;
  int wt_dist1;
  `uvm_declare_p_sequencer(eth_seqr)

  function new(string name = "eth_jabber_frame_seq");
    super.new(name);
  endfunction

  task body();
    if (cfg_h == null) `uvm_fatal("CFG_NULL", "eth_cnfg handle is null in eth_single_vlan_seq")
    cfg_h.ral_model.tx_pad_control.read(status, tx_disable_pad, UVM_FRONTDOOR);
    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      void'(std::randomize(
          jabber_en
      ) with {
        jabber_en dist {
          0 := wt_dist0,
          1 := wt_dist1
        };
      });
      if (jabber_en) begin
        fixed_ethertype_item($urandom_range(1536, 2000));
        req.padding_en = tx_disable_pad;
        req.jabber_en = 1;
        req.corrupt_fcs_en = 1;  // Bad FCS per jabber definition
      end else fixed_ethertype_item($urandom_range(1501, 2000));
      req.padding_en = tx_disable_pad;
      req.jabber_en  = 1;
      finish_item(req);
    end
  endtask

endclass

