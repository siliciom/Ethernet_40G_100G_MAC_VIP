`ifndef ETH_REG_MODEL_SV
`define ETH_REG_MODEL_SV

class eth_reg_block extends uvm_reg_block;

  `uvm_object_utils(eth_reg_block)

  tx_pad_control_reg tx_pad_control;
  tx_crc_control_reg tx_crc_control;
  tx_frame_minlength_reg tx_frame_minlength;
  tx_frame_maxlength_reg tx_frame_maxlength;
  tx_single_vlan_enable_reg tx_single_vlan_enable;
  tx_double_vlan_enable_reg tx_double_vlan_enable;
  tx_pauseframe_enable_reg tx_pauseframe_enable;
  tx_pauseframe_quanta_reg tx_pauseframe_quanta;
  tx_pfc_priority_enable_reg tx_pfc_priority_enable;
  tx_pause_quanta_0_reg tx_pause_quanta_0;
  tx_pause_quanta_1_reg tx_pause_quanta_1;
  tx_pause_quanta_2_reg tx_pause_quanta_2;
  tx_pause_quanta_3_reg tx_pause_quanta_3;
  tx_pause_quanta_4_reg tx_pause_quanta_4;
  tx_pause_quanta_5_reg tx_pause_quanta_5;
  tx_pause_quanta_6_reg tx_pause_quanta_6;
  tx_pause_quanta_7_reg tx_pause_quanta_7;

  rx_frame_minlength_reg rx_frame_minlength;
  rx_frame_maxlength_reg rx_frame_maxlength;
  rx_single_vlan_enable_reg rx_single_vlan_enable;
  rx_double_vlan_enable_reg rx_double_vlan_enable;
  rx_padcrc_control_reg rx_padcrc_control;
  rx_crccheck_control_reg rx_crccheck_control;
  rx_frame_control_reg rx_frame_control;
  rx_pfc_control_reg rx_pfc_control;

  uvm_reg_map default_map;

  function new(string name = "eth_reg_block");
    super.new(name, UVM_NO_COVERAGE);
  endfunction

  virtual function void build();

    tx_pad_control          = tx_pad_control_reg::type_id::create("tx_pad_control");
    tx_crc_control          = tx_crc_control_reg::type_id::create("tx_crc_control");
    tx_frame_minlength      = tx_frame_minlength_reg::type_id::create("tx_frame_minlength");
    tx_frame_maxlength      = tx_frame_maxlength_reg::type_id::create("tx_frame_maxlength");
    tx_single_vlan_enable   = tx_single_vlan_enable_reg::type_id::create("tx_single_vlan_enable");
    tx_double_vlan_enable   = tx_double_vlan_enable_reg::type_id::create("tx_double_vlan_enable");
    tx_pauseframe_enable    = tx_pauseframe_enable_reg::type_id::create("tx_pauseframe_enable");
    tx_pauseframe_quanta    = tx_pauseframe_quanta_reg::type_id::create("tx_pauseframe_quanta");
    tx_pfc_priority_enable  = tx_pfc_priority_enable_reg::type_id::create("tx_pfc_priority_enable");

    tx_pause_quanta_0 = tx_pause_quanta_0_reg::type_id::create("tx_pause_quanta_0");
    tx_pause_quanta_1 = tx_pause_quanta_1_reg::type_id::create("tx_pause_quanta_1");
    tx_pause_quanta_2 = tx_pause_quanta_2_reg::type_id::create("tx_pause_quanta_2");
    tx_pause_quanta_3 = tx_pause_quanta_3_reg::type_id::create("tx_pause_quanta_3");
    tx_pause_quanta_4 = tx_pause_quanta_4_reg::type_id::create("tx_pause_quanta_4");
    tx_pause_quanta_5 = tx_pause_quanta_5_reg::type_id::create("tx_pause_quanta_5");
    tx_pause_quanta_6 = tx_pause_quanta_6_reg::type_id::create("tx_pause_quanta_6");
    tx_pause_quanta_7 = tx_pause_quanta_7_reg::type_id::create("tx_pause_quanta_7");

    rx_frame_minlength    = rx_frame_minlength_reg::type_id::create("rx_frame_minlength");
    rx_frame_maxlength    = rx_frame_maxlength_reg::type_id::create("rx_frame_maxlength");
    rx_single_vlan_enable = rx_single_vlan_enable_reg::type_id::create("rx_single_vlan_enable");
    rx_double_vlan_enable = rx_double_vlan_enable_reg::type_id::create("rx_double_vlan_enable");
    rx_padcrc_control     = rx_padcrc_control_reg::type_id::create("rx_padcrc_control");
    rx_crccheck_control   = rx_crccheck_control_reg::type_id::create("rx_crccheck_control");
    rx_frame_control      = rx_frame_control_reg::type_id::create("rx_frame_control");
    rx_pfc_control        = rx_pfc_control_reg::type_id::create("rx_pfc_control");

    tx_pad_control.build();
    tx_crc_control.build();
    tx_frame_minlength.build();
    tx_frame_maxlength.build();
    tx_single_vlan_enable.build();
    tx_double_vlan_enable.build();
    tx_pauseframe_enable.build();
    tx_pauseframe_quanta.build();
    tx_pfc_priority_enable.build();

    tx_pause_quanta_0.build();
    tx_pause_quanta_1.build();
    tx_pause_quanta_2.build();
    tx_pause_quanta_3.build();
    tx_pause_quanta_4.build();
    tx_pause_quanta_5.build();
    tx_pause_quanta_6.build();
    tx_pause_quanta_7.build();

    rx_frame_minlength.build();
    rx_frame_maxlength.build();
    rx_single_vlan_enable.build();
    rx_double_vlan_enable.build();
    rx_padcrc_control.build();
    rx_crccheck_control.build();
    rx_frame_control.build();
    rx_pfc_control.build();

    tx_pad_control.configure(this);
    tx_crc_control.configure(this);
    tx_frame_minlength.configure(this);
    tx_frame_maxlength.configure(this);
    tx_single_vlan_enable.configure(this);
    tx_double_vlan_enable.configure(this);
    tx_pauseframe_enable.configure(this);
    tx_pauseframe_quanta.configure(this);
    tx_pfc_priority_enable.configure(this);

    tx_pause_quanta_0.configure(this);
    tx_pause_quanta_1.configure(this);
    tx_pause_quanta_2.configure(this);
    tx_pause_quanta_3.configure(this);
    tx_pause_quanta_4.configure(this);
    tx_pause_quanta_5.configure(this);
    tx_pause_quanta_6.configure(this);
    tx_pause_quanta_7.configure(this);

    rx_frame_minlength.configure(this);
    rx_frame_maxlength.configure(this);
    rx_single_vlan_enable.configure(this);
    rx_double_vlan_enable.configure(this);
    rx_padcrc_control.configure(this);
    rx_crccheck_control.configure(this);
    rx_frame_control.configure(this);
    rx_pfc_control.configure(this);

    default_map = create_map("default_map", 0, 4, UVM_LITTLE_ENDIAN);

    default_map.add_reg(tx_pad_control,         'h0000, "RW");
    default_map.add_reg(tx_crc_control,         'h0004, "RW");
    default_map.add_reg(tx_frame_minlength,     'h0008, "RW");
    default_map.add_reg(tx_frame_maxlength,     'h000C, "RW");
    default_map.add_reg(tx_single_vlan_enable,  'h0010, "RW");
    default_map.add_reg(tx_double_vlan_enable,  'h0014, "RW");
    default_map.add_reg(tx_pauseframe_enable,   'h0018, "RW");
    default_map.add_reg(tx_pauseframe_quanta,   'h001C, "RW");
    default_map.add_reg(tx_pfc_priority_enable, 'h0020, "RW");

    default_map.add_reg(tx_pause_quanta_0, 'h0024, "RW");
    default_map.add_reg(tx_pause_quanta_1, 'h0028, "RW");
    default_map.add_reg(tx_pause_quanta_2, 'h002C, "RW");
    default_map.add_reg(tx_pause_quanta_3, 'h0030, "RW");
    default_map.add_reg(tx_pause_quanta_4, 'h0034, "RW");
    default_map.add_reg(tx_pause_quanta_5, 'h0038, "RW");
    default_map.add_reg(tx_pause_quanta_6, 'h003C, "RW");
    default_map.add_reg(tx_pause_quanta_7, 'h0040, "RW");

    default_map.add_reg(rx_frame_minlength,    'h0044, "RW");
    default_map.add_reg(rx_frame_maxlength,    'h0048, "RW");
    default_map.add_reg(rx_single_vlan_enable, 'h004C, "RW");
    default_map.add_reg(rx_double_vlan_enable, 'h0050, "RW");
    default_map.add_reg(rx_padcrc_control,     'h0054, "RW");
    default_map.add_reg(rx_crccheck_control,   'h0058, "RW");
    default_map.add_reg(rx_frame_control,      'h005C, "RW");
    default_map.add_reg(rx_pfc_control,        'h0060, "RW");

    lock_model();

  endfunction

endclass

`endif

