class ral_base_seq extends uvm_sequence;

  `uvm_object_utils(ral_base_seq)

  eth_reg_block regmodel;

  function new(string name = "ral_base_seq");
    super.new(name);
  endfunction

  virtual task body();
    if (!uvm_config_db#(eth_reg_block)::get(null, "", "regmodel", regmodel)) begin
      `uvm_fatal("RAL_SEQ", "Unable to get regmodel from uvm_config_db")
    end
  endtask

endclass
