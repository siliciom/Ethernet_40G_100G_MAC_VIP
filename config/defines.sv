`ifndef DEFINE_SV
`define DEFINE_SV
//******************************************************************//
//                    ETHERNET DEFINES FILE
//
// Defines common macros, protocol constants, data types, and
// utility functions used throughout the Ethernet UVM verification
// environment. This file also provides global Ethernet MAC address
// initialization routines and shared definitions for frame handling.
//
//******************************************************************//
`define NO_OF_AGENTS 2
`define DATA_WIDTH 64
`define CTRL_WIDTH 8
`define FREQ_IN_MHZ 625
`define START_CH 8'hFB
`define TERMINATE_CH 8'hFD
`define IDLE_CH 8'h07
`define ERROR_CH 8'hFE
`define PREAMBLE 8'h55
`define SFD 8'hD5
`define REMOTE_FAULT_SEQ 32'h9c_00_00_02
`define LOCAL_FAULT_SEQ 32'h9c_00_00_01
`define IDLE_BYTES 32'h07_07_07_07
`define PAUSE_PAYLOAD_SIZE 42
`define PFC_PAYLOAD_SIZE 26
`define VLAN_PAYLOAD_SIZE 42
`define DOUBLE_VLAN_PAYLOAD_SIZE 38
`define MIN_PAYLOAD_SIZE 46
`define HEADER 18
`define CRC 32
`define MAC_ADDR 48
`define RESET_PERIOD 5
`define NUM_LANES = `DATA_WIDTH / 8;
`define FAULT_PERIOD 500
`define NO_OF_PKTS 100

typedef enum {
  NORMAL_FRAME,
  VLAN_FRAME,
  DOUBLE_VLAN_FRAME,
  PAUSE_FRAME,
  PFC_FRAME
} frame_type_e;

typedef struct packed {
  time         t;
  logic [63:0] txd;
  logic [7:0]  txc;
} intf_trace_t;

// Global mac addresses functions
function automatic void mac_unicast(ref bit [47:0] mac_t[`NO_OF_AGENTS]);
  for(int i = 0; i < `NO_OF_AGENTS; i++) begin
    mac_t[i] = {8'h00,8'(8'h50 + i),8'(8'h40 + i),8'(8'h30 + i),8'(8'h20 + i),8'(8'h10 + i)};
  end
endfunction

function automatic void mac_multicast(ref bit mac_t[`NO_OF_AGENTS][bit [47:0]]);
  for(int i=0; i < `NO_OF_AGENTS; i++) begin
    if(i%2==1)
      mac_t[i][{8'h01,8'h50,8'h40,8'h30,8'h20,8'h10}] = 1;
    mac_t[i][{8'h01,8'h80,8'hc2,8'h00,8'h00,8'h01}] = 1;
  end
endfunction
`endif
