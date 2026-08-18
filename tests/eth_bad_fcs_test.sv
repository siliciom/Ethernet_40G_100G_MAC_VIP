//******************************************************************//
//                ETHERNET BAD FCS TEST
//
// Defines the Ethernet bad FCS test. This test generates
// frames with invalid CRC values and verifies that they are
// detected and discarded correctly.
//
//******************************************************************//
class eth_bad_fcs_test extends eth_base_test;
   error_cb err_cb;
  `uvm_component_utils(eth_bad_fcs_test)
  function new (string name = "eth_bad_fcs_test", uvm_component parent = null);
    super.new(name,parent);
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
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_CRC_ERR",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_CRC_DROP",UVM_WARNING);
    end
    phase.raise_objection(this);  
      vseq = virtual_seq::type_id::create("vseq");
      vseq.no_of_pkts = `NO_OF_PKTS;   
      vseq.frame_mode = base_virtual_seq::BAD_FCS;
      vseq.err_cb = err_cb;
      vseq.wt_dist0 = 40;
      vseq.wt_dist1 = 60;   
      vseq.start(env_h.vseqr_h);    
      wait_until_complete();
    phase.drop_objection(this);
  endtask    
endclass

