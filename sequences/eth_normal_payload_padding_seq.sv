//******************************************************************//
//              ETHERNET NORMAL PAYLOAD PADDING SEQUENCE
//
// Generates Ethernet frames with payload sizes smaller than the
// minimum Ethernet frame size (46 bytes) to verify automatic
// padding insertion by the MAC.
//******************************************************************//

class eth_normal_payload_padding_seq extends base_seq;

  eth_cnfg cfg_h;
  uvm_status_e status;
  uvm_reg_data_t tx_pad_enable;
  //uvm_reg_data_t rx_vlan_enable;
  `uvm_object_utils(eth_normal_payload_padding_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  function new(string name = "eth_normal_payload_padding_seq");
    super.new(name);
  endfunction

  task body();
    if (cfg_h == null) `uvm_fatal("CFG_NULL", "eth_cnfg handle is null in eth_single_vlan_seq")
    cfg_h.ral_model.tx_pad_control.read(status, tx_pad_enable, UVM_FRONTDOOR);
    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      fixed_ethertype_item($urandom_range(0, 45));
      req.padding_en = tx_pad_enable;  // Enable padding
      finish_item(req);
    end
  endtask

endclass
