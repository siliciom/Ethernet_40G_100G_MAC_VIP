//******************************************************************//
//                     ETHERNET DEFINES FILE
//
// Contains common macro definitions, protocol constants, utility macros,
// and fixing agent address used throughout the Ethernet UVM verification 
// environment.
//
//******************************************************************//
`define NO_OF_AGENTS 2
`define DATA_WIDTH 64
`define CTRL_WIDTH 8
`define NO_OF_PACKETS 10
`define RESET_PERIOD 5
`define FREQ_IN_MHZ 156.25

  //**************************************************************//
  // This function creates the address for each MAC agent.
  // i.e: 00_50_40_30_20_10 (mac_0), 00_51_41_31_21_11 (mac_1) etc.,
  //**************************************************************//
  function automatic void mac_unicast(ref bit [47:0] mac_t[`NO_OF_AGENTS]);
    for(int i = 0; i < `NO_OF_AGENTS; i++) begin
        mac_t[i] = {8'h00,8'(8'h50 + i),8'(8'h40 + i),8'(8'h30 + i),8'(8'h20 + i),8'(8'h10 + i)};
    end
  endfunction
  
  //**************************************************************//
  // This function groups the MAC agents for multicast.
  // It groups odd numbered agents as one group and even as
  // another group.
  //**************************************************************//
  function automatic void mac_multicast(ref bit mac_t[`NO_OF_AGENTS][bit [47:0]]);
    for(int i=0; i < `NO_OF_AGENTS; i++) begin
        if(i%2==1)
            mac_t[i][{8'h01,8'h50,8'h40,8'h30,8'h20,8'h10}] = 1;
  
        mac_t[i][{8'h01,8'h80,8'hc2,8'h00,8'h00,8'h01}] = 1;
    end
  endfunction
