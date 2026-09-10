class eth_mac2_mac3_addr_cov_test extends eth_base_test;

  `uvm_component_utils(eth_mac2_mac3_addr_cov_test)

  eth_mac2_mac3_addr_cov_seq mac2_seq;
  eth_mac2_mac3_addr_cov_seq mac3_seq;

  function new(
    string name = "eth_mac2_mac3_addr_cov_test",
    uvm_component parent = null
  );
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction


  task run_phase(uvm_phase phase);

    phase.raise_objection(this);

    //==============================================================
    // Create sequence
    //==============================================================
    mac2_seq = eth_mac2_mac3_addr_cov_seq::type_id::create("mac2_seq");
    mac3_seq = eth_mac2_mac3_addr_cov_seq::type_id::create("mac3_seq");
    eth_top.mac23_route_en = 1;
    mac2_seq.no_of_pkts = `NO_OF_PKTS;
    mac3_seq.no_of_pkts = `NO_OF_PKTS;
    fork 
      mac2_seq.start(env_h.agnt_mac[2].seqr_h);
      mac3_seq.start(env_h.agnt_mac[3].seqr_h);
    join
    //==============================================================
    // Wait for completion
    //==============================================================
    wait_until_complete();

    #100;

    phase.drop_objection(this);

  endtask

endclass
