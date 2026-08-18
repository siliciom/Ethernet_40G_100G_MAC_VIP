//******************************************************************//
//                    ETHERNET SCOREBOARD FILE
//
// Implements the Ethernet UVM scoreboard. The scoreboard compares
// expected and observed Ethernet transactions, verifies protocol
// correctness, checks frame integrity, and reports functional
// mismatches and data inconsistencies.
// TODO:- Need to update the comparision for pause and pfc.
//
// Author: Arun
//
//******************************************************************//
`uvm_analysis_imp_decl(_ap_1)
`uvm_analysis_imp_decl(_ap_2)

class eth_scb extends uvm_scoreboard;
  `uvm_component_utils(eth_scb);
  uvm_analysis_imp_ap_1#(eth_seq_item, eth_scb) ai_1[`NO_OF_AGENTS];    
  uvm_analysis_imp_ap_2#(eth_seq_item, eth_scb) ai_2[`NO_OF_AGENTS];  
  eth_seq_item tx_tr;
  eth_seq_item rx_tr;

  // TX ARRAY [source_agent_id][destination_agent_id][transaction_number]
  eth_seq_item tx_aa[int][int][int];

  // RX ARRAY [source_agent_id][destination_agent_id][transaction_number]
  eth_seq_item rx_aa[int][int][int];
  int matched_pkt_count = 0;
  bit mac_addr_arr[bit[47:0]];
  bit k;

  function new(string name = "eth_scb", uvm_component parent = null);
    super.new(name,parent);
    // Creating memory for tlm analysis imp ports
    foreach(ai_1[i])
      ai_1[i]=new($sformatf ("ai_1[%0d]",i),this);
    foreach(ai_2[i])
      ai_2[i]=new($sformatf ("ai_2[%0d]",i),this);
  endfunction   

  function void build_phase(uvm_phase phase);
    super.build_phase(phase); 
  endfunction  

  //----------------------------------------------------------------------
  // Receives transmitted Ethernet packets from the monitor.
  // Decodes the source and destination information and stores
  // transactions for future comparison with received packets.
  //----------------------------------------------------------------------
  function void write_ap_1(eth_seq_item tx_tr);
    int src_id;
    int dst_id;
    int txn_no;

    src_id = source_address(tx_tr);
    if(!(mac_addr_arr.exists(tx_tr.sa)))
      mac_addr_arr[tx_tr.sa] = 1;
    txn_no = tx_tr.tx_count;
    if(is_broadcast_addr(tx_tr.da)) begin
      foreach(ai_2[i]) begin
	// source should not receive own broadcast
        if(i == src_id)
          continue;
        tx_aa[src_id][i][txn_no] = tx_tr;
        `uvm_info("SCB_BROADCAST_TX", $sformatf( "Stored BROADCAST TX : TX_MAC[%0d] --> RX_MAC[%0d] | TX_NO=%0d", src_id, i, txn_no), UVM_LOW)
      end
      return;
    end
    if(is_multicast_addr(tx_tr)) begin
      foreach(ai_2[i]) begin
        if(i==src_id)
          continue;
        if(tx_tr.multi_mac_addr[i].exists(tx_tr.da)) begin
          tx_aa[src_id][i][txn_no] = tx_tr;
          `uvm_info("SCB_MULTICAST_TX", $sformatf( "Stored MULTICAST TX : TX_MAC[%0d] --> RX_MAC[%0d] | TX_NO=%0d", src_id, i, txn_no), UVM_LOW)
        end
      end
      return;
    end
    dst_id = destination_address(tx_tr);

    // Store TX transaction
    tx_aa[src_id][dst_id][txn_no] = tx_tr;
    `uvm_info("SCB_TX", $sformatf( "Stored TX Packet : TX_MAC[%0d] --> RX_MAC[%0d] | TX_NO=%0d ", src_id, dst_id, txn_no), UVM_LOW)
  endfunction

  //----------------------------------------------------------------------
  // Determines whether the received transaction is marked as
  // an erroneous packet and should not be considered as a
  // valid frame for comparison.
  //----------------------------------------------------------------------
  function bit is_error_pkt(eth_seq_item tr);
    if(tr.err_b)
      return 1;
    return 0;
  endfunction

  //----------------------------------------------------------------------
  // Checks whether the destination MAC address corresponds
  // to the Ethernet broadcast address (FF:FF:FF:FF:FF:FF).
  // Returns 1 for broadcast packets.
  //----------------------------------------------------------------------
  function bit is_broadcast_addr(bit [47:0] da);
    return (da == 48'hFFFF_FFFF_FFFF);
  endfunction

  //----------------------------------------------------------------------
  // Determines whether the destination address belongs to
  // any configured multicast group.
  // Returns 1 if the packet is identified as multicast.
  //----------------------------------------------------------------------
  function bit is_multicast_addr(eth_seq_item tr);
    foreach(tr.multi_mac_addr[i]) begin
      if(tr.multi_mac_addr[i].exists(tr.da))
        return 1;
    end
    return 0;
  endfunction

  //----------------------------------------------------------------------
  // Receives Ethernet packets from the RX monitor.
  // Identifies the corresponding transmitted packet,
  // validates packet status, and initiates comparison.
  //----------------------------------------------------------------------
  function void write_ap_2(eth_seq_item rx_tr);
    int src_id;
    int dst_id;
    int txn_no;
    
    // Decode SOURCE (SA → src_id)
    src_id = source_address(rx_tr);
    txn_no = rx_tr.rx_count;
    
    // BROADCAST CASE
    if(is_broadcast_addr(rx_tr.da)) begin
      dst_id = broad_cast(rx_tr);
    end
    else if(is_multicast_addr(rx_tr)) begin
      dst_id = multi_cast(rx_tr);
    end
    else // UNICAST CASE
      dst_id = destination_address(rx_tr);
    
    // TX existence check
    if(!tx_aa.exists(src_id) || !tx_aa[src_id].exists(dst_id) || !tx_aa[src_id][dst_id].exists(txn_no)) begin
      `uvm_error("SCB_EXTRA_RX", $sformatf( "RX received but matching TX not found : TX_MAC[%0d] --> RX_MAC[%0d] | TX_NO=%0d", src_id, dst_id, txn_no))
	rx_aa[src_id][dst_id][txn_no] = rx_tr;
      return;
    end

    // BAD PACKET HANDLING
    if(is_error_pkt( tx_aa[src_id][dst_id][txn_no])) begin
      `uvm_error("SCB_BAD_PKT", $sformatf("Bad packet reached RX | TX_MAC[%0d]->RX_MAC[%0d] TX_NO=%0d", src_id, dst_id, txn_no))
      rx_aa[src_id][dst_id][txn_no] = rx_tr;
      return;
    end

    // GOOD PACKET → COMPARE
    compare_packet( src_id, dst_id, txn_no, rx_tr.rx_count, tx_aa[src_id][dst_id][txn_no], rx_tr);
    // DELETE TX AFTER SUCCESS
    tx_aa[src_id][dst_id].delete(txn_no);
  endfunction

  //----------------------------------------------------------------------
  // Executes at the end of simulation to verify that all
  // expected packets have been matched. Reports missing,
  // dropped, or unmatched packets.
  //----------------------------------------------------------------------
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    foreach(tx_aa[src_id]) begin
      foreach(tx_aa[src_id][dst_id]) begin
        foreach(tx_aa[src_id][dst_id][txn_no]) begin
          if(is_error_pkt(tx_aa[src_id][dst_id][txn_no])) begin // BAD PACKET
            `uvm_info("SCB_BAD_PKT_PASS",
               $sformatf({
               "\n========================================================",
               "\nPASS : Bad Packet Correctly Dropped",
               "\n--------------------------------------------------------",
               "\nTX_MAC          : %0d",
               "\nRX_MAC          : %0d",
               "\nTRANSACTION     : %0d",
               "\nDA              : %012h",
               "\nSA              : %012h",
               "\n========================================================"
               }, src_id, dst_id, txn_no, tx_aa[src_id][dst_id][txn_no].da, tx_aa[src_id][dst_id][txn_no].sa), UVM_LOW)
            tx_aa[src_id][dst_id].delete(txn_no); // delete only bad packet
          end
          else begin // GOOD PACKET
            `uvm_error("SCB_MISSING_RX",
               $sformatf({
               "\n========================================================",
               "\nFAIL : Good Packet Missing At RX",
               "\n--------------------------------------------------------",
               "\nTX_MAC          : %0d",
               "\nRX_MAC          : %0d",
               "\nTRANSACTION     : %0d",
               "\nDA              : %012h",
               "\nSA              : %012h",
               "\n========================================================"
               }, src_id, dst_id, txn_no, tx_aa[src_id][dst_id][txn_no].da, tx_aa[src_id][dst_id][txn_no].sa))// keep the good packet for debugging purpose
          end
        end
      end
    end
  endfunction

  //----------------------------------------------------------------------
  // Generates the final scoreboard summary after simulation.
  // Reports packet comparison statistics, unmatched packets,
  // and overall PASS/FAIL status.
  //----------------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    string test_name;
    string agent_status;
    int tx_left;
    int rx_left;
    int tx_pkt_left;
    int rx_pkt_left;
    super.report_phase(phase);
    
    if(`NO_OF_AGENTS == 2) begin
      for(int i = 0; i < `NO_OF_AGENTS; i++)
	compare_counters(i);
    end
    // Get testcase name
    if (!$value$plusargs("UVM_TESTNAME=%s", test_name))
      test_name = "UNKNOWN_TEST";

    // TX Status
    agent_status = "";
    tx_left = 0;
    rx_left = 0;
    for (int i = 0; i < `NO_OF_AGENTS; i++) begin
      tx_pkt_left = 0;
      if (tx_aa.exists(i)) begin
        foreach (tx_aa[i][dst])
          tx_pkt_left += tx_aa[i][dst].num();
      end
      tx_left += tx_pkt_left;
      agent_status = {agent_status, $sformatf("\n tx_array[%0d] : packets_left = %0d", i, tx_pkt_left)};
    end

    // RX Status
    for (int i = 0; i < `NO_OF_AGENTS; i++) begin
      rx_pkt_left = 0;
      if (rx_aa.exists(i)) begin
        foreach (rx_aa[i][dst])
          rx_pkt_left += rx_aa[i][dst].num();
      end
      rx_left += rx_pkt_left;
      agent_status = {agent_status, $sformatf("\n rx_array[%0d] : packets_left = %0d", i, rx_pkt_left)};
    end

    // PASS REPORT
    if ((tx_left == 0) && (rx_left == 0)) begin
      `uvm_info("SCB_REPORT",
        $sformatf({
          "\n============================================================",
          "\n                  ETH SCOREBOARD REPORT",
          "\n============================================================",
          "\n TESTCASE         : %s",
          "\n PACKETS COMPARED : %0d",
          "\n",
          "\n MAC STATUS",
          "\n -----------------------------------------------------------",
          "%s",
          "\n -----------------------------------------------------------",
          "\n TOTAL TX PACKETS LEFT    : %0d",
          "\n TOTAL RX PACKETS LEFT    : %0d",
          "\n",
          "\n FINAL RESULT     : PASS",
          "\n============================================================"
        },
        test_name, matched_pkt_count, agent_status, tx_left, rx_left), UVM_NONE)
    end
    else begin
      `uvm_error("SCB_REPORT",
        $sformatf({
          "\n============================================================",
          "\n                  ETH SCOREBOARD REPORT",
          "\n============================================================",
          "\n TESTCASE         : %s",
          "\n PACKETS COMPARED : %0d",
          "\n",
          "\n MAC STATUS",
          "\n -----------------------------------------------------------",
          "%s",
          "\n -----------------------------------------------------------",
          "\n TOTAL TX PACKETS LEFT    : %0d",
          "\n TOTAL RX PACKETS LEFT    : %0d",
          "\n",
          "\n FINAL RESULT     : FAIL",
          "\n REASON           : %0d TX and %0d RX packets remain unmatched",
          "\n============================================================"
        },
        test_name, matched_pkt_count, agent_status, tx_left, rx_left, tx_left, rx_left))
    end
  endfunction

  //----------------------------------------------------------------------
  // Compares all relevant fields between transmitted and
  // received Ethernet packets. Reports field mismatches and
  // updates the successful comparison count.
  //----------------------------------------------------------------------
function void compare_packet(
    int tx_id,
    int rx_id,
    int tx_no,
    int rx_no,
    eth_seq_item tx_tr,
    eth_seq_item rx_tr);
 
    bit pass = 1;
 
    // --- Destination & Source MAC Comparison ---
    if (tx_tr.da !== rx_tr.da) begin
      `uvm_error("SCB_DA", $sformatf("DA mismatch: TX=%012h RX=%012h", tx_tr.da, rx_tr.da))
      pass = 0;
    end
 
    if (tx_tr.sa !== rx_tr.sa) begin
      `uvm_error("SCB_SA", $sformatf("SA mismatch: TX=%012h RX=%012h", tx_tr.sa, rx_tr.sa))
      pass = 0;
    end
 
    // --- EtherType Comparison ---
    if (tx_tr.ether_type !== rx_tr.ether_type) begin
      `uvm_error("SCB_ETHERTYPE", $sformatf("EtherType mismatch: TX=%04h RX=%04h", tx_tr.ether_type, rx_tr.ether_type))
      pass = 0;
    end
 
    // --- Payload Comparison ---
    if (tx_tr.payload.size() != rx_tr.payload.size()) begin
      `uvm_error("SCB_PAYLOAD_SIZE", $sformatf("Payload size mismatch: TX=%0d RX=%0d", tx_tr.payload.size(), rx_tr.payload.size()))
      pass = 0;
    end
    else begin
      foreach (tx_tr.payload[i]) begin
        if (tx_tr.payload[i] !== rx_tr.payload[i]) begin
          `uvm_error("SCB_PAYLOAD", $sformatf("Payload mismatch byte[%0d]: TX=%0h RX=%0h", i, tx_tr.payload[i], rx_tr.payload[i]))
          pass = 0;
        end
      end
    end
 
    // --- Outer VLAN Field Comparisons ---
    if (tx_tr.outer_vlan_en == 1) begin
      if (tx_tr.outer_TPID !== rx_tr.outer_TPID) begin
        `uvm_error("SCB_OUTER_TPID", $sformatf("Outer TPID mismatch: TX=%04h RX=%04h", tx_tr.outer_TPID, rx_tr.outer_TPID))
        pass = 0;
      end
      if (tx_tr.outer_PCP !== rx_tr.outer_PCP) begin
        `uvm_error("SCB_OUTER_PCP", $sformatf("Outer PCP mismatch: TX=%0d RX=%0d", tx_tr.outer_PCP, rx_tr.outer_PCP))
        pass = 0;
      end
      if (tx_tr.outer_DEI !== rx_tr.outer_DEI) begin
        `uvm_error("SCB_OUTER_DEI", $sformatf("Outer DEI mismatch: TX=%0b RX=%0b", tx_tr.outer_DEI, rx_tr.outer_DEI))
        pass = 0;
      end
      if (tx_tr.outer_VID !== rx_tr.outer_VID) begin
        `uvm_error("SCB_OUTER_VID", $sformatf("Outer VID mismatch: TX=%0d RX=%0d", tx_tr.outer_VID, rx_tr.outer_VID))
        pass = 0;
      end 
    end
 
    // --- Inner VLAN Field Comparisons ---
    if (tx_tr.vlan_en) begin
      if (tx_tr.TPID !== rx_tr.TPID) begin
        `uvm_error("SCB_TPID", $sformatf("TPID mismatch: TX=%04h RX=%04h", tx_tr.TPID, rx_tr.TPID))
        pass = 0;
      end
      if (tx_tr.PCP !== rx_tr.PCP) begin
        `uvm_error("SCB_PCP", $sformatf("PCP mismatch: TX=%0d RX=%0d", tx_tr.PCP, rx_tr.PCP))
        pass = 0;
      end
      if (tx_tr.DEI !== rx_tr.DEI) begin
        `uvm_error("SCB_DEI", $sformatf("DEI mismatch: TX=%0b RX=%0b", tx_tr.DEI, rx_tr.DEI))
        pass = 0;
      end
      if (tx_tr.VID !== rx_tr.VID) begin
        `uvm_error("SCB_VID", $sformatf("VID mismatch: TX=%0d RX=%0d", tx_tr.VID, rx_tr.VID))
        pass = 0;
      end        
    end
 
    // --- Final Reporting Block ---
    if (pass) begin
      matched_pkt_count++;
      `uvm_info("SCB_TRANS_NUM", $sformatf("\nTX_TRANSACTION_NO = %0d\nRX_TRANSACTION_NO = %0d", tx_no, rx_no), UVM_LOW)
 
      `uvm_info("SCB_COMPARE",
        $sformatf({
          "\n==============================================================================",
          "\n%-18s : %-18s | %-18s : %-18s",
          "\n==============================================================================",
          "\n%-18s : %-18d | %-18s : %-18d",
          "\n%-18s : %012h       | %-18s : %012h",
          "\n%-18s : %012h       | %-18s : %012h",
          "\n%-18s : %04h         | %-18s : %04h",
          "\n%-18s : %-18d | %-18s : %-18d",
          "\n%-18s : %08h       | %-18s : %08h",
          "\n=============================================================================="
        },
        "EXPECTED (TX)", "", "ACTUAL (RX)", "",
        "TX_AGENT", tx_id, "RX_AGENT", rx_id,
        "DA", tx_tr.da, "DA", rx_tr.da,
        "SA", tx_tr.sa, "SA", rx_tr.sa,
        "ETHER_TYPE", tx_tr.ether_type, "ETHER_TYPE", rx_tr.ether_type,
        "PAYLOAD_SIZE", tx_tr.payload.size(), "PAYLOAD_SIZE", rx_tr.payload.size(),
        "CRC", tx_tr.crc, "CRC", rx_tr.crc
        ), UVM_LOW)   
 
      // Print Inner VLAN info if enabled
      if (tx_tr.vlan_en) begin
        `uvm_info("SCB_VLAN_INFO",
          $sformatf({
            "\n================ VLAN INFO ================",
            "\nTX_TPID    : %04h  | RX_TPID    : %04h",
            "\nTX_PCP     : %0d   | RX_PCP     : %0d",
            "\nTX_DEI     : %0b   | RX_DEI     : %0b",
            "\nTX_VID     : %0d   | RX_VID     : %0d",
            "\n==========================================="
          }, tx_tr.TPID, rx_tr.TPID, tx_tr.PCP, rx_tr.PCP, tx_tr.DEI, rx_tr.DEI, tx_tr.VID, rx_tr.VID), UVM_LOW)
      end
 
      // Print Outer VLAN info if enabled
      if (tx_tr.outer_vlan_en) begin
        `uvm_info("SCB_OUTER_VLAN_INFO",
          $sformatf({
            "\n================ OUTER VLAN INFO ================",
            "\nTX_OUTER_TPID    : %04h | RX_OUTER_TPID    : %04h",
            "\nTX_OUTER_PCP     : %0d    | RX_OUTER_PCP     : %0d",
            "\nTX_OUTER_DEI     : %0b    | RX_OUTER_DEI     : %0b",
            "\nTX_OUTER_VID     : %0h    | RX_OUTER_VID     : %0h",
            "\n================================================="
          }, 
          tx_tr.outer_TPID, rx_tr.outer_TPID, 
          tx_tr.outer_PCP,  rx_tr.outer_PCP, 
          tx_tr.outer_DEI,  rx_tr.outer_DEI, 
          tx_tr.outer_VID,  rx_tr.outer_VID
          ), UVM_LOW)
      end
 
      `uvm_info("SCB_RX_COUNT", $sformatf("RX packet count received in SB = %0d", rx_tr.rx_count), UVM_LOW)
    end
    else begin
      `uvm_error("SCB_FAIL", $sformatf("Packet mismatch: TX agent[%0d] (Pkt #%0d) -> RX agent[%0d] (Pkt #%0d)", tx_id, tx_no, rx_id, rx_no))
    end
 
  endfunction

  //----------------------------------------------------------------------
  // Determines the source Ethernet agent by matching the
  // source MAC address with the configured MAC addresses.
  // Returns the corresponding source agent index.
  //----------------------------------------------------------------------
  function int source_address(eth_seq_item tx_tr);
    for(int i = 0; i < `NO_OF_AGENTS; i++) begin
      if(tx_tr.sa == tx_tr.mac_addr[i])
        return i;
    end
    `uvm_error("SB_INVALID_SA", $sformatf( "Invalid Source Address Detected : SA=%012h", tx_tr.sa))
     return -1;
  endfunction

  //----------------------------------------------------------------------
  // Determines the destination Ethernet agent by matching
  // the destination MAC address with the configured MAC
  // address table.
  //----------------------------------------------------------------------
  function int destination_address(eth_seq_item tx_tr);
    for(int i = 0; i < `NO_OF_AGENTS; i++) begin
      if(tx_tr.da == tx_tr.mac_addr[i])
        return i;
    end
    `uvm_error("SB_INVALID_DA", $sformatf( "Invalid Destination Address Detected : DA=%012h", tx_tr.da))
    return -1;
  endfunction

  //----------------------------------------------------------------------
  // Identifies the receiving agent for a broadcast packet
  // based on the current agent MAC address.
  // Returns the destination agent index.
  //----------------------------------------------------------------------
  function int broad_cast(eth_seq_item rx_tr);
    for(int i = 0; i < `NO_OF_AGENTS; i++) begin
      if(rx_tr.agt_addr == rx_tr.mac_addr[i])
        return i;
    end
  endfunction

  //----------------------------------------------------------------------
  // Identifies the receiving agent for a multicast packet
  // by checking multicast group membership.
  // Returns the matching destination agent index.
  //----------------------------------------------------------------------
  function int multi_cast(eth_seq_item rx_tr);
    for(int i=0; i<`NO_OF_AGENTS; i++) begin
      if(rx_tr.mac_addr[i]==rx_tr.agt_addr && rx_tr.multi_mac_addr[i].exists(rx_tr.da))
        return i;
    end
  endfunction
 
  function void compare_counters(int i);
    bit [47:0] mac0_addr;
    bit [47:0] mac1_addr;
    bit j;
    bit [47:0] index;
  
    j = ~(bit'(i));
    mac_addr_arr.first(index);
    mac0_addr = index;
    mac_addr_arr.last(index);  
    mac1_addr = index;

    `COMPARE_COUNTER(tx_good_pkt_pending,        rx_good_pkt_pending,        "GOOD_PKT")
    `COMPARE_COUNTER(tx_bad_pkt_pending,         rx_bad_pkt_pending,         "BAD_PKT")
    `COMPARE_COUNTER(tx_unicast_pending,         rx_unicast_pending,         "UNICAST")
    `COMPARE_COUNTER(tx_multicast_pending,       rx_multicast_pending,       "MULTICAST")
    `COMPARE_COUNTER(tx_broadcast_pending,       rx_broadcast_pending,       "BROADCAST")
    `COMPARE_COUNTER(tx_runt_pending,            rx_runt_pending,            "RUNT")
    `COMPARE_COUNTER(tx_fragment_pending,        rx_fragment_pending,        "FRAGMENT")
    `COMPARE_COUNTER(tx_jumbo_pending,           rx_jumbo_pending,           "JUMBO")
    `COMPARE_COUNTER(tx_super_jumbo_pending,     rx_super_jumbo_pending,     "SUPER_JUMBO")
    `COMPARE_COUNTER(tx_jabber_pending,          rx_jabber_pending,          "JABBER")
    `COMPARE_COUNTER(tx_pause_pending,           rx_pause_pending,           "PAUSE")
    `COMPARE_COUNTER(tx_vlan_pending,            rx_vlan_pending,            "VLAN")
    `COMPARE_COUNTER(tx_ipg_violation_pending,   rx_ipg_violation_pending,   "IPG_VIOLATION")
    `COMPARE_COUNTER(tx_pfc_xon_pending,         rx_pfc_xon_pending,         "PFC_XON")
    `COMPARE_COUNTER(tx_pfc_xoff_pending,        rx_pfc_xoff_pending,        "PFC_XOFF")
    `COMPARE_COUNTER(tx_carrier_ext_pending,     rx_carrier_ext_pending,     "CARRIER_EXT")
    `COMPARE_COUNTER(tx_pause_xon_pending,       rx_pause_xon_pending,       "PAUSE_XON")
    `COMPARE_COUNTER(tx_pause_xoff_pending,      rx_pause_xoff_pending,      "PAUSE_XOFF")
    `COMPARE_COUNTER(tx_control_pkt_pending,     rx_control_pkt_pending,     "CONTROL_PKT")
    
    `COMPARE_COUNTER(tx_pfc_xon_prio0_pending,   rx_pfc_xon_prio0_pending,   "PFC_XON_PRIO0")
    `COMPARE_COUNTER(tx_pfc_xon_prio1_pending,   rx_pfc_xon_prio1_pending,   "PFC_XON_PRIO1")
    `COMPARE_COUNTER(tx_pfc_xon_prio2_pending,   rx_pfc_xon_prio2_pending,   "PFC_XON_PRIO2")
    `COMPARE_COUNTER(tx_pfc_xon_prio3_pending,   rx_pfc_xon_prio3_pending,   "PFC_XON_PRIO3")
    `COMPARE_COUNTER(tx_pfc_xon_prio4_pending,   rx_pfc_xon_prio4_pending,   "PFC_XON_PRIO4")
    `COMPARE_COUNTER(tx_pfc_xon_prio5_pending,   rx_pfc_xon_prio5_pending,   "PFC_XON_PRIO5")
    `COMPARE_COUNTER(tx_pfc_xon_prio6_pending,   rx_pfc_xon_prio6_pending,   "PFC_XON_PRIO6")
    `COMPARE_COUNTER(tx_pfc_xon_prio7_pending,   rx_pfc_xon_prio7_pending,   "PFC_XON_PRIO7")
    
    `COMPARE_COUNTER(tx_pfc_xoff_prio0_pending,  rx_pfc_xoff_prio0_pending,  "PFC_XOFF_PRIO0")
    `COMPARE_COUNTER(tx_pfc_xoff_prio1_pending,  rx_pfc_xoff_prio1_pending,  "PFC_XOFF_PRIO1")
    `COMPARE_COUNTER(tx_pfc_xoff_prio2_pending,  rx_pfc_xoff_prio2_pending,  "PFC_XOFF_PRIO2")
    `COMPARE_COUNTER(tx_pfc_xoff_prio3_pending,  rx_pfc_xoff_prio3_pending,  "PFC_XOFF_PRIO3")
    `COMPARE_COUNTER(tx_pfc_xoff_prio4_pending,  rx_pfc_xoff_prio4_pending,  "PFC_XOFF_PRIO4")
    `COMPARE_COUNTER(tx_pfc_xoff_prio5_pending,  rx_pfc_xoff_prio5_pending,  "PFC_XOFF_PRIO5")
    `COMPARE_COUNTER(tx_pfc_xoff_prio6_pending,  rx_pfc_xoff_prio6_pending,  "PFC_XOFF_PRIO6")
    `COMPARE_COUNTER(tx_pfc_xoff_prio7_pending,  rx_pfc_xoff_prio7_pending,  "PFC_XOFF_PRIO7")
    
    `COMPARE_COUNTER(tx_idle_fault_seq_cnt,      rx_idle_fault_seq_cnt,      "IDLE_FAULT_SEQ")
    `COMPARE_COUNTER(tx_remote_fault_seq_cnt,    rx_remote_fault_seq_cnt,    "REMOTE_FAULT_SEQ")
  endfunction
endclass

