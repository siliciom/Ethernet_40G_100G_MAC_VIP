//******************************************************************//
//                     ETHERNET PACKAGE FILE
//
// Contains all common Ethernet definitions including classes,
// typedefs, parameters, enumerations, macros, utility functions, and
// package imports required by the Ethernet UVM verification
// environment.
// TODO:- Need to include the files of pause and pfc checker
//
// Author: Sanjeev
//
//******************************************************************//
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "defines.sv"
  `include "statistics.sv"
  
  `include "../sequences/eth_seq_item.sv"
  `include "../config/tracker.sv"
  

  `include "../tests/eth_callback.sv"
  `include "../env/eth_cnfg.sv"
  `include "../agents/eth_mon.sv"
  `include "../agents/eth_drv.sv"
  `include "../agents/eth_seqr.sv"
  `include "../agents/eth_agnt.sv"

  `include "../env/eth_virtual_seqr.sv"
  `include "../env/eth_sbscr.sv"
  `include "../env/eth_scb.sv"
  `include "../env/eth_env.sv"

  `include "../sequences/eth_sequence.sv"
  `include "../sequences/eth_virtual_seq.sv"
  `include "../tests/eth_base_test.sv"

//*******************************************//
//             TEST CASE FILES
//*******************************************//
   `include "../tests/eth_normal_frame_test.sv"
   `include "../tests/eth_min_size_frame_test.sv"
   `include "../tests/eth_max_size_frame_test.sv"
   `include "../tests/eth_error_detection_test.sv"
   `include "../tests/eth_bad_fcs_test.sv"
   `include "../tests/eth_normal_payload_padding_test.sv"
   `include "../tests/eth_single_vlan_tag_frame_test.sv"
   `include "../tests/eth_vlan_payload_padding_test.sv"
   `include "../tests/eth_runt_frame_test.sv"
   `include "../tests/eth_fragment_frame_test.sv"
   `include "../tests/eth_jabber_frame_test.sv"
   `include "../tests/eth_multicast_frame_test.sv"
   `include "../tests/eth_preamble_corruption_test.sv"
   `include "../tests/eth_double_vlan_tag_frame_test.sv"
   `include "../tests/eth_unicast_frame_test.sv"
   `include "../tests/eth_broadcast_frame_test.sv"
