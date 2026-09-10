class reg_read_seq extends ral_base_seq;

  `uvm_object_utils(reg_read_seq)

  function new(string name = "reg_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_status_e   status;
    uvm_reg_data_t data;

    super.body();

    regmodel.tx_pad_control.read(status, data, UVM_FRONTDOOR);

    if (status != UVM_IS_OK) `uvm_error("RAL_READ", "tx_pad_control read failed")
    else `uvm_info("RAL_READ", $sformatf("tx_pad_control = 0x%08h", data), UVM_MEDIUM)
  endtask

endclass
