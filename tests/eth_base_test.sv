//******************************************************************//
//                      ETHERNET TEST FILE
//
// Implements the top-level Ethernet UVM test. The test configures the
// verification environment, applies protocol-specific settings,
// starts virtual sequences, and controls the overall execution of
// Ethernet verification test case scenarios.
// TODO:- Need to add ethernet test case scenarios.
//
// Author: Ankitha, Sanjeev
//
//******************************************************************// 
class eth_base_test extends uvm_test;
  `uvm_component_utils(eth_base_test);
  
  eth_env env_h;
  virtual_seq v_seq;
  eth_cnfg cfg_h;
  int no_of_pkts = `NO_OF_PACKETS;

  
  function new(string name = "eth_base_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    env_h = eth_env::type_id::create("env_h",this);
    cfg_h = eth_cnfg::type_id::create("cfg_h");

    uvm_config_db #(eth_cnfg)::set(this, "env_h.agnt_mac*","cfg",cfg_h);
    
  endfunction
  
  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction
  

endclass

//******************************************************************//
//                    ETHERNET NORMAL FRAME TEST
//
// This test verifies the transmission and reception of normal
// Ethernet frames by generating frame traffic through the virtual
// sequence and checking the end-to-end MAC functionality.
//
//******************************************************************//
class eth_normal_frame_test extends eth_base_test;
  `uvm_component_utils(eth_normal_frame_test)
  
  function new (string name = "eth_normal_frame_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction  

    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    
    phase.raise_objection(this); 

    // Wait until reset is released
    wait(env_h.agnt_mac[0].mon_h.v_intf.rst == 1);
    repeat(this.no_of_pkts) begin
      vseq = virtual_seq::type_id::create("vseq");
      vseq.start(env_h.vseqr_h);  
    end
    #10;
    phase.drop_objection(this);
  endtask  
endclass
