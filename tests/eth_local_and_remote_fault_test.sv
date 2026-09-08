class eth_local_and_remote_fault_test extends eth_base_test;
  `uvm_component_utils(eth_local_and_remote_fault_test)
  eth_normal_frame_seq seq0;
  eth_normal_frame_seq seq1;

  function new(string name = "eth_local_and_remote_fault_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    foreach (env_h.agnt_mac[i]) begin
      uvm_root::get().set_report_severity_id_override(UVM_ERROR, "TX_CTRL_DATA_MISMATCH",
                                                      UVM_WARNING);
      uvm_root::get().set_report_severity_id_override(UVM_ERROR, "RX_CTRL_DATA_MISMATCH",
                                                      UVM_WARNING);
      uvm_root::get().set_report_severity_id_override(UVM_ERROR, "TX_START_AFTER_IDLE_ERR",
                                                      UVM_WARNING);
      uvm_root::get().set_report_severity_id_override(UVM_ERROR, "RX_START_AFTER_IDLE_ERR",
                                                      UVM_WARNING);
      uvm_root::get().set_report_severity_id_override(UVM_ERROR, "TX_START_TERM_ERR", UVM_WARNING);
      uvm_root::get().set_report_severity_id_override(UVM_ERROR, "RX_START_TERM_ERR", UVM_WARNING);
    end
    env_h.ipg_chkr_h.ipg_checker_en = 0;
    phase.raise_objection(this);

    seq0 = eth_normal_frame_seq::type_id::create("seq0");
    seq1 = eth_normal_frame_seq::type_id::create("seq1");

    // Number of packets
    seq0.no_of_pkts = `NO_OF_PKTS;
    seq1.no_of_pkts = `NO_OF_PKTS;
    env_h.agnt_mac[1].drv_h.local_fault_en = 1;

    // Run traffic concurrently on both MAC agents
    fork
      seq0.start(env_h.agnt_mac[0].seqr_h);
      seq1.start(env_h.agnt_mac[1].seqr_h);
    join
    wait_until_complete();
    phase.drop_objection(this);
  endtask
endclass
