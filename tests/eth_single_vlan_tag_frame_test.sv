//******************************************************************//
//          ETHERNET SINGLE VLAN TAG TEST
//
// Defines the Ethernet single VLAN tag test. This test
// verifies transmission and reception of IEEE 802.1Q tagged
// Ethernet frames.
//
//******************************************************************//
class eth_single_vlan_tag_frame_test extends eth_base_test;
  `uvm_component_utils(eth_single_vlan_tag_frame_test)
  function new (string name = "eth_single_vlan_tag_frame_test", uvm_component parent = null);
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
    vseq.frame_mode = base_virtual_seq::VLAN_MODE;
    vseq.start(env_h.vseqr_h);    
    #100;
    phase.drop_objection(this);
  endtask    
endclass

