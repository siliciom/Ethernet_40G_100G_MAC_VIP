//******************************************************************//
//      ETHERNET CONTROL CHARACTER DATA MISMATCH TEST
//
// Defines the Ethernet control character data mismatch test.
// This test injects control/data mismatch conditions to verify
// detection and handling of invalid interface characters and
// the corresponding protocol error reporting mechanisms.
//
//******************************************************************//
class eth_control_char_data_mismatch_test extends eth_base_test;
  `uvm_component_utils(eth_control_char_data_mismatch_test)
  error_cb err_cb;
  function new (string name = "eth_control_char_data_mismatch_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    err_cb = error_cb::type_id::create("err_cb");
  endfunction  
   function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_callbacks#(eth_drv, error_cb)::add(env_h.agnt_mac[0].drv_h, err_cb);
    uvm_callbacks#(eth_drv, error_cb)::add(env_h.agnt_mac[1].drv_h, err_cb);
  endfunction
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RS_UNKNOWN_CTRL",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_CRC_ERR",UVM_WARNING);
      uvm_top.set_report_severity_id_override(UVM_ERROR,"TX_CTRL_DATA_MISMATCH",UVM_WARNING);
      uvm_top.set_report_severity_id_override(UVM_ERROR,"RX_CTRL_DATA_MISMATCH",UVM_WARNING);
    end
    env_h.ipg_chkr_h.ipg_checker_en = 0;
    phase.raise_objection(this);
      vseq = virtual_seq::type_id::create("vseq");
      vseq.frame_mode = base_virtual_seq::CONTROL_DATA_MISMATCH;
      vseq.err_cb = err_cb;
      vseq.no_of_pkts = `NO_OF_PKTS;
      vseq.wt_dist0 = 30;
      vseq.wt_dist1 = 70;
      vseq.start(env_h.vseqr_h);
      wait_until_complete();
    phase.drop_objection(this);
  endtask  
endclass
