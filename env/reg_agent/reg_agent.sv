class reg_agent extends uvm_agent;

  `uvm_component_utils(reg_agent)

  reg_sequencer seqr;
  reg_driver    drv;
  reg_monitor   mon;

  function new(string name = "reg_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    seqr = reg_sequencer::type_id::create("seqr", this);
    drv  = reg_driver::type_id::create("drv", this);
    mon  = reg_monitor::type_id::create("mon", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction

endclass
