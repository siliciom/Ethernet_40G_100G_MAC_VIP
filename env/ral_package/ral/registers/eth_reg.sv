`ifndef ETH_REG_SV
`define ETH_REG_SV

class eth_reg extends uvm_reg;

  `uvm_object_utils(eth_reg)

  rand uvm_reg_field value;

  function new(string name = "eth_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build(uvm_reg_data_t reset_value = '0);
    value = uvm_reg_field::type_id::create("value");
    //configure( parent, size, lsb_pos, access, volatile, reset, has_reset, is_rand, individually_accessible);
    value.configure(this, 32, 0, "RW", 1, reset_value, 1, 1, 0);
  endfunction

endclass

`endif
