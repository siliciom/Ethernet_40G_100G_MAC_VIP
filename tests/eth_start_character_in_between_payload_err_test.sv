//******************************************************************//
//  ETHERNET START CHARACTER IN BETWEEN PAYLOAD ERROR TEST
//
// Defines the Ethernet start character in between payload error
// test. This test injects an unexpected start character within
// the payload to verify detection, reporting, and handling of
// invalid frame formatting and protocol violations.
//
//******************************************************************//
class eth_start_character_in_between_payload_err_test extends eth_base_test;
  `uvm_component_utils(eth_start_character_in_between_payload_err_test)
  error_cb err_cb;
  function new (string name = "eth_start_character_in_between_payload_err_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    err_cb = error_cb::type_id::create("err_cb");
    cfg_h[0].rx_crccheck_control[1]=1;
    cfg_h[1].rx_crccheck_control[1]=1;
  endfunction 
   function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_callbacks#(eth_drv, error_cb)::add(env_h.agnt_mac[0].drv_h, err_cb);
    uvm_callbacks#(eth_drv, error_cb)::add(env_h.agnt_mac[1].drv_h, err_cb);
  endfunction
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RS_UNEXPECTED_START",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_CRC_ERR",UVM_WARNING);
    end  
    phase.raise_objection(this);
      vseq = virtual_seq::type_id::create("vseq");
      vseq.frame_mode = base_virtual_seq::DOUBLE_START_CHAR;
      vseq.err_cb = err_cb;
      vseq.no_of_pkts = `NO_OF_PKTS;
      vseq.wt_dist0 = 30;
      vseq.wt_dist1 = 70;
      vseq.start(env_h.vseqr_h);
    #200;
    phase.drop_objection(this);
  endtask  
endclass
