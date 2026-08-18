//******************************************************************//
//     ETHERNET END CHARACTER IN BETWEEN PAYLOAD ERROR TEST
//
// Defines the Ethernet end character in between payload error
// test. This test injects an unexpected terminate character
// within the payload to verify detection, reporting, and handling
// of invalid frame termination and protocol violations.
//
//******************************************************************//
class eth_end_character_in_between_payload_err_test extends eth_base_test;
  `uvm_component_utils(eth_end_character_in_between_payload_err_test)
  error_cb err_cb;
  function new (string name = "eth_end_character_in_between_payload_err_test", uvm_component parent = null);
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
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RS_TERMINATE_ALIGN_ERR",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_CRC_ERR",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RS_TERMINATE_CROSS_CYCLE_ERR",UVM_WARNING);
      uvm_top.set_report_severity_id_override(UVM_ERROR,"TX_TERM_TO_IDLE_VIOLATION",UVM_WARNING);
      uvm_top.set_report_severity_id_override(UVM_ERROR,"RX_TERM_TO_IDLE_VIOLATION",UVM_WARNING);
 
    end
    env_h.ipg_chkr_h.ipg_checker_en = 0;
    phase.raise_objection(this);
      vseq = virtual_seq::type_id::create("vseq");
      vseq.frame_mode = base_virtual_seq::DOUBLE_TERMINATE;
      vseq.err_cb = err_cb;
      vseq.no_of_pkts = `NO_OF_PKTS;
      vseq.wt_dist0 = 30;
      vseq.wt_dist1 = 70;
      vseq.start(env_h.vseqr_h);
      wait_until_complete();
    phase.drop_objection(this);
  endtask  
endclass
