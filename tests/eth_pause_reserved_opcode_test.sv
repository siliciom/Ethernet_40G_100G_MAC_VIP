//******************************************************************//
//            ETHERNET PAUSE RESERVED OPCODE TEST
//
// Defines the Ethernet PAUSE reserved opcode test. This test
// generates PAUSE control frames using a reserved (non-standard)
// opcode value instead of the standard PAUSE opcode (0x0001), and
// verifies that such frames are correctly identified/handled
// (e.g. ignored or flagged) rather than being treated as valid
// PAUSE frames.
//
//******************************************************************//
class eth_pause_reserved_opcode_test extends eth_base_test;
  `uvm_component_utils(eth_pause_reserved_opcode_test)

  eth_pause_frame_reserved_opcode_seq mac_0;
  eth_pause_frame_reserved_opcode_seq mac_1;
  function new(string name = "eth_pause_reserved_opcode_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    uvm_status_e status;
    bit [31:0] var_1;
    phase.raise_objection(this);
    wait (env_h.agnt_mac[0].drv_h.v_intf.rst == 1'b1 && env_h.agnt_mac[1].drv_h.v_intf.rst == 1'b1);
    pkt_rand_en = 1;

    if (pkt_rand_en == 0) begin
      env_h.ral_model[0].tx_pauseframe_quanta.write(status, $urandom_range(0, 10), UVM_FRONTDOOR);
      env_h.ral_model[1].tx_pauseframe_quanta.write(status, $urandom_range(0, 10), UVM_FRONTDOOR);
    end
    mac_0              = eth_pause_frame_reserved_opcode_seq::type_id::create("mac_0");
    mac_0.cfg_h        = cfg_h[0];
    mac_0.no_of_pkts   = `NO_OF_PKTS;
    mac_0.pause_rsd_en = 1'b1;
    mac_0.cfg_h        = cfg_h[0];
    mac_0.pkt_rand_en  = pkt_rand_en;
    mac_0.wt_dist0     = 70;
    mac_0.wt_dist1     = 30;

    mac_1              = eth_pause_frame_reserved_opcode_seq::type_id::create("mac_1");
    mac_1.cfg_h        = cfg_h[1];
    mac_1.no_of_pkts   = `NO_OF_PKTS;
    mac_1.pause_rsd_en = 1'b1;
    mac_1.cfg_h        = cfg_h[1];
    mac_1.pkt_rand_en  = pkt_rand_en;
    mac_1.wt_dist0     = 70;
    mac_1.wt_dist1     = 30;
    fork
      mac_0.start(env_h.agnt_mac[0].seqr_h);
      mac_1.start(env_h.agnt_mac[1].seqr_h);
    join
    #200;
    wait_until_complete();
    phase.drop_objection(this);
  endtask
endclass
