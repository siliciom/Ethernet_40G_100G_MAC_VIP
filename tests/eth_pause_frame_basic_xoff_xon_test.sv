//******************************************************************//
//           ETHERNET PAUSE FRAME BASIC XOFF/XON TEST
//
// Defines the Ethernet PAUSE frame basic XOFF/XON test. This test
// generates PAUSE control frames along with normal traffic
// and verifies that normal traffic is correctly paused (XOFF) and
// resumed (XON) in response to the PAUSE frames.
//
//******************************************************************//
class eth_pause_frame_basic_xoff_xon_test extends eth_base_test;
  `uvm_component_utils(eth_pause_frame_basic_xoff_xon_test)

  eth_pause_frame_basic_seq mac_0;
  eth_pause_frame_basic_seq mac_1;

  function new(string name = "eth_pause_frame_basic_xoff_xon_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    bit [31:0] val;
    uvm_status_e status;
    phase.raise_objection(this);
    pkt_rand_en = 1;
    env_h.ral_model[1].rx_frame_control.write(status, 32'h0000_0000, UVM_FRONTDOOR);  // Bit 4 = 1 
    env_h.ral_model[0].tx_crc_control.read(status, val, UVM_FRONTDOOR);
    if (pkt_rand_en == 0) begin
      env_h.ral_model[0].tx_pauseframe_quanta.write(status, $urandom_range(0, 10), UVM_FRONTDOOR);
      env_h.ral_model[1].tx_pauseframe_quanta.write(status, $urandom_range(0, 10), UVM_FRONTDOOR);
    end

    mac_0 = eth_pause_frame_basic_seq::type_id::create("mac_0");
    mac_1 = eth_pause_frame_basic_seq::type_id::create("mac_1");

    mac_0.no_of_pkts = `NO_OF_PKTS;
    mac_0.normal_xon_xoff_en = 1;
    mac_0.pkt_rand_en = pkt_rand_en;
    mac_0.cfg_h = cfg_h[0];
    mac_0.wt_dist0 = 70;
    mac_0.wt_dist1 = 30;

    mac_1.no_of_pkts = `NO_OF_PKTS;
    mac_1.normal_xon_xoff_en = 0;
    mac_1.pkt_rand_en = pkt_rand_en;
    mac_1.cfg_h = cfg_h[1];
    mac_1.wt_dist0 = 70;
    mac_1.wt_dist1 = 30;

    fork
      mac_0.start(env_h.agnt_mac[0].seqr_h);
      mac_1.start(env_h.agnt_mac[1].seqr_h);
    join

    wait_until_complete();
    #200;
    phase.drop_objection(this);
  endtask
endclass
