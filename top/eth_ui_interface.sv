//******************************************************************//
//                 ETHERNET UI INTERFACE FILE
//
// Defines the User Interface (UI) for Ethernet user-defined counters.
// This interface provides signals for collecting and monitoring
// protocol statistics, packet counts, error counts, event counters,
// and other user-defined verification metrics during simulation.
//
// Author: Nitheesh
//
//******************************************************************//
interface eth_ui_interface ();


  // Register access
  logic        reg_valid;
  logic        reg_write;
  logic [31:0] reg_addr;
  logic [31:0] reg_wdata;
  logic [31:0] reg_rdata;
  logic        reg_ready;
  logic        reg_error;

  // Tx Counters
  logic [31:0] tx_good_pkt_count;
  logic [31:0] tx_bad_pkt_count;
  logic [31:0] tx_unicast_count;
  logic [31:0] tx_multicast_count;
  logic [31:0] tx_broadcast_count;
  logic [31:0] tx_runt_count;
  logic [31:0] tx_drop_count;
  logic [31:0] tx_fragment_count;
  logic [31:0] tx_jumbo_count;
  logic [31:0] tx_oversized_count;
  logic [31:0] tx_jabber_count;
  logic [31:0] tx_pause_count;
  logic [31:0] tx_vlan_count;
  logic [31:0] tx_ipg_violation_count;
  logic [31:0] tx_pfc_xon_count;
  logic [31:0] tx_pfc_xoff_count;
  logic [31:0] tx_carrier_ext_count;
  logic [31:0] tx_pause_xon_count;
  logic [31:0] tx_pause_xoff_count;
  logic [31:0] tx_control_pkt_count;
  logic [31:0] tx_pfc_xon_prio0_count;
  logic [31:0] tx_pfc_xon_prio1_count;
  logic [31:0] tx_pfc_xon_prio2_count;
  logic [31:0] tx_pfc_xon_prio3_count;
  logic [31:0] tx_pfc_xon_prio4_count;
  logic [31:0] tx_pfc_xon_prio5_count;
  logic [31:0] tx_pfc_xon_prio6_count;
  logic [31:0] tx_pfc_xon_prio7_count;
  logic [31:0] tx_pfc_xoff_prio0_count;
  logic [31:0] tx_pfc_xoff_prio1_count;
  logic [31:0] tx_pfc_xoff_prio2_count;
  logic [31:0] tx_pfc_xoff_prio3_count;
  logic [31:0] tx_pfc_xoff_prio4_count;
  logic [31:0] tx_pfc_xoff_prio5_count;
  logic [31:0] tx_pfc_xoff_prio6_count;
  logic [31:0] tx_pfc_xoff_prio7_count;
  logic [31:0] tx_idle_fault_seq_cnt;
  logic [31:0] tx_remote_fault_seq_cnt;


  //Rx Counters
  logic [31:0] rx_good_pkt_count;
  logic [31:0] rx_bad_pkt_count;
  logic [31:0] rx_unicast_count;
  logic [31:0] rx_multicast_count;
  logic [31:0] rx_broadcast_count;
  logic [31:0] rx_runt_count;
  logic [31:0] rx_fragment_count;
  logic [31:0] rx_jumbo_count;
  logic [31:0] rx_oversized_count;
  logic [31:0] rx_jabber_count;
  logic [31:0] rx_pause_count;
  logic [31:0] rx_vlan_count;
  logic [31:0] rx_drop_count;
  logic [31:0] rx_ipg_violation_count;
  logic [31:0] rx_pfc_xon_count;
  logic [31:0] rx_pfc_xoff_count;
  logic [31:0] rx_carrier_ext_count;
  logic [31:0] rx_pause_xon_count;
  logic [31:0] rx_pause_xoff_count;
  logic [31:0] rx_control_pkt_count;
  logic [31:0] rx_pfc_xon_prio0_count;
  logic [31:0] rx_pfc_xon_prio1_count;
  logic [31:0] rx_pfc_xon_prio2_count;
  logic [31:0] rx_pfc_xon_prio3_count;
  logic [31:0] rx_pfc_xon_prio4_count;
  logic [31:0] rx_pfc_xon_prio5_count;
  logic [31:0] rx_pfc_xon_prio6_count;
  logic [31:0] rx_pfc_xon_prio7_count;
  logic [31:0] rx_pfc_xoff_prio0_count;
  logic [31:0] rx_pfc_xoff_prio1_count;
  logic [31:0] rx_pfc_xoff_prio2_count;
  logic [31:0] rx_pfc_xoff_prio3_count;
  logic [31:0] rx_pfc_xoff_prio4_count;
  logic [31:0] rx_pfc_xoff_prio5_count;
  logic [31:0] rx_pfc_xoff_prio6_count;
  logic [31:0] rx_pfc_xoff_prio7_count;
  logic [31:0] rx_idle_fault_seq_cnt;
  logic [31:0] rx_remote_fault_seq_cnt;

endinterface




