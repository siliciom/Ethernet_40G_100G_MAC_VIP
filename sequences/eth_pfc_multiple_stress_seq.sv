//******************************************************************//
//                  ETH PFC MULTIPLE (CONSECUTIVE DIFFERENT PRIO)
//                  STRESS SEQUENCE
//
// Alternates PCP 3/4 across packet count and ramps pause quanta
// 10 -> 6 -> 3 -> 0 in fixed count windows (count 2..9).
// Mirrors virtual_seq's set_multiple_pfc_stress() task /
// multiple_pfc_stress_en branch.
//******************************************************************//

`ifndef ETH_PFC_MULTIPLE_STRESS_SEQ_SV
`define ETH_PFC_MULTIPLE_STRESS_SEQ_SV

class eth_pfc_multiple_stress_seq extends base_seq;

  `uvm_object_utils(eth_pfc_multiple_stress_seq)
  `uvm_declare_p_sequencer(eth_seqr)
  eth_cnfg cfg_h;

  uvm_status_e status;
  uvm_reg_data_t tx_vlan_enable;
  uvm_reg_data_t rx_vlan_enable;

  int num_pkts;
  int count;
  bit quanta_ctrl;

  function new(string name = "eth_pfc_multiple_stress_seq");
    super.new(name);
  endfunction

  task set_multiple_pfc_stress(ref int count, ref eth_seq_item req);

    bit [ 2:0] pfc_prio;
    bit [15:0] pfc_quanta;

    req.pfc_frame_en          = 1;
    req.tx_single_vlan_enable = 0;
    req.rx_single_vlan_enable = 0;
    req.TPID                  = 16'h0000;
    req.PCP                   = 0;
    req.DEI                   = 0;
    req.VID                   = 0;
    req.da                    = 48'h0180_C200_0001;
    req.pause_opc             = 16'h0101;
    req.ether_type            = 16'h8808;

    // ------------------------------------------------
    // Select priority: PCP 3 / PCP 4
    // ------------------------------------------------
    if (count % 2 == 0) pfc_prio = 3;
    else pfc_prio = 4;

    // ------------------------------------------------
    // Select pause quanta
    // ------------------------------------------------
    if (count == 2 || count == 3) pfc_quanta = 10;
    else if (count == 4 || count == 5) pfc_quanta = 6;
    else if (count == 6 || count == 7) pfc_quanta = 3;
    else pfc_quanta = 0;

    // ------------------------------------------------
    // Write quanta into corresponding RAL register
    // and enable the corresponding priority
    // ------------------------------------------------
    if (quanta_ctrl) write_pause_quanta_reg(pfc_prio, pfc_quanta);

    // ------------------------------------------------
    // Read back the value from RAL/DUT
    // ------------------------------------------------
    read_pause_quanta_reg(pfc_prio, pfc_quanta);

    // ------------------------------------------------
    // Drive packet from READBACK value
    // ------------------------------------------------
    req.priority_en_vector = 16'h0000;
    req.priority_en_vector[pfc_prio] = 1;

    for (int i = 0; i < 8; i++) req.pfc_pause_time[i] = 16'h0000;

    req.pfc_pause_time[pfc_prio] = pfc_quanta;

  endtask

  task body();
    if (cfg_h == null)
      `uvm_fatal("CFG_NULL", "eth_cnfg handle is null in eth_pfc_multiple_stress_seq")

    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);
      randomise_item();
      cfg_h.ral_model.tx_single_vlan_enable.read(status, tx_vlan_enable, UVM_FRONTDOOR);
      cfg_h.ral_model.rx_single_vlan_enable.read(status, rx_vlan_enable, UVM_FRONTDOOR);
      req.tx_single_vlan_enable = tx_vlan_enable[0];
      req.rx_single_vlan_enable = rx_vlan_enable[0];


      if (count >= 2 && count <= 9 && num_pkts < (no_of_pkts - 30))
        set_multiple_pfc_stress(count, req);
      else begin
        req.pfc_sel      = 0;
        req.pfc_frame_en = 0;
      end


      if (!req.pfc_frame_en && (tx_vlan_enable[0] || rx_vlan_enable[0])) begin
        req.TPID = 16'h8100;
        req.PCP  = $urandom_range(0, 7);
        req.DEI  = $urandom_range(0, 1);
        req.VID  = $urandom_range(1, 4094);
      end

      count++;
      num_pkts++;
      finish_item(req);
    end
  endtask

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

