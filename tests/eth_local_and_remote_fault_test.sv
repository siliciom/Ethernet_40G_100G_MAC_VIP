class eth_local_and_remote_fault_test extends eth_base_test;
  `uvm_component_utils(eth_local_and_remote_fault_test)
  function new (string name = "eth_local_and_remote_fault_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction  
    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    phase.raise_objection(this); 
      vseq = virtual_seq::type_id::create("vseq");
      vseq.no_of_pkts = `NO_OF_PKTS;
      env_h.agnt_mac[1].drv_h.local_fault_en = 1;
      vseq.start(env_h.vseqr_h);  
    #200;
    phase.drop_objection(this);
  endtask  
endclass
