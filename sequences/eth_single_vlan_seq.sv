class eth_single_vlan_seq extends base_seq;

  eth_cnfg cfg_h;

  uvm_status_e status;
  uvm_reg_data_t tx_vlan_enable;
  uvm_reg_data_t rx_vlan_enable;

  `uvm_object_utils(eth_single_vlan_seq)

  function new(string name = "eth_single_vlan_seq");
    super.new(name);
  endfunction

  task body();

    if (cfg_h == null) `uvm_fatal("CFG_NULL", "eth_cnfg handle is null in eth_single_vlan_seq")

    repeat (no_of_pkts) begin

      cfg_h.ral_model.tx_single_vlan_enable.read(status, tx_vlan_enable, UVM_FRONTDOOR);


      req = eth_seq_item::type_id::create("req");
      start_item(req);
      randomise_item();
      req.tx_single_vlan_enable = tx_vlan_enable[0];
      req.rx_single_vlan_enable = rx_vlan_enable[0];

      if (tx_vlan_enable[0] || rx_vlan_enable[0]) begin
        req.TPID = 16'h8100;
        req.PCP  = $urandom_range(0, 7);
        req.DEI  = $urandom_range(0, 1);
        req.VID  = $urandom_range(1, 4094);
      end


      finish_item(req);
    end

  endtask

endclass

