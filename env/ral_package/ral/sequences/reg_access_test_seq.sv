class reg_access_test_seq extends ral_base_seq;

  `uvm_object_utils(reg_access_test_seq)

  function new(string name = "reg_access_test_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_reg regs[$];
    uvm_status_e status;
    uvm_reg_data_t write_data;
    uvm_reg_data_t read_data;

    super.body();

    regmodel.get_registers(regs, UVM_NO_HIER);

    foreach (regs[i]) begin
      write_data = $urandom();

      regs[i].write(status, write_data, UVM_FRONTDOOR);

      if (status != UVM_IS_OK) begin
        `uvm_error("RAL_ACCESS", $sformatf("%s write failed", regs[i].get_name()))
        continue;
      end

      regs[i].read(status, read_data, UVM_FRONTDOOR);

      if (status != UVM_IS_OK) begin
        `uvm_error("RAL_ACCESS", $sformatf("%s read failed", regs[i].get_name()))
        continue;
      end

      if (read_data !== write_data)
        `uvm_error("RAL_ACCESS", $sformatf(
                   "%s mismatch W=%08h R=%08h", regs[i].get_name(), write_data, read_data))
    end
  endtask

endclass
