//******************************************************************//
//           ETHERNET MINIMUM SIZE FRAME TEST
//
// Defines the Ethernet minimum frame size test. This test
// verifies transmission, padding, and reception of frames
// with the minimum valid Ethernet payload.
//
//******************************************************************//
class eth_min_size_frame_test extends eth_base_test;

  `uvm_component_utils(eth_min_size_frame_test)

  eth_min_size_seq mac_0, mac_1;

  function new(string name = "eth_min_size_frame_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    uvm_status_e status;
    phase.raise_objection(this);
    for(int i=0; i<`NO_OF_AGENTS;i++) begin
      env_h.ral_model[i].tx_frame_minlength.write(status, 32'h40, UVM_FRONTDOOR);
      env_h.ral_model[i].rx_frame_minlength.write(status, 32'h40, UVM_FRONTDOOR);
    end

    // Create separate sequence objects for each MAC agent
    mac_0 = eth_min_size_seq::type_id::create("mac_0");
    mac_1 = eth_min_size_seq::type_id::create("mac_1");

    // Number of packets
    mac_0.no_of_pkts = `NO_OF_PKTS;
    mac_1.no_of_pkts = `NO_OF_PKTS;

    // Run traffic concurrently on both MAC agents
    fork
      mac_0.start(env_h.agnt_mac[0].seqr_h);
      mac_1.start(env_h.agnt_mac[1].seqr_h);
    join
    wait_until_complete();
    #300;
    phase.drop_objection(this);
  endtask

endclass

