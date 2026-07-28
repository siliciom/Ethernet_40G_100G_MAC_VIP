//******************************************************************//
//                   ETHERNET SEQUENCE ITEM FILE
//
// Defines the Ethernet transaction object used throughout the UVM
// environment. It contains frame fields, control information,
// protocol-specific attributes, and randomization constraints required
// for Ethernet packet generation and verification.
//
// Author: Ankitha, Sanjeev
//
//******************************************************************//
class eth_seq_item extends uvm_sequence_item;

  // Declare all the required Variables/Signals
  rand bit [7:0] preamble[7];
  rand bit [7:0] sfd;
  rand bit [47:0] da;
  rand bit [47:0] sa;
  rand bit [15:0] ether_type;
  rand bit [7:0] payload[];
  bit [31:0] crc;
  rand bit [63:0] txd;
  rand bit [7:0]  txc;
  bit [63:0] rxd;
  bit [7:0]  rxc;
  
  `uvm_object_utils_begin(eth_seq_item)
  `uvm_field_int(da, UVM_ALL_ON)   // <-- DA
  `uvm_field_int(sa, UVM_ALL_ON)   // <-- SA
  `uvm_field_sarray_int(payload, UVM_ALL_ON) 
  `uvm_field_int(crc,UVM_ALL_ON)
  `uvm_field_int(ether_type,UVM_ALL_ON)
   `uvm_field_int(txd, UVM_ALL_ON)
    `uvm_field_int(txc, UVM_ALL_ON)
    `uvm_field_int(rxd, UVM_ALL_ON)
    `uvm_field_int(rxc, UVM_ALL_ON)  
  `uvm_object_utils_end
  
  // Add Required Constraints 
  constraint payload_size {payload.size() == ether_type;}
  

endclass


