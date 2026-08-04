//******************************************************************//
//                      ETHERNET TEST FILE
//
// Implements the top-level Ethernet UVM test. The test configures the
// verification environment, applies protocol-specific settings,
// starts virtual sequences, and controls the overall execution of
// Ethernet verification test case scenarios.
//
// Author: Dheeraj
// 
//******************************************************************// 
class eth_base_test extends uvm_test;
  `uvm_component_utils(eth_base_test);
  
  eth_env env_h;
  virtual_seq v_seq;
  eth_cnfg cfg_h[];
  int no_of_pkts = 100;
  function new(string name = "eth_base_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env_h = eth_env::type_id::create("env_h",this);
      cfg_h = new[`NO_OF_AGENTS];
      foreach(cfg_h[i]) begin
        cfg_h[i] = eth_cnfg::type_id::create($sformatf("cfg_%0d", i));
        uvm_config_db#(eth_cnfg)::set(this, $sformatf("env_h.agnt_mac[%0d]", i), "cfg", cfg_h[i]);
      end
  endfunction
  
  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction
endclass

