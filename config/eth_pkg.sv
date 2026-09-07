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
import ral_pkg::*;
import reg_agent_pkg::*;


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
`include "../env/eth_ipg_checker.sv"
`include "../env/eth_pause_checker.sv"
`include "../env/eth_pfc_checker.sv"
`include "../env/eth_env.sv"

`include "../sequences/eth_base_sequence.sv"
`include "../sequences/eth_normal_seq.sv"

`include "../sequences/eth_min_frame_seq.sv"
`include "../sequences/eth_max_frame_seq.sv"
`include "../sequences/eth_runt_frame_seq.sv"
`include "../sequences/eth_jabber_frame_seq.sv"
`include "../sequences/eth_fragment_frame_seq.sv"
`include "../sequences/eth_oversize_frame_seq.sv"

`include "../sequences/eth_unicast_frame_seq.sv"
`include "../sequences/eth_multicast_frame_seq.sv"
`include "../sequences/eth_broadcast_frame_seq.sv"

`include "../sequences/eth_single_vlan_seq.sv"
`include "../sequences/eth_double_vlan_tag_seq.sv"
`include "../sequences/eth_vlan_payload_padding_seq.sv"
`include "../sequences/eth_double_vlan_payload_padding_seq.sv"

`include "../sequences/eth_normal_payload_padding_seq.sv"
`include "../sequences/eth_len_payload_mismatch_seq.sv"

`include "../sequences/eth_control_char_data_mismatch_seq.sv"
`include "../sequences/eth_invalid_control_char_seq.sv"
`include "../sequences/eth_start_char_in_payload_seq.sv"
`include "../sequences/eth_end_char_in_payload_seq.sv"
`include "../sequences/eth_missing_terminate_seq.sv"

`include "../sequences/eth_bad_fcs_seq.sv"
`include "../sequences/eth_error_detection_seq.sv"
`include "../sequences/eth_preamble_corruption_seq.sv"

`include "../sequences/eth_pause_frame_basic_seq.sv"
`include "../sequences/eth_pause_frame_vlan_seq.sv"
`include "../sequences/eth_pause_frame_simul_seq.sv"
`include "../sequences/eth_pause_frame_updated_time_seq.sv"
`include "../sequences/eth_pause_frame_reserved_opcode_seq.sv"
`include "../sequences/eth_pfc_basic_seq.sv"
`include "../sequences/eth_pfc_rand_priority_seq.sv"
`include "../sequences/eth_pfc_simultaneous_seq.sv"
`include "../sequences/eth_pfc_back_to_back_xoff_xon_seq.sv"
`include "../sequences/eth_pfc_independent_priority_overlap_seq.sv"
`include "../sequences/eth_pfc_stress_seq.sv"
`include "../sequences/eth_pfc_multiple_stress_seq.sv"
`include "../sequences/eth_pfc_multi_priority_seq.sv"
`include "../sequences/eth_mac2_mac3_addr_cov_seq.sv"

`include "../sequences/eth_reg_seq.sv"
`include "../sequences/eth_virtual_seq.sv"
`include "../tests/eth_base_test.sv"

//*******************************************//
//             TEST CASE FILES
//*******************************************//
`include "../tests/eth_normal_frame_test.sv"
`include "../tests/eth_reg_test.sv"
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
`include "../tests/eth_double_vlan_payload_padding_test.sv"
`include "../tests/eth_len_payload_mismatch_test.sv"
`include "../tests/eth_oversize_frame_test.sv"
`include "../tests/eth_invalid_control_character_test.sv"
`include "../tests/eth_start_character_in_between_payload_err_test.sv"
`include "../tests/eth_end_character_in_between_payload_err_test.sv"
`include "../tests/eth_missing_terminate_character_test.sv"
`include "../tests/eth_pause_frame_basic_xoff_xon_test.sv"
`include "../tests/eth_simultaneous_pause_frame_test.sv"
`include "../tests/eth_pause_reserved_opcode_test.sv"
`include "../tests/eth_pause_frame_with_updated_pause_time.sv"
`include "../tests/eth_pause_frame_during_vlan_traffic_test.sv"
`include "../tests/eth_control_char_data_mismatch_test.sv"
`include "../tests/eth_pfc_frame_test.sv"
`include "../tests/eth_pfc_with_random_priority_quanta_expiry_test.sv"
`include "../tests/eth_pfc_simultaneous_operation_test.sv"
`include "../tests/eth_pfc_independent_timer_overlap_test.sv"
`include "../tests/eth_xoff_xon_back_to_back_pfc_test.sv"
`include "../tests/eth_pfc_multiple_priority_xoff_test.sv"
`include "../tests/eth_consec_multiple_same_pfc_xoff_imd_xon_test.sv"
`include "../tests/eth_consec_multiple_diff_pfc_xoff_imd_xon_test.sv"
`include "../tests/eth_local_and_remote_fault_test.sv"
`include "../tests/eth_mac2_mac3_addr_cov_test.sv"
