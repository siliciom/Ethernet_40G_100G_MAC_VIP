//******************************************************************//
//                    ETHERNET SCOREBOARD FILE
//
// Implements the Ethernet UVM scoreboard. The scoreboard compares
// expected and observed Ethernet transactions, verifies protocol
// correctness, checks frame integrity, and reports functional
// mismatches and data inconsistencies.
// TODO: Need to compare the expected and actual frame fields
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
  
   // Queue to store tx n rx packets
  eth_seq_item tx_q[$];
  eth_seq_item rx_q[$];

  //**************************************************************//
  // Constructor for the Ethernet scoreboard component.
  // Creates all analysis implementation ports.
  //**************************************************************//
  function new(string name = "eth_scb", uvm_component parent = null);
    super.new(name,parent);

    // Creating memory for tlm analysis imp ports
    foreach(ai_1[i])
      ai_1[i]=new($sformatf ("ai_1[%0d]",i),this);

    foreach(ai_2[i])
      ai_2[i]=new($sformatf ("ai_2[%0d]",i),this);

  endfunction   

  //**************************************************************//
  // This function performs component build operations.
  //**************************************************************//
  function void build_phase(uvm_phase phase);
    super.build_phase(phase); 
  endfunction  

  //**************************************************************//
  // Receives transmit transactions through analysis port 1.
  // Stores the transaction and triggers comparison.
  //**************************************************************//
  function void write_ap_1(eth_seq_item tx_tr);
    eth_seq_item tx_copy;

    tx_copy = eth_seq_item::type_id::create("tx_copy");
    tx_copy.copy(tx_tr);
    if(tx_tr.txd != 0 && tx_tr.txc != 0)
      tx_q.push_back(tx_copy);
    compare();
    `uvm_info(get_type_name(),$sformatf("TXD=%0h TXC=%0h", tx_tr.txd, tx_tr.txc),UVM_LOW)
  endfunction

  //**************************************************************//
  // Receives receive transactions through analysis port 2.
  // Stores the transaction and triggers comparison.
  //**************************************************************//
   function void write_ap_2(eth_seq_item rx_tr);
     eth_seq_item rx_copy;

     rx_copy = eth_seq_item::type_id::create("rx_copy");
     rx_copy.copy(rx_tr);

     if(rx_tr.rxd != 0 && rx_tr.rxc != 0)
       rx_q.push_back(rx_copy);
     compare();
     `uvm_info(get_type_name(),$sformatf("RXD=%0h RXC=%0h", rx_tr.rxd, rx_tr.rxc),UVM_LOW)
   endfunction

  //**************************************************************//
  // Compares queued transmit and receive transactions.
  // Reports pass or fail based on data comparison.
  //**************************************************************//
  function void compare();
  
    eth_seq_item tx_tr;
    eth_seq_item rx_tr;
  
    while (tx_q.size() > 0 && rx_q.size() > 0) begin
  
      tx_tr = tx_q.pop_front();
      rx_tr = rx_q.pop_front();
      `uvm_info(get_type_name(),$sformatf("TX=%0h RX=%0h",tx_tr.txd, rx_tr.rxd), UVM_LOW)
  
      if (tx_tr.txd == rx_tr.rxd && tx_tr.txc == rx_tr.rxc)begin
        `uvm_info(get_type_name(),$sformatf("PASS: TX=%0h RX=%0h",tx_tr.txd, rx_tr.rxd), UVM_LOW)
      end
      else
          $sformatf("FAIL: Expected TXD=%0h TXC=%0h, Got RXD=%0h RXC=%0h", tx_tr.txd, tx_tr.txc,
                    rx_tr.rxd, rx_tr.rxc);
    end
  endfunction
endclass
