//******************************************************************//
//         ETHERNET NORMAL PAYLOAD PADDING TEST
//
// Defines the Ethernet payload padding test. This test
// verifies automatic padding of frames with payloads smaller
// than the minimum Ethernet frame size.
//******************************************************************//
class eth_normal_payload_padding_test extends eth_base_test;
  `uvm_component_utils(eth_normal_payload_padding_test)
  function new(string name = "eth_normal_payload_padding_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction
  task run_phase(uvm_phase phase);
    eth_normal_payload_padding_seq seq0;
    eth_normal_payload_padding_seq seq1;
    uvm_status_e status;

    phase.raise_objection(this);
    wait (env_h.agnt_mac[0].drv_h.v_intf.rst == 1'b1 && env_h.agnt_mac[1].drv_h.v_intf.rst);
    env_h.ral_model[0].tx_pad_control.write(status, 1, UVM_FRONTDOOR);
    env_h.ral_model[1].tx_pad_control.write(status, 1, UVM_FRONTDOOR);

    // Create separate sequence objects for each MAC agent
    seq0 = eth_normal_payload_padding_seq::type_id::create("seq0");
    seq1 = eth_normal_payload_padding_seq::type_id::create("seq1");

    // Number of packets
    seq0.cfg_h = cfg_h[0];
    seq0.no_of_pkts = `NO_OF_PKTS;
    seq1.cfg_h = cfg_h[1];
    seq1.no_of_pkts = `NO_OF_PKTS;

    // Run traffic concurrently on both MAC agents
    fork
      seq0.start(env_h.agnt_mac[0].seqr_h);
      seq1.start(env_h.agnt_mac[1].seqr_h);
    join
    wait_until_complete();
    #200;
    phase.drop_objection(this);
  endtask
endclass
