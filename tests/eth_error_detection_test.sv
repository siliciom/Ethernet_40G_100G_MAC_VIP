//******************************************************************//
//             ETHERNET ERROR DETECTION TEST
//
// Defines the Ethernet error detection test. This test injects
// transmission errors and verifies protocol error detection and
// reporting mechanisms.
//
//******************************************************************//

class eth_error_detection_test extends eth_base_test;

  `uvm_component_utils(eth_error_detection_test)
  error_cb err_cb;

  function new(string name = "eth_error_detection_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  //================================================================
  // BUILD
  //================================================================
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    err_cb = error_cb::type_id::create("err_cb");
  endfunction


  //================================================================
  // CALLBACK REGISTRATION
  //================================================================
  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_callbacks#(eth_drv, error_cb)::add(env_h.agnt_mac[0].drv_h, err_cb);
    uvm_callbacks#(eth_drv, error_cb)::add(env_h.agnt_mac[1].drv_h, err_cb);
  endfunction


  //================================================================
  // RUN
  //================================================================
  task run_phase(uvm_phase phase);

    eth_error_detection_seq mac_0, mac_1;
    phase.raise_objection(this);

    // -------------------------------------------------------------
    // Downgrade expected error messages to warnings
    // -------------------------------------------------------------
    foreach (env_h.agnt_mac[i]) begin

      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR, "TX_CRC_ERR", UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR, "RX_CRC_DROP",
                                                              UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR, "RS_FRAMER_ERROR_CHAR",
                                                              UVM_WARNING);
    end

    // -------------------------------------------------------------
    // Agent 0 sequence
    // -------------------------------------------------------------
    mac_0            = eth_error_detection_seq::type_id::create("mac_0");
    mac_0.no_of_pkts = no_of_pkts;
    mac_0.err_cb     = err_cb;
    mac_0.wt_dist0   = 40;
    mac_0.wt_dist1   = 60;


    // -------------------------------------------------------------
    // Agent 1 sequence
    // -------------------------------------------------------------
    mac_1            = eth_error_detection_seq::type_id::create("seq1");
    mac_1.no_of_pkts = no_of_pkts;
    mac_1.err_cb     = err_cb;
    mac_1.wt_dist0   = 40;
    mac_1.wt_dist1   = 60;


    // -------------------------------------------------------------
    // Start both agents
    // -------------------------------------------------------------
    fork
      mac_0.start(env_h.agnt_mac[0].seqr_h);
      mac_1.start(env_h.agnt_mac[1].seqr_h);
    join

    // Wait until driver/monitor activity is complete
    wait_until_complete();
    #500;
    phase.drop_objection(this);
  endtask
endclass
