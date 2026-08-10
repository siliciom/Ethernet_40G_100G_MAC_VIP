//******************************************************************//
//                   ETHERNET SEQUENCE ITEM FILE
//
// Defines the Ethernet transaction object used throughout the UVM
// environment. It contains frame fields, control information,
// protocol-specific attributes, and randomization constraints required
// for Ethernet packet generation and verification.
// TODO -: Extend the sequence item to support all Ethernet control frame
//         transactions (Pause, PFC, and Fault Sequences).
// Author: Dheeraj
//
//******************************************************************//
class eth_seq_item extends uvm_sequence_item;
 
  // Ethernet frame fields
  rand bit [7:0] preamble[7];
  rand bit [7:0] sfd;
  rand bit [47:0] da;
  rand bit [47:0] sa;
  rand bit [15:0] ether_type;
  rand bit [7:0] payload[];
  bit [31:0] crc;
  // Pause frame fields
  bit pause_frame_en;
  bit [15:0] pause_opc;
  bit [15:0] pause_time;
  bit [31:0]crc_residue;
 
  // Priority Flow Control (PFC) fields
  bit pfc_frame_en;
  bit [15:0] priority_en_vector; 
  bit [15:0] pfc_pause_time[8];  
 
  // MAC address information
  bit [47:0] mac_addr[`NO_OF_AGENTS];
  bit multi_mac_addr[`NO_OF_AGENTS][bit [47:0]];
  bit [47:0] agt_addr;
  
  frame_type_e frame_type;
  int tx_count;
  int rx_count;
  bit crc_ok;
  bit padding_en;
  bit err_b;
  bit runt_en;
  bit jabber_en;
  int err_offset;
 
  //VLAN Fields
  bit vlan_en;
  bit [2:0] PCP;
  bit DEI;
  bit [11:0] VID;
  bit [15:0] TPID;
  rand bit [15:0] tpid;              // outer VLAN tag(0X8100)
  rand bit [15:0] tpid2;             // inner VLAN tag(0x88A8)
  rand bit double_vlan_enable;

  //double vlan
  bit         outer_vlan_en;   
  bit [15:0]  outer_TPID;     
  bit [2:0]   outer_PCP;
  bit         outer_DEI;
  bit [11:0]  outer_VID;

  bit invalid;
  bit jumbo_en;;

  //error_fields
  bit corrupt_fcs_en;
  bit bad_preamble_en;
  bit start_char;
  bit end_char;
  bit data_txc_error;
  int start_offset;
  int end_offset;
  int data_txc_offset;
  bit missing_terminate;
 
  //tracker
  intf_trace_t tx_trace_q[$]; 

  //------------------------------------------------------------------------------
  // Constructor
  // Initializes the transaction and assigns default MAC addresses.
  //------------------------------------------------------------------------------
  function new(string name = "transaction");
    super.new(name);
    // Initializing unique mac addresses for each mac
     for (int i = 0; i < `NO_OF_AGENTS; i++)
      mac_addr[i] = {8'h00,8'(8'h50 + i),8'(8'h40 + i),8'(8'h30 + i),8'(8'h20 + i),8'(8'h10 + i)};    
      mac_multicast(multi_mac_addr);
  endfunction
 
  //------------------------------------------------------------------------------
  // Calculates the Ethernet CRC-32 value for one byte of data.
  //------------------------------------------------------------------------------
  function bit [31:0] crc_32 (bit [31:0] crc, bit[7:0] data);
    crc = crc^data;
    for (int i=0; i<8; i++) begin
      if(crc[0])
        crc = (crc>>1) ^ 32'hEDB88320;
      else
        crc = crc>>1;
    end
    return crc; 
  endfunction

  // Register transaction fields with the UVM factory and automation macros.
  `uvm_object_utils_begin(eth_seq_item)
  `uvm_field_int(da, UVM_ALL_ON)   // <-- DA
  `uvm_field_int(sa, UVM_ALL_ON)   // <-- SA
  `uvm_field_sarray_int(payload, UVM_ALL_ON) 
  `uvm_field_int(crc,UVM_ALL_ON)
  `uvm_field_int(ether_type,UVM_ALL_ON)  
  `uvm_object_utils_end

  // Default Ethernet frame constraints
  constraint preamble_value {foreach(preamble[i]) preamble[i]==8'h55;}
  constraint sfd_value {sfd == 8'hd5;}
  constraint ether_type_value { soft ether_type inside {[46:1500]};}
  constraint addr {da inside {mac_addr};};
  constraint payload_size {payload.size() == ether_type;}
  constraint sa_da_not_match {da != sa;}
endclass

