//******************************************************************//
//                     ETHERNET SEQUENCE FILE
//
// This sequence is responsible for configuring and randomizing 
// Ethernet MAC registers through the virtual sequencer. 
// Register fields may be randomized or explicitly programmed based
// on the requirements of the test.
// TODO:- Extend the sequence to support Ethernet control frames 
// such as Pause, PFC, and Fault Sequences..
//
// Author: Dheeraj
//
//******************************************************************//

class eth_reg_config_seq extends uvm_sequence;
  `uvm_object_utils(eth_reg_config_seq)
  eth_cnfg cfg_h;
  int agent_id;
  `uvm_declare_p_sequencer(eth_virtual_seqr)

  function new(string name = "eth_reg_seq");
    super.new(name);
  endfunction

  task body();
    cfg_h = p_sequencer.cfg_h[agent_id];
    //cfg_h.tx_single_vlan_enable = 1;
    //cfg_h.rx_single_vlan_enable = 1;

    assert (cfg_h.randomize() with {
      tx_single_vlan_enable inside {32'h0, 32'h1};
      rx_single_vlan_enable == tx_single_vlan_enable;
    });
  endtask
endclass





