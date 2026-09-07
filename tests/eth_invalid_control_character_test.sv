//******************************************************************//
//      ETHERNET INVALID CONTROL CHARACTER TEST
//
// Defines the Ethernet invalid control character test. This test
// injects invalid control characters into the interface to verify
// detection, reporting, and handling of protocol violations during
// frame transmission and reception.
//
//******************************************************************//
class eth_invalid_control_character_test extends eth_base_test;
  `uvm_component_utils(eth_invalid_control_character_test)

  error_cb err_cb;
  eth_invalid_control_char_seq mac_0;
  eth_invalid_control_char_seq mac_1;

  function new(string name = "eth_invalid_control_character_test", uvm_component parent = null);
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
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR, "RS_INVALID_CTRL_CHAR", UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR, "TX_PREAMBLE_ERR", UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR, "RX_PREAMBLE_ERR", UVM_WARNING);
      uvm_top.set_report_severity_id_override(UVM_ERROR, "TX_CTRL_DATA_MISMATCH",UVM_WARNING);
      uvm_top.set_report_severity_id_override(UVM_ERROR, "RX_CTRL_DATA_MISMATCH", UVM_WARNING);
    end

    phase.raise_objection(this);

    mac_0 = eth_invalid_control_char_seq::type_id::create("mac_0");
    mac_1 = eth_invalid_control_char_seq::type_id::create("mac_1");

    mac_0.no_of_pkts = `NO_OF_PKTS;
    mac_1.no_of_pkts = `NO_OF_PKTS;
    mac_0.err_cb = err_cb;
    mac_1.err_cb = err_cb;
    mac_0.wt_dist0 = 27;
    mac_0.wt_dist1 = 69;
    mac_1.wt_dist0 = 27;
    mac_1.wt_dist1 = 69;

    fork
      mac_0.start(env_h.agnt_mac[0].seqr_h);
      mac_1.start(env_h.agnt_mac[1].seqr_h);
    join

    wait_until_complete();
    #200;
    phase.drop_objection(this);
  endtask
endclass
