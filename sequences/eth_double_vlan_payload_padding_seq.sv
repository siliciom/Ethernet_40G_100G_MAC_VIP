//******************************************************************//
//           ETHERNET DOUBLE VLAN PAYLOAD PADDING SEQUENCE
//
// Generates ONLY double VLAN (Q-in-Q) tagged Ethernet frames with
// payload sizes 0-37 bytes.
//
// Double VLAN minimum payload:
//     46 - 4 - 4 = 38 bytes
//
// Therefore every generated packet requires padding.
//
// RAL registers:
//     tx_double_vlan_enable = 1 -> required
//
// No normal packets.
// No single VLAN packets.
//******************************************************************//

`ifndef ETH_DOUBLE_VLAN_PAYLOAD_PADDING_SEQ_SV
`define ETH_DOUBLE_VLAN_PAYLOAD_PADDING_SEQ_SV

class eth_double_vlan_payload_padding_seq extends base_seq;

  `uvm_object_utils(eth_double_vlan_payload_padding_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  eth_cnfg cfg_h;

  uvm_status_e status;
  uvm_reg_data_t tx_double_vlan_enable;
  uvm_reg_data_t rx_double_vlan_enable;
  uvm_reg_data_t tx_pad_enable;

  function new(string name = "eth_double_vlan_payload_padding_seq");
    super.new(name);
  endfunction


  task body();

    if (cfg_h == null)
      `uvm_fatal("CFG_NULL", "eth_cnfg handle is null in eth_double_vlan_payload_padding_seq")

    cfg_h.ral_model.tx_double_vlan_enable.write(status, 1, UVM_FRONTDOOR);
    cfg_h.ral_model.rx_double_vlan_enable.write(status, 1, UVM_FRONTDOOR);
    //==============================================================
    // READ DOUBLE VLAN REGISTERS ONCE
    //==============================================================

    cfg_h.ral_model.tx_double_vlan_enable.read(status, tx_double_vlan_enable, UVM_FRONTDOOR);
    cfg_h.ral_model.rx_double_vlan_enable.read(status, rx_double_vlan_enable, UVM_FRONTDOOR);
    cfg_h.ral_model.tx_pad_control.read(status, tx_pad_enable, UVM_FRONTDOOR);

    if (!tx_double_vlan_enable[0]) begin
      `uvm_fatal("TX_DOUBLE_VLAN_DISABLED", "TX Double VLAN Enable register is 0. ")
    end


    if (!rx_double_vlan_enable[0]) begin
      `uvm_fatal("RX_DOUBLE_VLAN_DISABLED", "RX Double VLAN Enable register is 0. ")
    end

    if (!tx_pad_enable) begin
      `uvm_fatal("tx_pad_enable", "RX Double VLAN Enable register is 0. ")
    end

    //==============================================================
    // GENERATE ONLY DOUBLE VLAN PACKETS
    //==============================================================

    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      //randomise_item();
      req.randomize() with {
        sa == p_sequencer.mac_addr;
        payload.size() == ether_type;
        ether_type inside {[0 : 37]};
      };


      //============================================================
      // FORCE DOUBLE VLAN FLAGS FROM RAL CONFIGURATION
      //============================================================

      req.tx_double_vlan_en     = tx_double_vlan_enable[0];
      req.rx_double_vlan_en     = rx_double_vlan_enable[0];
      req.outer_vlan_en         = 1;
      req.vlan_en               = 1;


      //============================================================
      // OUTER VLAN TAG
      //============================================================

      req.outer_TPID            = 16'h88A8;
      req.outer_PCP             = $urandom_range(0, 7);
      req.outer_DEI             = 1'b0;
      req.outer_VID             = $urandom_range(1, 4094);


      //============================================================
      // INNER VLAN TAG
      //============================================================

      req.TPID                  = 16'h8100;
      req.PCP                   = $urandom_range(0, 7);
      req.DEI                   = 1'b0;
      req.VID                   = $urandom_range(1, 4094);
      req.padding_en            = tx_pad_enable;
      finish_item(req);

    end

  endtask

endclass

`endif
