class reg_write_read_seq extends ral_base_seq;

  `uvm_object_utils(reg_write_read_seq)

  function new(string name = "reg_write_read_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_status_e   status;
    uvm_reg_data_t write_data;
    uvm_reg_data_t read_data;

    super.body();

    write_data = $urandom();

    regmodel.tx_pad_control.write(status, write_data, UVM_FRONTDOOR);

    if (status != UVM_IS_OK) `uvm_fatal("RAL_RW", "Register write failed")

    regmodel.tx_pad_control.read(status, read_data, UVM_FRONTDOOR);

    if (status != UVM_IS_OK) `uvm_fatal("RAL_RW", "Register read failed")

    if (read_data !== write_data)
      `uvm_error("RAL_RW", $sformatf("Readback mismatch: W=0x%08h R=0x%08h", write_data, read_data))
    else `uvm_info("RAL_RW", "Write/readback successful", UVM_MEDIUM)
  endtask

endclass
