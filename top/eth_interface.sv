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
    output TXD;
    output TXC;
    input RXD;
    input RXC;
  endclocking

  //========================================================
  // Clocking block for monitor
  //========================================================
  clocking mon_cb @(negedge TX_CLK);
    input TXD;
    input TXC;
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
  modport MON_MP (
    clocking mon_cb);
  

endinterface
      
