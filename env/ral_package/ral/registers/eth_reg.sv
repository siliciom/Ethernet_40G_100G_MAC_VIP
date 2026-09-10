`ifndef ETH_REG_SV
`define ETH_REG_SV

// Individual uvm_reg class for each Ethernet register.
// Each class is intentionally separate so register types can be
// independently extended with fields/access policies in future.

class tx_pad_control_reg extends uvm_reg;
  `uvm_object_utils(tx_pad_control_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_pad_control_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(
                    .parent(this), 
                    .size(32), 
                    .lsb_pos(0),
                    .access("RW"),
                    .volatile(1),
                    .reset(32'h0000_0001),
                    .has_reset(1),
                    .is_rand(1),
                    .individually_accessible(0));
  endfunction
endclass

class tx_crc_control_reg extends uvm_reg;
  `uvm_object_utils(tx_crc_control_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_crc_control_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0003, 1, 1, 0);
  endfunction
endclass

class tx_frame_minlength_reg extends uvm_reg;
  `uvm_object_utils(tx_frame_minlength_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_frame_minlength_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0040, 1, 1, 0);  // 64
  endfunction
endclass

class tx_frame_maxlength_reg extends uvm_reg;
  `uvm_object_utils(tx_frame_maxlength_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_frame_maxlength_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_05EE, 1, 1, 0);  // 1518
  endfunction
endclass

class tx_single_vlan_enable_reg extends uvm_reg;
  `uvm_object_utils(tx_single_vlan_enable_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_single_vlan_enable_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

class tx_double_vlan_enable_reg extends uvm_reg;
  `uvm_object_utils(tx_double_vlan_enable_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_double_vlan_enable_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

class tx_pauseframe_enable_reg extends uvm_reg;
  `uvm_object_utils(tx_pauseframe_enable_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_pauseframe_enable_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

class tx_pauseframe_quanta_reg extends uvm_reg;
  `uvm_object_utils(tx_pauseframe_quanta_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_pauseframe_quanta_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

class tx_pfc_priority_enable_reg extends uvm_reg;
  `uvm_object_utils(tx_pfc_priority_enable_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_pfc_priority_enable_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

class tx_pause_quanta_0_reg extends uvm_reg;
  `uvm_object_utils(tx_pause_quanta_0_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_pause_quanta_0_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

class tx_pause_quanta_1_reg extends uvm_reg;
  `uvm_object_utils(tx_pause_quanta_1_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_pause_quanta_1_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

class tx_pause_quanta_2_reg extends uvm_reg;
  `uvm_object_utils(tx_pause_quanta_2_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_pause_quanta_2_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

class tx_pause_quanta_3_reg extends uvm_reg;
  `uvm_object_utils(tx_pause_quanta_3_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_pause_quanta_3_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

class tx_pause_quanta_4_reg extends uvm_reg;
  `uvm_object_utils(tx_pause_quanta_4_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_pause_quanta_4_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

class tx_pause_quanta_5_reg extends uvm_reg;
  `uvm_object_utils(tx_pause_quanta_5_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_pause_quanta_5_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

class tx_pause_quanta_6_reg extends uvm_reg;
  `uvm_object_utils(tx_pause_quanta_6_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_pause_quanta_6_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

class tx_pause_quanta_7_reg extends uvm_reg;
  `uvm_object_utils(tx_pause_quanta_7_reg)
  rand uvm_reg_field value;

  function new(string name = "tx_pause_quanta_7_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

class rx_frame_minlength_reg extends uvm_reg;
  `uvm_object_utils(rx_frame_minlength_reg)
  rand uvm_reg_field value;

  function new(string name = "rx_frame_minlength_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0040, 1, 1, 0);  // 64
  endfunction
endclass

class rx_frame_maxlength_reg extends uvm_reg;
  `uvm_object_utils(rx_frame_maxlength_reg)
  rand uvm_reg_field value;

  function new(string name = "rx_frame_maxlength_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_05EE, 1, 1, 0);  // 1518
  endfunction
endclass

class rx_single_vlan_enable_reg extends uvm_reg;
  `uvm_object_utils(rx_single_vlan_enable_reg)
  rand uvm_reg_field value;

  function new(string name = "rx_single_vlan_enable_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

class rx_double_vlan_enable_reg extends uvm_reg;
  `uvm_object_utils(rx_double_vlan_enable_reg)
  rand uvm_reg_field value;

  function new(string name = "rx_double_vlan_enable_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

class rx_padcrc_control_reg extends uvm_reg;
  `uvm_object_utils(rx_padcrc_control_reg)
  rand uvm_reg_field value;

  function new(string name = "rx_padcrc_control_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0001, 1, 1, 0);
  endfunction
endclass

class rx_crccheck_control_reg extends uvm_reg;
  `uvm_object_utils(rx_crccheck_control_reg)
  rand uvm_reg_field value;

  function new(string name = "rx_crccheck_control_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0002, 1, 1, 0);
  endfunction
endclass

class rx_frame_control_reg extends uvm_reg;
  `uvm_object_utils(rx_frame_control_reg)
  rand uvm_reg_field value;

  function new(string name = "rx_frame_control_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

class rx_pfc_control_reg extends uvm_reg;
  `uvm_object_utils(rx_pfc_control_reg)
  rand uvm_reg_field value;

  function new(string name = "rx_pfc_control_reg");
    super.new(name, 32, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();
    value = uvm_reg_field::type_id::create("value");
    value.configure(this, 32, 0, "RW", 1, 32'h0000_0000, 1, 1, 0);
  endfunction
endclass

`endif

