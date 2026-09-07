`ifndef ETH_PFC_SIMULTANEOUS_SEQ_SV
`define ETH_PFC_SIMULTANEOUS_SEQ_SV

class eth_pfc_simultaneous_seq extends base_seq;

  `uvm_object_utils(eth_pfc_simultaneous_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  eth_cnfg cfg_h;

  bit pfc_temp;
  int wt_dist0;
  int wt_dist1;
  bit quanta_ctrl;
  uvm_status_e status;
  uvm_reg_data_t tx_vlan_enable;
  uvm_reg_data_t rx_vlan_enable;
  int num_pkts;
  bit pfc_simul_en;
  bit [2:0] pfc_prio;
  bit [15:0] pfc_quanta;
  bit is_unicast_multicast;

  // pfc_randc_pcp pcp_gen;
  // int xon_prio;
  //int paused_pcp_q[$];

  function new(string name = "eth_pfc_simultaneous_seq");
    super.new(name);
  endfunction
  task body();
    if (cfg_h == null) `uvm_fatal("CFG_NULL", "eth_cnfg handle is null in eth_pfc_basic_seq")

      cfg_h.ral_model.tx_single_vlan_enable.read(status, tx_vlan_enable, UVM_FRONTDOOR);
      cfg_h.ral_model.rx_single_vlan_enable.read(status, rx_vlan_enable, UVM_FRONTDOOR);
    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      randomise_item();
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
      if (pfc_simul_en && pfc_temp && num_pkts < (no_of_pkts - 30)) begin
        // cfg_h.ral_model.tx_single_vlan_enable.write(status,32'h0 , UVM_FRONTDOOR);
        // cfg_h.ral_model.rx_single_vlan_enable.write(status,32'h0 , UVM_FRONTDOOR);
        clear_pfc_fields();

        void'(std::randomize(pfc_prio) with {pfc_prio inside {[0 : 7]};});
        void'(std::randomize(pfc_quanta) with {pfc_quanta inside {[1 : 10]};});

        // ---- WRITE the randomized quanta to the register ----
        if (quanta_ctrl) write_pause_quanta_reg(pfc_prio, pfc_quanta);
        // ---- READ IT BACK and use the readback value to drive the item ----
        read_pause_quanta_reg(pfc_prio, pfc_quanta);

        // cfg_h.ral_model.tx_single_vlan_enable.read(status, tx_vlan_enable, UVM_FRONTDOOR);
        //cfg_h.ral_model.rx_single_vlan_enable.read(status, rx_vlan_enable, UVM_FRONTDOOR);
        req.tx_single_vlan_enable = 0;  // tx_vlan_enable[0];
        req.rx_single_vlan_enable = 0;  //rx_vlan_enable[0];

        req.pfc_frame_en          = pfc_temp;
        req.TPID                  = 16'h0000;
        req.PCP                   = 0;
        req.DEI                   = 0;
        req.VID                   = 0;
        is_unicast_multicast      = $urandom_range(0, 1);
        if (is_unicast_multicast) req.da = 48'h0180_C200_0001;

        req.pause_opc                    = 16'h0101;
        req.ether_type                   = 16'h8808;
        // req.priority_en_vector           = 16'h0000;
        req.priority_en_vector[pfc_prio] = 1;
        for (int i = 0; i < 8; i++)
        // req.pfc_pause_time[i] = 16'h0000;
        req.pfc_pause_time[pfc_prio] = pfc_quanta;  // driven from the READBACK value
      end else begin
        req.pfc_frame_en = 0;
      end

      if (tx_vlan_enable[0] || rx_vlan_enable[0]) begin
        req.TPID = 16'h8100;
        req.PCP  = $urandom_range(0, 7);
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
  task automatic clear_pfc_fields();
    req.pfc_frame_en       = 1'b0;
    req.priority_en_vector = 16'h0000;

    for (int i = 0; i < 8; i++) req.pfc_pause_time[i] = 16'h0000;

  endtask

endclass

`endif
