//******************************************************************//
//              ETHERNET DOUBLE VLAN TAG SEQUENCE
//
// Generates double VLAN (Q-in-Q) tagged Ethernet frames.
// When register is enabled, randomizes per-packet: normal / single VLAN / double VLAN
//******************************************************************//

//******************************************************************//
//                  ETHERNET DOUBLE VLAN TAG SEQUENCE
//
// Generates ONLY Double VLAN (Q-in-Q) tagged Ethernet frames.
//
// Required RAL configuration:
//   TX Double VLAN Enable = 1
//   RX Double VLAN Enable = 1
//
// No normal packets.
// No single VLAN packets.
// Every generated packet is double VLAN tagged.
//
// RAL values are read once at sequence start and stamped onto req.
//******************************************************************//

`ifndef ETH_DOUBLE_VLAN_TAG_SEQ_SV
`define ETH_DOUBLE_VLAN_TAG_SEQ_SV

class eth_double_vlan_tag_seq extends base_seq;

  `uvm_object_utils(eth_double_vlan_tag_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  eth_cnfg cfg_h;

  uvm_status_e status;
  uvm_reg_data_t tx_double_vlan_enable;
  uvm_reg_data_t rx_double_vlan_enable;

  function new(string name = "eth_double_vlan_tag_seq");
    super.new(name);
  endfunction


  task body();

    if (cfg_h == null) `uvm_fatal("CFG_NULL", "eth_cnfg handle is null in eth_double_vlan_tag_seq")

    ////==============================================================
    //// READ DOUBLE VLAN ENABLE REGISTERS ONCE
    ////==============================================================

    //cfg_h.ral_model.tx_double_vlan_enable.read( status, tx_double_vlan_enable, UVM_FRONTDOOR);
    //cfg_h.ral_model.rx_double_vlan_enable.read( status, rx_double_vlan_enable, UVM_FRONTDOOR);


    //==============================================================
    // GENERATE ONLY DOUBLE VLAN PACKETS
    //==============================================================

    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      randomise_item();

      //============================================================
      // FORCE DOUBLE VLAN
      //============================================================

      req.tx_double_vlan_en     = 1;
      req.rx_double_vlan_en     = 1;

      req.tx_single_vlan_enable = 0;
      req.rx_single_vlan_enable = 0;

      req.outer_vlan_en         = 1;
      req.vlan_en               = 1;


      //============================================================
      // OUTER VLAN TAG
      //============================================================

      req.outer_TPID            = 16'h88A8;
      req.outer_PCP             = $urandom_range(0, 7);
      req.outer_DEI             = $urandom_range(0, 1);
      req.outer_VID             = $urandom_range(1, 4094);

      //============================================================
      // INNER VLAN TAG
      //============================================================

      req.TPID                  = 16'h8100;
      req.PCP                   = $urandom_range(0, 7);
      req.DEI                   = $urandom_range(0, 1);
      req.VID                   = $urandom_range(1, 4094);

      //============================================================
      // PADDING
      //============================================================
      req.padding_en            = 1;
      finish_item(req);

    end

  endtask

endclass

`endif
