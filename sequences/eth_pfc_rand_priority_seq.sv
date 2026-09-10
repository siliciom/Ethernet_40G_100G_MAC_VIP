//******************************************************************//
//                  ETH PFC RANDOM PRIORITY SEQUENCE
//
// PFC XOFF fired on a randomized priority (~10/100 packets).
// Mirrors virtual_seq's pfc_rand_pri_en branch.
//
// When basic_pfc_en=1 (mac_0 role): randomly fires PFC XOFF on a
// random priority, then publishes that priority + a small credit
// count via static fields so another instance of this same class
// (mac_1 role, basic_pfc_en=0) can bias its own PCP to match for
// the next few packets, producing a clear PFC->hold-queue correlation.
//******************************************************************//

`ifndef ETH_PFC_RAND_PRIORITY_SEQ_SV
`define ETH_PFC_RAND_PRIORITY_SEQ_SV

class eth_pfc_rand_priority_seq extends base_seq;

  `uvm_object_utils(eth_pfc_rand_priority_seq)
  `uvm_declare_p_sequencer(eth_seqr)
  eth_cnfg              cfg_h;

  uvm_status_e          status;
  uvm_reg_data_t        tx_vlan_enable;
  uvm_reg_data_t        rx_vlan_enable;
  bit                   pfc_temp;
  int                   wt_dist0;
  int                   wt_dist1;
  bit                   quanta_ctrl;
  bit            [ 2:0] forced_prio;
  bit                   basic_pfc_en;
  bit            [ 2:0] pfc_prio;
  bit            [15:0] pfc_quanta;
  int                   num_pkts;

  // ---------------------------------------------------------------
  // Shared (static) state used to correlate a "reactor" instance's
  // PCP with a "generator" instance's most recent PFC priority.
  // Static => shared automatically across all instances of this
  // class (e.g. mac_0 and mac_1), no external handle/class needed.
  // ---------------------------------------------------------------
  static bit     [ 2:0] shared_pfc_prio;
  static int            shared_pfc_credits;
  static int            shared_min_follow_pkts = 3;
  static int            shared_max_follow_pkts = 5;

  function new(string name = "eth_pfc_rand_priority_seq");
    super.new(name);
  endfunction

  task body();
    if (cfg_h == null)
      `uvm_fatal("CFG_NULL", "eth_cnfg handle is null in eth_pfc_rand_priority_seq")

      cfg_h.ral_model.tx_single_vlan_enable.read(status, tx_vlan_enable, UVM_FRONTDOOR);
      cfg_h.ral_model.rx_single_vlan_enable.read(status, rx_vlan_enable, UVM_FRONTDOOR);
    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      randomise_item();
      //cfg_h.ral_model.tx_single_vlan_enable.read(status, tx_vlan_enable, UVM_FRONTDOOR);
      //cfg_h.ral_model.rx_single_vlan_enable.read(status, rx_vlan_enable, UVM_FRONTDOOR);
      req.tx_single_vlan_enable = tx_vlan_enable[0];
      req.rx_single_vlan_enable = rx_vlan_enable[0];
      void'(std::randomize(
          pfc_temp
      ) with {
        pfc_temp dist {
          0 := wt_dist1,
          1 := wt_dist0
        };
      });

      if (basic_pfc_en && pfc_temp && num_pkts < (no_of_pkts - 30)) begin

        void'(std::randomize(pfc_quanta) with {pfc_quanta inside {[1 : 10]};});
        void'(std::randomize(pfc_prio) with {pfc_prio inside {[0 : 7]};});
        forced_prio = pfc_prio;
        if (quanta_ctrl) write_pause_quanta_reg(pfc_prio, pfc_quanta);
        read_pause_quanta_reg(pfc_prio, pfc_quanta);

        // Publish this priority so a reactor instance (e.g. mac_1)
        // can bias its next few packets' PCP to match.
        shared_pfc_prio = forced_prio;
        shared_pfc_credits = $urandom_range(shared_min_follow_pkts, shared_max_follow_pkts);

        req.pfc_frame_en = 1;
        req.tx_single_vlan_enable = 0;
        req.rx_single_vlan_enable = 0;
        req.TPID = 16'h0000;
        req.PCP = 0;
        req.DEI = 0;
        req.VID = 0;
        req.da = 48'h0180_C200_0001;
        req.pause_opc = 16'h0101;
        req.ether_type = 16'h8808;
        req.priority_en_vector = 16'h0000;
        req.priority_en_vector[pfc_prio] = 1;
        for (int i = 0; i < 8; i++) req.pfc_pause_time[i] = 16'h0000;
        req.pfc_pause_time[pfc_prio] = pfc_quanta;  // driven from the READBACK value
        if ($urandom_range(0, 1)) req.da = 48'h0180c2000001;

      end else begin
        req.pfc_frame_en = 0;
        fixed_ethertype_item($urandom_range(42, 64));
        // Reactor path (mac_1, basic_pfc_en=0 always lands here; mac_0
        // also lands here on packets where it doesn't fire PFC itself).
        // If credits remain from a recent PFC event, bias PCP to match
        // it for a handful of packets, then fall back to random.
        if (shared_pfc_credits > 0) begin
          forced_prio = shared_pfc_prio;
          shared_pfc_credits--;
        end else begin
          forced_prio = $urandom_range(0, 7);
        end
      end

      if (tx_vlan_enable[0] || rx_vlan_enable[0]) begin
        req.TPID = 16'h8100;
        req.PCP  = forced_prio;
        req.DEI  = 0;
        req.VID  = 0;
      end

      num_pkts++;
      finish_item(req);
    end
  endtask

  //--------------------------------------------------------------
  // Writes the randomized quanta to the matching per-priority
  // register and enables that priority in tx_pfc_priority_enable.
  //--------------------------------------------------------------
  task write_pause_quanta_reg(bit [2:0] prio, bit [15:0] quanta);
    uvm_status_e   wstatus;
    uvm_reg_data_t enable_mask;
    case (prio)
      0: cfg_h.ral_model.tx_pause_quanta_0.write(wstatus, quanta, UVM_FRONTDOOR);
      1: cfg_h.ral_model.tx_pause_quanta_1.write(wstatus, quanta, UVM_FRONTDOOR);
      2: cfg_h.ral_model.tx_pause_quanta_2.write(wstatus, quanta, UVM_FRONTDOOR);
      3: cfg_h.ral_model.tx_pause_quanta_3.write(wstatus, quanta, UVM_FRONTDOOR);
      4: cfg_h.ral_model.tx_pause_quanta_4.write(wstatus, quanta, UVM_FRONTDOOR);
      5: cfg_h.ral_model.tx_pause_quanta_5.write(wstatus, quanta, UVM_FRONTDOOR);
      6: cfg_h.ral_model.tx_pause_quanta_6.write(wstatus, quanta, UVM_FRONTDOOR);
      7: cfg_h.ral_model.tx_pause_quanta_7.write(wstatus, quanta, UVM_FRONTDOOR);
    endcase
    enable_mask = (32'h1 << prio);
    cfg_h.ral_model.tx_pfc_priority_enable.write(wstatus, enable_mask, UVM_FRONTDOOR);
  endtask

  //--------------------------------------------------------------
  // Reads the register back into pfc_quanta, so req is driven from
  // the register's actual (post-write) value rather than the raw
  // randomized value blindly.
  //--------------------------------------------------------------
  task read_pause_quanta_reg(bit [2:0] prio, ref bit [15:0] quanta_out);
    uvm_status_e   rstatus;
    uvm_reg_data_t rdata;
    case (prio)
      0: cfg_h.ral_model.tx_pause_quanta_0.read(rstatus, rdata, UVM_FRONTDOOR);
      1: cfg_h.ral_model.tx_pause_quanta_1.read(rstatus, rdata, UVM_FRONTDOOR);
      2: cfg_h.ral_model.tx_pause_quanta_2.read(rstatus, rdata, UVM_FRONTDOOR);
      3: cfg_h.ral_model.tx_pause_quanta_3.read(rstatus, rdata, UVM_FRONTDOOR);
      4: cfg_h.ral_model.tx_pause_quanta_4.read(rstatus, rdata, UVM_FRONTDOOR);
      5: cfg_h.ral_model.tx_pause_quanta_5.read(rstatus, rdata, UVM_FRONTDOOR);
      6: cfg_h.ral_model.tx_pause_quanta_6.read(rstatus, rdata, UVM_FRONTDOOR);
      7: cfg_h.ral_model.tx_pause_quanta_7.read(rstatus, rdata, UVM_FRONTDOOR);
    endcase
    quanta_out = rdata[15:0];
  endtask

endclass

`endif
