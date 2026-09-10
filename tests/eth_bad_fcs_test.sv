//******************************************************************//
//                ETHERNET BAD FCS TEST
//
// Defines the Ethernet bad FCS test. This test generates
// frames with invalid CRC values and verifies that they are
// detected and discarded correctly.
//
//******************************************************************//
class eth_bad_fcs_test extends eth_base_test;
  `uvm_component_utils(eth_bad_fcs_test)

  error_cb err_cb;
  eth_bad_fcs_seq mac_0;
  eth_bad_fcs_seq mac_1;

  function new(string name = "eth_bad_fcs_test", uvm_component parent = null);
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
    foreach (env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR, "TX_CRC_ERR", UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR, "RX_CRC_DROP",
                                                              UVM_WARNING);
    end

    phase.raise_objection(this);

    mac_0 = eth_bad_fcs_seq::type_id::create("mac_0");
    mac_1 = eth_bad_fcs_seq::type_id::create("mac_1");

    mac_0.no_of_pkts = `NO_OF_PKTS;
    mac_1.no_of_pkts = `NO_OF_PKTS;
    mac_0.err_cb = err_cb;
    mac_1.err_cb = err_cb;
    mac_0.wt_dist0 = 40;
    mac_0.wt_dist1 = 60;
    mac_1.wt_dist0 = 40;
    mac_1.wt_dist1 = 60;

    fork
      mac_0.start(env_h.agnt_mac[0].seqr_h);
      mac_1.start(env_h.agnt_mac[1].seqr_h);
    join
    wait_until_complete();
    #100;
    phase.drop_objection(this);
  endtask
endclass

