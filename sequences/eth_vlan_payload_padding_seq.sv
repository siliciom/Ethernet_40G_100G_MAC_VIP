//******************************************************************//
//               ETHERNET VLAN PAYLOAD PADDING SEQUENCE
//
// Generates VLAN-tagged Ethernet frames with payload sizes smaller
// than the minimum for VLAN frames (42 bytes) to verify automatic
// padding insertion. VLAN frames add 4 bytes of tag, so payload
// must be at least 42 bytes (46 - 4 = 42).
//******************************************************************//

class eth_vlan_payload_padding_seq extends base_seq;

  eth_seq_item req;
  uvm_status_e status;
  uvm_reg_data_t tx_pad_enable, tx_single_vlan;
  eth_cnfg cfg_h;

  `uvm_object_utils(eth_vlan_payload_padding_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  function new(string name = "eth_vlan_payload_padding_seq");
    super.new(name);
  endfunction

  task body();
    cfg_h.ral_model.tx_pad_control.read(status, tx_pad_enable, UVM_FRONTDOOR);
    cfg_h.ral_model.tx_single_vlan_enable.read(status, tx_single_vlan, UVM_FRONTDOOR);
    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      req.randomize() with {
        sa == p_sequencer.mac_addr;
        payload.size() inside {[0 : 41]};
      };
      req.tx_single_vlan_enable = tx_single_vlan;
      req.vlan_en = 1;
      req.TPID = 16'h8100;
      req.PCP = $urandom_range(0, 7);
      req.DEI = $urandom_range(0, 1);
      req.VID = $urandom_range(1, 4094);
      req.padding_en = tx_pad_enable;

      finish_item(req);
    end
  endtask

endclass
