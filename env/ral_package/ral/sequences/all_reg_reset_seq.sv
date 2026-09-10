class all_reg_reset_seq extends ral_base_seq;

  `uvm_object_utils(all_reg_reset_seq)

  function new(string name = "all_reg_reset_seq");
    super.new(name);
  endfunction

  virtual task body();
    uvm_status_e status;
    uvm_reg_data_t data;
    uvm_reg regs[$];

    super.body();

    regmodel.reset();
    regmodel.get_registers(regs, UVM_NO_HIER);

    foreach (regs[i]) begin
      regs[i].read(status, data, UVM_FRONTDOOR);

      if (status != UVM_IS_OK) begin
        `uvm_error("RAL_RESET", $sformatf("Read failed for %s", regs[i].get_name()))
        continue;
      end

      if (data !== 32'h0000_0000)
        `uvm_error("RAL_RESET", $sformatf("%s reset = 0x%08h, expected 0", regs[i].get_name(), data
                   ))
    end
  endtask

endclass
