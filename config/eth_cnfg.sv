//******************************************************************//
//            ETHERNET REGISTER CONFIGURATION FILE
//
// Defines the register configuration settings used by the Ethernet
// verification environment. It contains register initialization
// values, feature enable controls, protocol configuration fields,
// and other register-related parameters required during simulation.
// TODO:- Need to add the registers and its configurations
//
// Author: Lavanya
//
//******************************************************************//
class eth_cnfg extends uvm_object;

  `uvm_object_utils(eth_cnfg)

  // Virtual Interface
  virtual eth_if vif;

  function new(string name="eth_cnfg");
    super.new(name);
  endfunction

endclass
