//******************************************************************//
//         ETHERNET PAUSE FRAME DURING VLAN TRAFFIC TEST
//
// Defines the Ethernet PAUSE frame during VLAN traffic test. This
// test enables single VLAN tagging on both TX and RX paths and
// generates  PAUSE control frames along with VLAN-tagged
// normal traffic, verifying that VLAN traffic is correctly paused
// (XOFF) and resumed (XON) in response to the PAUSE frames.
//
//******************************************************************//

class eth_pause_frame_during_vlan_traffic_test extends eth_base_test;
  `uvm_component_utils(eth_pause_frame_during_vlan_traffic_test)
  function new (string name = "eth_pause_frame_during_vlan_traffic_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
      cfg_h[0].tx_single_vlan_enable[0] = 1;
      cfg_h[1].tx_single_vlan_enable[0] = 1;
      cfg_h[0].rx_single_vlan_enable[0] = 1;
      cfg_h[1].rx_single_vlan_enable[0] = 1;

  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this);          
    vseq = virtual_seq::type_id::create("vseq");
    vseq.no_of_pkts = `NO_OF_PKTS;   
    vseq.ether_type = 46;
    vseq.payload_rand_en = 0;
    vseq.pause_normal_traffic = 1;
    vseq.vlan_en=1;
    vseq.TPID =16'h8100;
    vseq.vlan_pause_en=1;
    vseq.normal_xon_xoff_en = 1;
    vseq.start(env_h.vseqr_h);
    #200;
    phase.drop_objection(this);
  endtask    
endclass

