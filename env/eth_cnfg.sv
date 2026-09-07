//******************************************************************//
//            ETHERNET REGISTER CONFIGURATION FILE
//
// Defines the register configuration settings used by the Ethernet
// verification environment. It contains register initialization
// values, feature enable controls, protocol configuration fields,
// and other register-related parameters required during simulation.
// TODO:- Need to add the registers and its configurations
//
// Author: Lavanya
//
//******************************************************************//
class eth_cnfg extends uvm_object;

  `uvm_object_utils(eth_cnfg)

  eth_reg_block        ral_model;
  bit           [31:0] tx_pad_control;
  bit           [31:0] tx_crc_control;
  bit           [31:0] tx_frame_minlength;
  bit           [31:0] tx_frame_maxlength;
  bit           [31:0] tx_single_vlan_enable;
  bit           [31:0] tx_double_vlan_enable;
  bit           [31:0] tx_pauseframe_enable;
  bit           [31:0] tx_pauseframe_quanta;
  bit           [31:0] tx_pfc_priority_enable;
  bit           [31:0] tx_pause_quanta_0;
  bit           [31:0] tx_pause_quanta_1;
  bit           [31:0] tx_pause_quanta_2;
  bit           [31:0] tx_pause_quanta_3;
  bit           [31:0] tx_pause_quanta_4;
  bit           [31:0] tx_pause_quanta_5;
  bit           [31:0] tx_pause_quanta_6;
  bit           [31:0] tx_pause_quanta_7;

  bit           [31:0] rx_frame_minlength;
  bit           [31:0] rx_frame_maxlength;
  rand bit      [31:0] rx_single_vlan_enable;
  bit           [31:0] rx_double_vlan_enable;
  bit           [31:0] rx_padcrc_control;
  bit           [31:0] rx_crccheck_control;
  bit           [31:0] rx_frame_control;
  bit           [31:0] rx_pfc_control;

  function new(string name = "eth_cnfg");
    super.new(name);
    tx_pad_control         = 32'h0000_0001;
    tx_crc_control         = 32'h0000_0003;
    tx_frame_minlength     = 32'h0000_0040;  //64
    tx_frame_maxlength     = 32'h0000_05EE;  //1518
    tx_single_vlan_enable  = 32'h0000_0000;
    tx_double_vlan_enable  = 32'h0000_0000;
    tx_pauseframe_enable   = 32'h0000_0001;
    tx_pauseframe_quanta   = 32'h0000_0000;
    tx_pfc_priority_enable = 32'h0000_0000;
    tx_pause_quanta_0      = 32'h0000_0000;
    tx_pause_quanta_1      = 32'h0000_0000;
    tx_pause_quanta_2      = 32'h0000_0000;
    tx_pause_quanta_3      = 32'h0000_0000;
    tx_pause_quanta_4      = 32'h0000_0000;
    tx_pause_quanta_5      = 32'h0000_0000;
    tx_pause_quanta_6      = 32'h0000_0000;
    tx_pause_quanta_7      = 32'h0000_0000;

    rx_frame_minlength     = 32'h0000_0040;  //64
    rx_frame_maxlength     = 32'h0000_05EE;  //1518
    rx_single_vlan_enable  = 32'h0000_0000;
    rx_double_vlan_enable  = 32'h0000_0000;
    rx_padcrc_control      = 32'h0000_0000;
    rx_crccheck_control    = 32'h0000_0002;
    rx_frame_control       = 32'h0000_0000;
    rx_pfc_control         = 32'h0000_0000;

  endfunction


endclass

