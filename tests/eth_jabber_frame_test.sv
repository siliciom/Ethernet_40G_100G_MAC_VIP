//******************************************************************//
//              ETHERNET JABBER FRAME TEST
//
// Defines the Ethernet jabber frame test. This test verifies
// detection and handling of oversized Ethernet frames that
// exceed the maximum permitted frame length.
//
//******************************************************************//
class eth_jabber_frame_test extends eth_base_test;
  `uvm_component_utils(eth_jabber_frame_test)
  function new (string name = "eth_jabber_frame_test", uvm_component parent = null);
    super.new(name,parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction    
  task run_phase(uvm_phase phase);
    virtual_seq vseq;
    foreach(env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_CRC_ERR",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"TX_JABBER_PKT",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_JABBER_PKT",UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR,"RX_CRC_DROP",UVM_WARNING);

    end	    
    phase.raise_objection(this);  
    vseq = virtual_seq::type_id::create("vseq");
    vseq.frame_mode = base_virtual_seq::JABBER_MODE;
    vseq.no_of_pkts = `NO_OF_PKTS;
    vseq.wt_dist0 = 30;
    vseq.wt_dist1 = 70;
    vseq.start(env_h.vseqr_h);    
      wait_until_complete();
    phase.drop_objection(this);
  endtask    
endclass

