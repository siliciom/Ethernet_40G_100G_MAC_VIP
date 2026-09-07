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

  `uvm_component_utils(eth_base_test)

  eth_env env_h;

  eth_cnfg cfg_h[];

  int no_of_pkts = `NO_OF_PKTS;
  bit pkt_rand_en;
  bit quanta_ctrl = 1;
  function new(string name = "eth_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    env_h = eth_env::type_id::create("env_h", this);

    cfg_h = new[`NO_OF_AGENTS];

    foreach (cfg_h[i]) begin

      cfg_h[i] = eth_cnfg::type_id::create($sformatf("cfg_%0d", i));

      uvm_config_db#(eth_cnfg)::set(this, $sformatf("env_h.agnt_mac[%0d]", i), "cfg", cfg_h[i]);
      uvm_config_db#(eth_cnfg)::set(this, "env_h.scb_h", $sformatf("scb_cfg_%0d", i), cfg_h[i]);

    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Give the RAL model handle to each MAC configuration
    foreach (cfg_h[i]) begin
      cfg_h[i].ral_model = env_h.ral_model[i];
      env_h.ral_model[i].reset();
    end

  endfunction


  task wait_until_complete();
    fork
      begin
        for (int i = 0; i < `NO_OF_AGENTS; i++) begin
          fork
            automatic int idx = i;
            begin
              wait (env_h.agnt_mac[idx].drv_h.frame_in_progress == 0);
              wait (env_h.agnt_mac[idx].mon_h.rx_frame_q.size() == 0);
            end
          join_none
        end
        wait fork;
      end
    join
  endtask

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

endclass

