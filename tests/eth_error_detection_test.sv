//******************************************************************//
//             ETHERNET ERROR DETECTION TEST
//
// Defines the Ethernet error detection test. This test
// injects transmission errors and verifies protocol error
// detection and reporting mechanisms.
//
//******************************************************************//
class eth_error_detection_test extends eth_base_test;
  `uvm_component_utils(eth_error_detection_test)
  error_cb err_cb;
  function new(string name = "eth_error_detection_test", uvm_component parent = null);
     super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
     err_cb = error_cb::type_id::create("err_cb");
  endfunction
  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_callbacks#(eth_drv, error_cb)::add( env_h.agnt_mac[0].drv_h, err_cb);
    uvm_callbacks#(eth_drv, error_cb)::add( env_h.agnt_mac[1].drv_h, err_cb);
  endfunction
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_CRC_ERR",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_CRC_DROP",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RS_FRAMER_ERROR_CHAR",UVM_WARNING);
    end
    phase.raise_objection(this);
      vseq = virtual_seq::type_id::create("vseq");
      vseq.no_of_pkts = `NO_OF_PKTS;      
      vseq.frame_mode = base_virtual_seq::ERR_DET;
      vseq.err_cb = err_cb;
      vseq.wt_dist0 = 40;
      vseq.wt_dist1 = 60;
      vseq.start(env_h.vseqr_h);
      wait_until_complete();
    phase.drop_objection(this);
  endtask
endclass

