//******************************************************************//
//                    ETHERNET INTERFACE FILE
//
// Defines the SystemVerilog interface representing the Ethernet
// physical interface signals. It provides the signal connectivity 
// between the DUT and UVM components through virtual interface handles.
//
// Author: Dheeraj, Lavanya
//
//******************************************************************//
`include "../config/defines.sv"
`timescale 1ns/1ps
interface eth_interface (input bit rst);

  // Transmit path
    logic [`DATA_WIDTH-1:0] TXD;
    logic [`CTRL_WIDTH-1:0] TXC;
    logic       TX_CLK;

    // Receive path
    logic [`DATA_WIDTH-1:0] RXD;
    logic [`CTRL_WIDTH-1:0] RXC;
    logic       RX_CLK;
  //========================================================
  // Clocking block for driver
  //========================================================
  clocking drv_cb @(posedge TX_CLK);
    default input #1 output #0;
    output TXD;
    output TXC;
  endclocking

  //========================================================
  // Clocking block for monitor
  //========================================================
  clocking tx_mon_cb @(negedge TX_CLK);
   // default input #1 output #0;
    input TXD;
    input TXC;
  endclocking

  //========================================================
  // Clocking block for monitor
  //========================================================
  clocking rx_mon_cb @(negedge RX_CLK);
    //default input #1 output #0;
    input RXD;
    input RXC;
  endclocking
  //========================================================
  // Modports
  //========================================================

  // For UVM driver
  modport DRV_MP (
    clocking drv_cb);
  

  // For UVM monitor
  modport TX_MON_MP (
    clocking tx_mon_cb);
  modport RX_MON_MP (
    clocking rx_mon_cb);
  

endinterface
      
