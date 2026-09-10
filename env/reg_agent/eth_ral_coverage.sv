`ifndef ETH_REG_FIELD_COVERAGE_SV
`define ETH_REG_FIELD_COVERAGE_SV

//============================================================================
// ETH_RAL_COVERAGE
//
// Field-level functional coverage for the XLGMII MAC register map.
// One covergroup per register, each sampled only on a write to that
// register's address. Field values are sliced from wdata in write()
// and passed into the per-register sample() call.
//
// Only registers marked "Implemented" in the register test plan are
// covered here (rx_padcrc_control, tx_preamble_control,
// tx_pauseframe_holdoff_quanta, rx_custom_preamble_forward,
// rx_preamble_control, tx_pauseframe_control are waived / not implemented
// and therefore excluded).
//============================================================================

class eth_ral_coverage extends uvm_subscriber #(reg_seq_item);

  `uvm_component_utils(eth_ral_coverage)

  //==========================================================
  // Register address map (kept aligned with eth_ral_coverage)
  //==========================================================
  localparam bit [31:0] ADDR_TX_PAD_CONTROL         = 32'h0000;
  localparam bit [31:0] ADDR_TX_FRAME_MINLENGTH      = 32'h0008;
  localparam bit [31:0] ADDR_TX_FRAME_MAXLENGTH      = 32'h000C;
  localparam bit [31:0] ADDR_TX_SINGLE_VLAN_ENABLE   = 32'h0010;
  localparam bit [31:0] ADDR_TX_DOUBLE_VLAN_ENABLE   = 32'h0014;
  localparam bit [31:0] ADDR_TX_PAUSEFRAME_ENABLE    = 32'h0018;
  localparam bit [31:0] ADDR_TX_PAUSEFRAME_QUANTA    = 32'h001C;
  localparam bit [31:0] ADDR_TX_PFC_PRIORITY_ENABLE  = 32'h0020;

  localparam bit [31:0] ADDR_TX_PAUSE_QUANTA_0       = 32'h0024;
  localparam bit [31:0] ADDR_TX_PAUSE_QUANTA_1       = 32'h0028;
  localparam bit [31:0] ADDR_TX_PAUSE_QUANTA_2       = 32'h002C;
  localparam bit [31:0] ADDR_TX_PAUSE_QUANTA_3       = 32'h0030;
  localparam bit [31:0] ADDR_TX_PAUSE_QUANTA_4       = 32'h0034;
  localparam bit [31:0] ADDR_TX_PAUSE_QUANTA_5       = 32'h0038;
  localparam bit [31:0] ADDR_TX_PAUSE_QUANTA_6       = 32'h003C;
  localparam bit [31:0] ADDR_TX_PAUSE_QUANTA_7       = 32'h0040;

  localparam bit [31:0] ADDR_RX_FRAME_MINLENGTH      = 32'h0044;
  localparam bit [31:0] ADDR_RX_FRAME_MAXLENGTH      = 32'h0048;
  localparam bit [31:0] ADDR_RX_SINGLE_VLAN_ENABLE   = 32'h004C;
  localparam bit [31:0] ADDR_RX_DOUBLE_VLAN_ENABLE   = 32'h0050;
  localparam bit [31:0] ADDR_RX_PADCRC_CONTROL       = 32'h0054; // not implemented - addr map only
  localparam bit [31:0] ADDR_RX_FRAME_CONTROL        = 32'h005C;
  localparam bit [31:0] ADDR_RX_PFC_CONTROL          = 32'h0060;

  //==========================================================
  // tx_pad_control [0]
  //==========================================================
  covergroup cg_tx_pad_control with function sample(bit pad_en);
    option.per_instance = 1;
    cp_pad_en: coverpoint pad_en {
      bins disabled = {0};
      bins enabled  = {1};
    }
  endgroup



  //==========================================================
  // tx_frame_minlength [15:0]
  //==========================================================
  covergroup cg_tx_frame_minlength with function sample(bit [15:0] len);
    option.per_instance = 1;
    cp_len: coverpoint len {
      bins std_min   = {16'd64};
    }
  endgroup

  //==========================================================
  // tx_frame_maxlength [15:0]
  //==========================================================
  covergroup cg_tx_frame_maxlength with function sample(bit [15:0] len);
    option.per_instance = 1;
    cp_len: coverpoint len {
      bins std_max    = {16'd1518};
    }
  endgroup

  //==========================================================
  // tx_single_vlan_enable [0]
  //==========================================================
  covergroup cg_tx_single_vlan_enable with function sample(bit vlan_en);
    option.per_instance = 1;
    cp_en: coverpoint vlan_en { bins disabled = {0}; bins enabled = {1}; }
  endgroup

  //==========================================================
  // tx_double_vlan_enable [0]
  //==========================================================
  covergroup cg_tx_double_vlan_enable with function sample(bit vlan_en);
    option.per_instance = 1;
    cp_en: coverpoint vlan_en { bins disabled = {0}; bins enabled = {1}; }
  endgroup

  //==========================================================
  // tx_pauseframe_enable [0]
  //==========================================================
  covergroup cg_tx_pauseframe_enable with function sample(bit en);
    option.per_instance = 1;
    cp_en: coverpoint en { bins disabled = {0}; bins enabled = {1}; }
  endgroup

  //==========================================================
  // tx_pauseframe_quanta [15:0]
  //==========================================================
  covergroup cg_tx_pauseframe_quanta with function sample(bit [15:0] quanta);
    option.per_instance = 1;
    cp_quanta: coverpoint quanta {
      bins xon_quanta  = {16'd0};
      bins xoff_quanta = {[16'd1 : 16'd10]};
    }
  endgroup

  //==========================================================
  // tx_pfc_priority_enable [7:0] - one bit per priority queue
  //==========================================================
  covergroup cg_tx_pfc_priority_enable with function sample(bit [7:0] pfc_vec);
    option.per_instance = 1;
    cp_all_disabled: coverpoint (pfc_vec == 8'h00) { bins hit = {1}; }
    cp_pri0: coverpoint pfc_vec[0] { bins dis = {0}; bins en = {1}; }
    cp_pri1: coverpoint pfc_vec[1] { bins dis = {0}; bins en = {1}; }
    cp_pri2: coverpoint pfc_vec[2] { bins dis = {0}; bins en = {1}; }
    cp_pri3: coverpoint pfc_vec[3] { bins dis = {0}; bins en = {1}; }
    cp_pri4: coverpoint pfc_vec[4] { bins dis = {0}; bins en = {1}; }
    cp_pri5: coverpoint pfc_vec[5] { bins dis = {0}; bins en = {1}; }
    cp_pri6: coverpoint pfc_vec[6] { bins dis = {0}; bins en = {1}; }
    cp_pri7: coverpoint pfc_vec[7] { bins dis = {0}; bins en = {1}; }
  endgroup

  //==========================================================
  // tx_pause_quanta_0..7 [15:0] - shared covergroup, sampled per instance
  //==========================================================
  covergroup cg_tx_pause_quanta_x with function sample(int idx, bit [15:0] quanta);
    option.per_instance = 1;
    cp_idx: coverpoint idx { bins queue[] = {[0:7]}; }
    cp_quanta: coverpoint quanta {
      bins xon_quanta  = {16'd0};
      bins xoff_quanta = {[16'd1 : 16'd10]};
    }
    cross_idx_quanta: cross cp_idx, cp_quanta;
  endgroup

  //==========================================================
  // rx_frame_minlength [15:0]
  //==========================================================
  covergroup cg_rx_frame_minlength with function sample(bit [15:0] len);
    option.per_instance = 1;
    cp_len: coverpoint len {
      bins std_min   = {16'd64};
    }
  endgroup

  //==========================================================
  // rx_frame_maxlength [15:0]
  //==========================================================
  covergroup cg_rx_frame_maxlength with function sample(bit [15:0] len);
    option.per_instance = 1;
    cp_len: coverpoint len {
      bins std_max    = {16'd1518};
    }
  endgroup

  //==========================================================
  // rx_single_vlan_enable [0]
  //==========================================================
  covergroup cg_rx_single_vlan_enable with function sample(bit vlan_en);
    option.per_instance = 1;
    cp_en: coverpoint vlan_en { bins disabled = {0}; bins enabled = {1}; }
  endgroup

  //==========================================================
  // rx_double_vlan_enable [0]
  //==========================================================
  covergroup cg_rx_double_vlan_enable with function sample(bit vlan_en);
    option.per_instance = 1;
    cp_en: coverpoint vlan_en { bins disabled = {0}; bins enabled = {1}; }
  endgroup



  //==========================================================
  // rx_frame_control - fwd_control[3], fwd_pause[4]
  //                    supplementary_addr_en[19:16]
  //==========================================================
  covergroup cg_rx_frame_control with function sample(
      bit        fwd_control,
      bit        fwd_pause

  );
    option.per_instance = 1;

    cp_fwd_control: coverpoint fwd_control {
      bins drop_ctrl_frames    = {0};
      bins forward_ctrl_frames = {1};
    }
    cp_fwd_pause: coverpoint fwd_pause {
      bins drop_pause_frames    = {0};
      bins forward_pause_frames = {1};
    }

  endgroup

  //==========================================================
  // rx_pfc_control - priority enable[7:0], fwd/drop[16]
  //==========================================================
  covergroup cg_rx_pfc_control with function sample(
      bit       fwd_pfc
  );
    option.per_instance = 1;
    cp_fwd_pfc: coverpoint fwd_pfc {
      bins drop_pfc_frames    = {0};
      bins forward_pfc_frames = {1};
    }
  endgroup

  //==========================================================
  // Constructor
  //==========================================================
  function new(string name = "eth_ral_coverage", uvm_component parent = null);
    super.new(name, parent);

    cg_tx_pad_control        = new();
    cg_tx_frame_minlength      = new();
    cg_tx_frame_maxlength      = new();
    cg_tx_single_vlan_enable   = new();
    cg_tx_double_vlan_enable   = new();
    cg_tx_pauseframe_enable    = new();
    cg_tx_pauseframe_quanta    = new();
    cg_tx_pfc_priority_enable  = new();
    cg_tx_pause_quanta_x       = new();

    cg_rx_frame_minlength      = new();
    cg_rx_frame_maxlength      = new();
    cg_rx_single_vlan_enable   = new();
    cg_rx_double_vlan_enable   = new();
    cg_rx_frame_control        = new();
    cg_rx_pfc_control          = new();
  endfunction

  //==========================================================
  // Receive transaction from register monitor
  // Field coverage is sampled only on writes; wdata carries the
  // programmed value for the addressed register.
  //==========================================================
  virtual function void write(reg_seq_item t);

    bit [31:0] data;

    if (t == null || !t.write)
      return;

    data = t.wdata;

    case (t.addr)

      ADDR_TX_PAD_CONTROL:
        cg_tx_pad_control.sample(data[0]);



      ADDR_TX_FRAME_MINLENGTH:
        cg_tx_frame_minlength.sample(data[15:0]);

      ADDR_TX_FRAME_MAXLENGTH:
        cg_tx_frame_maxlength.sample(data[15:0]);

      ADDR_TX_SINGLE_VLAN_ENABLE:
        cg_tx_single_vlan_enable.sample(data[0]);

      ADDR_TX_DOUBLE_VLAN_ENABLE:
        cg_tx_double_vlan_enable.sample(data[0]);

      ADDR_TX_PAUSEFRAME_ENABLE:
        cg_tx_pauseframe_enable.sample(data[0]);

      ADDR_TX_PAUSEFRAME_QUANTA:
        cg_tx_pauseframe_quanta.sample(data[15:0]);

      ADDR_TX_PFC_PRIORITY_ENABLE:
        cg_tx_pfc_priority_enable.sample(data[7:0]);

      ADDR_TX_PAUSE_QUANTA_0: cg_tx_pause_quanta_x.sample(0, data[15:0]);
      ADDR_TX_PAUSE_QUANTA_1: cg_tx_pause_quanta_x.sample(1, data[15:0]);
      ADDR_TX_PAUSE_QUANTA_2: cg_tx_pause_quanta_x.sample(2, data[15:0]);
      ADDR_TX_PAUSE_QUANTA_3: cg_tx_pause_quanta_x.sample(3, data[15:0]);
      ADDR_TX_PAUSE_QUANTA_4: cg_tx_pause_quanta_x.sample(4, data[15:0]);
      ADDR_TX_PAUSE_QUANTA_5: cg_tx_pause_quanta_x.sample(5, data[15:0]);
      ADDR_TX_PAUSE_QUANTA_6: cg_tx_pause_quanta_x.sample(6, data[15:0]);
      ADDR_TX_PAUSE_QUANTA_7: cg_tx_pause_quanta_x.sample(7, data[15:0]);

      ADDR_RX_FRAME_MINLENGTH:
        cg_rx_frame_minlength.sample(data[15:0]);

      ADDR_RX_FRAME_MAXLENGTH:
        cg_rx_frame_maxlength.sample(data[15:0]);

      ADDR_RX_SINGLE_VLAN_ENABLE:
        cg_rx_single_vlan_enable.sample(data[0]);

      ADDR_RX_DOUBLE_VLAN_ENABLE:
        cg_rx_double_vlan_enable.sample(data[0]);



 

      ADDR_RX_FRAME_CONTROL:
        cg_rx_frame_control.sample(data[3], data[4]);

      ADDR_RX_PFC_CONTROL:
        cg_rx_pfc_control.sample(data[16]);

      default: ; // address not part of the implemented register set

    endcase

  endfunction

  //==========================================================
  // Report combined field coverage
  //==========================================================
  function void report_phase(uvm_phase phase);
    real total, cnt;

    super.report_phase(phase);

    total = 0; cnt = 0;

    `uvm_info("FUNC_COV", $sformatf("tx_pad_control         = %0.2f%%", cg_tx_pad_control.get_inst_coverage()), UVM_NONE)
    `uvm_info("FUNC_COV", $sformatf("tx_frame_minlength      = %0.2f%%", cg_tx_frame_minlength.get_inst_coverage()), UVM_NONE)
    `uvm_info("FUNC_COV", $sformatf("tx_frame_maxlength      = %0.2f%%", cg_tx_frame_maxlength.get_inst_coverage()), UVM_NONE)
    `uvm_info("FUNC_COV", $sformatf("tx_single_vlan_enable   = %0.2f%%", cg_tx_single_vlan_enable.get_inst_coverage()), UVM_NONE)
    `uvm_info("FUNC_COV", $sformatf("tx_double_vlan_enable   = %0.2f%%", cg_tx_double_vlan_enable.get_inst_coverage()), UVM_NONE)
    `uvm_info("FUNC_COV", $sformatf("tx_pauseframe_enable    = %0.2f%%", cg_tx_pauseframe_enable.get_inst_coverage()), UVM_NONE)
    `uvm_info("FUNC_COV", $sformatf("tx_pauseframe_quanta    = %0.2f%%", cg_tx_pauseframe_quanta.get_inst_coverage()), UVM_NONE)
    `uvm_info("FUNC_COV", $sformatf("tx_pfc_priority_enable  = %0.2f%%", cg_tx_pfc_priority_enable.get_inst_coverage()), UVM_NONE)
    `uvm_info("FUNC_COV", $sformatf("tx_pause_quanta_x       = %0.2f%%", cg_tx_pause_quanta_x.get_inst_coverage()), UVM_NONE)

    `uvm_info("FUNC_COV", $sformatf("rx_frame_minlength      = %0.2f%%", cg_rx_frame_minlength.get_inst_coverage()), UVM_NONE)
    `uvm_info("FUNC_COV", $sformatf("rx_frame_maxlength      = %0.2f%%", cg_rx_frame_maxlength.get_inst_coverage()), UVM_NONE)
    `uvm_info("FUNC_COV", $sformatf("rx_single_vlan_enable   = %0.2f%%", cg_rx_single_vlan_enable.get_inst_coverage()), UVM_NONE)
    `uvm_info("FUNC_COV", $sformatf("rx_double_vlan_enable   = %0.2f%%", cg_rx_double_vlan_enable.get_inst_coverage()), UVM_NONE)
    `uvm_info("FUNC_COV", $sformatf("rx_frame_control        = %0.2f%%", cg_rx_frame_control.get_inst_coverage()), UVM_NONE)
    `uvm_info("FUNC_COV", $sformatf("rx_pfc_control          = %0.2f%%", cg_rx_pfc_control.get_inst_coverage()), UVM_NONE)

    `uvm_info("FUNC_COV", $sformatf("Overall Register Field Coverage = %0.2f%%", $get_coverage()), UVM_NONE)
  endfunction

endclass

`endif

