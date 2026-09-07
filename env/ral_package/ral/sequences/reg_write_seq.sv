class reg_write_seq extends ral_base_seq;

  `uvm_object_utils(reg_write_seq)

  function new(string name = "reg_write_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_status_e   status;
    uvm_reg_data_t data;

    super.body();

    data = $urandom();

    regmodel.tx_pad_control.write(status, data, UVM_FRONTDOOR);

    if (status != UVM_IS_OK) `uvm_error("RAL_WRITE", "tx_pad_control write failed")
  endtask

endclass
