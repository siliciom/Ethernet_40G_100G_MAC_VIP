//******************************************************************//
//                        ETHERNET AGENT FILE
//
// Implements the Ethernet UVM agent. The agent encapsulates the
// sequencer, driver, and monitor required to generate, drive, and
// observe Ethernet transactions over the configured MAC interface.
//
// Author: Sanjeev
//
//******************************************************************//
class eth_agnt extends uvm_agent;
  `uvm_component_utils(eth_agnt);

  eth_seqr seqr_h;
  eth_drv  drv_h;
  eth_mon  mon_h;
  eth_cnfg cfg;

  function new(string name = "eth_agnt", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    seqr_h = eth_seqr::type_id::create("seqr_h", this);
    drv_h  = eth_drv::type_id::create("drv_h", this);
    mon_h  = eth_mon::type_id::create("mon_h", this);

    if (!uvm_config_db#(eth_cnfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "Agent Config Not Found")
    if (!uvm_config_db#(eth_cnfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_type_name(), "eth_cnfg not found")

    uvm_config_db#(eth_cnfg)::set(this, "drv_h", "cfg", cfg);
    uvm_config_db#(eth_cnfg)::set(this, "mon_h", "cfg", cfg);

  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv_h.seq_item_port.connect(seqr_h.seq_item_export);
  endfunction

endclass
