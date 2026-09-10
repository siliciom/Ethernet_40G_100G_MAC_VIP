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

  eth_oversize_frame_seq mac_0;
  eth_oversize_frame_seq mac_1;

  function new(string name = "eth_oversize_frame_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    uvm_status_e status;
    foreach (env_h.agnt_mac[i]) begin
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR, "TX_OVERSIZED_PKT",
                                                              UVM_WARNING);
      env_h.agnt_mac[i].mon_h.set_report_severity_id_override(UVM_ERROR, "RX_OVERSIZED_PKT",
                                                              UVM_WARNING);
    end

    phase.raise_objection(this);
    wait (env_h.agnt_mac[0].drv_h.v_intf.rst == 1'b1 && env_h.agnt_mac[1].drv_h.v_intf.rst);

    // ---------------------------------------------------------
    // Disable pad_Control through RAL
    // ---------------------------------------------------------
    env_h.ral_model[0].tx_pad_control.write(status, 32'h0, UVM_FRONTDOOR);
    env_h.ral_model[1].tx_pad_control.write(status, 32'h0, UVM_FRONTDOOR);

    mac_0 = eth_oversize_frame_seq::type_id::create("mac_0");
    mac_1 = eth_oversize_frame_seq::type_id::create("mac_1");

    mac_0.no_of_pkts = `NO_OF_PKTS;
    mac_0.cfg_h = cfg_h[0];
    mac_1.no_of_pkts = `NO_OF_PKTS;
    mac_1.cfg_h = cfg_h[1];
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

