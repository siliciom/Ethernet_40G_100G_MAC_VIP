//******************************************************************//
//                    ETHERNET ENVIRONMENT FILE
//
// Implements the Ethernet UVM environment. The environment instantiates
// and connects the required verification components such as agents,
// scoreboard, coverage collectors, protocol checkers, virtual
// sequencer, and register model to form a complete verification
// environment.
//
// Author: Ankitha, Sanjeev
//
//******************************************************************//
class eth_env extends uvm_env;
  `uvm_component_utils(eth_env);
  
  eth_agnt agnt_mac[];
 
  eth_scb scb_h;
  eth_sbscr sbscr_h;
  
  eth_virtual_seqr vseqr_h;
  
  //**************************************************************//
  // This function creates memory for mac agents
  //**************************************************************//
  function new(string name = "eth_env", uvm_component parent = null);
    super.new(name,parent);
    agnt_mac = new[`NO_OF_AGENTS];
  endfunction
  
  //**************************************************************//
  // This function builds mac agents, scoreboard, subscriber,
  // and virtual sequencer
  //**************************************************************//
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    foreach (agnt_mac[i])
      agnt_mac[i] = eth_agnt::type_id::create($sformatf("agnt_mac[%0d]", i), this); 
    
      scb_h = eth_scb::type_id::create("scb_h",this);
      sbscr_h = eth_sbscr::type_id::create("sbscr_h",this);
    
      vseqr_h = eth_virtual_seqr::type_id::create("vseqr_h",this);
  endfunction
  
  //**************************************************************//
  // This function do the connections for scoreboard and subscriber 
  //**************************************************************//
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    foreach(agnt_mac[i]) begin
      // Scoreboard Connection
      agnt_mac[i].mon_h.tx_ap.connect(scb_h.ai_1[i]);
      agnt_mac[i].mon_h.rx_ap.connect(scb_h.ai_2[i]);    
      
      // Subscriber Connection
      agnt_mac[i].mon_h.tx_ap.connect(sbscr_h.ai_1[i]);
      agnt_mac[i].mon_h.rx_ap.connect(sbscr_h.ai_2[i]);       
    end
    
    for (int i = 0; i < `NO_OF_AGENTS; i++) begin
      vseqr_h.mac_seqr_h[i] = agnt_mac[i].seqr_h; // Virtual Sequencer Connection
    end

  endfunction  
  
endclass
