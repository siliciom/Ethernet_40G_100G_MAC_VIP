//******************************************************************//
//                      ETHERNET TOP FILE
//
// Top-level module of the Ethernet verification environment. It
// instantiates the DUT, Ethernet interfaces, clock and reset
// generation logic, and connects the UVM testbench components.
// This file initializes the simulation environment and starts the
// execution of Ethernet UVM test cases using `run_test()`.
// TODO:- Need to add logic for interconnect connection between MAC's
//
// Author: Dheeraj, Lavanya
//
//******************************************************************//
import uvm_pkg::*;
`include "uvm_macros.svh"
`include "../config/eth_pkg.sv"

module eth_top;
  bit clk;
  bit rst;
   
  // Intermediate Signals---------------------------------------
  logic [`DATA_WIDTH-1:0] txd   [`NO_OF_AGENTS];
  logic [`CTRL_WIDTH-1:0] txc   [`NO_OF_AGENTS];
  logic [`DATA_WIDTH-1:0] rxd   [`NO_OF_AGENTS];
  logic [`CTRL_WIDTH-1:0] rxc   [`NO_OF_AGENTS];
   
  //----------------------------------------------------------

  // Converting frequency from MHz to ns
  parameter real HALF_PERIOD = 1000 / (2 * `FREQ_IN_MHZ);
  
  eth_interface eth_if[`NO_OF_AGENTS](rst);
  eth_ui_interface user_if[`NO_OF_AGENTS]();

  // Seting  Intf to Config_db
  genvar i;
  generate
    for (i = 0; i < `NO_OF_AGENTS; i++) begin : gen_config
      initial begin
        uvm_config_db#(virtual eth_interface)::set(
          null,
          $sformatf("uvm_test_top.env_h.agnt_mac[%0d]*", i),
          "vif",
          eth_if[i]
        );
        
      end
      assign eth_if[i].TX_CLK = clk; 
      assign eth_if[i].RX_CLK = clk;
    end
  endgenerate

    // Seting  user_Intf to Config_db
  genvar j;
  generate
    for (j = 0; j < `NO_OF_AGENTS; j++) begin : user_int
      initial begin
        uvm_config_db#(virtual eth_ui_interface)::set(
          null,
          $sformatf("uvm_test_top.env_h.agnt_mac[%0d]*", j),
          "u_vif",
          user_if[j]
        );
        
      end
    end


  endgenerate
  
  // connecting intermediate variables with xlgmii Signals  
  assign eth_if[1].RXC = eth_if[0].TXC; 
  assign eth_if[1].RXD = eth_if[0].TXD; 
  
  assign eth_if[0].RXC = eth_if[1].TXC; 
  assign eth_if[0].RXD = eth_if[1].TXD; 
  

  // Clock Generation 
  initial begin
    clk = 0;
    forever #(HALF_PERIOD) clk = ~clk; 
  end
   
  // Initializing the reset
  initial begin
    rst = 0;
    repeat (`RESET_PERIOD) @(posedge clk);
    rst = 1;
  end
  
  // Starting the test  
  initial begin
    run_test("");
  end
  
  
endmodule
