//******************************************************************//
//             ETHERNET OVERSIZE FRAME TEST
//
// Defines the Ethernet oversize frame test. This test generates
// oversized Ethernet frames and verifies detection, reporting,
// and handling of frames exceeding the maximum supported frame
// length.
//
//******************************************************************//
class eth_oversize_frame_test extends eth_base_test;
  `uvm_component_utils(eth_oversize_frame_test)
 
  function new (string name = "eth_oversize_frame_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
 
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_LONG_PKT",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_LONG_PKT",UVM_WARNING);
    end	   
    phase.raise_objection(this);
    vseq = virtual_seq::type_id::create("vseq");
    vseq.frame_mode = base_virtual_seq::OVERSIZE_MODE;
    vseq.jumbo_en   = 1;
    vseq.no_of_pkts = `NO_OF_PKTS;
    vseq.wt_dist0   = 40;
    vseq.wt_dist1   = 60;
    vseq.start(env_h.vseqr_h);
      wait_until_complete();
    phase.drop_objection(this);
  endtask
endclass
