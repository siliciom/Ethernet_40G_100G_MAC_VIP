class ral_smoke_test extends uvm_test;

  `uvm_component_utils(ral_smoke_test)

  eth_reg_block regmodel;
  master_reg_adapter adapter;

  function new(string name = "ral_smoke_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    regmodel = eth_reg_block::type_id::create("regmodel", this);
    regmodel.build();

    adapter = master_reg_adapter::type_id::create("adapter", this);

    regmodel.default_map.set_auto_predict(0);

    uvm_config_db#(eth_reg_block)::set(this, "*", "regmodel", regmodel);
  endfunction

  virtual task run_phase(uvm_phase phase);
    reg_write_read_seq seq;

    phase.raise_objection(this);

    seq = reg_write_read_seq::type_id::create("seq");
    seq.regmodel = regmodel;

    // Connect regmodel.default_map to the existing
    // Master sequencer in the environment before starting
    // this sequence. The exact handle is environment-specific.

    `uvm_info("RAL_SMOKE",
              "RAL smoke sequence created. Connect default_map to the existing Master sequencer.",
              UVM_LOW)

    phase.drop_objection(this);
  endtask

endclass
