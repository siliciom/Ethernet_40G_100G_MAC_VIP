//******************************************************************//
//              ETH PFC MULTIPLE STRESS SEQUENCE
//
// Alternates PCP 3 / PCP 4 across consecutive packet count and
// ramps pause quanta:
//
//              10 -> 6 -> 3 -> 0
//
// Count window:
//
//              count 2,3 -> PCP 3/4 -> quanta 10
//              count 4,5 -> PCP 3/4 -> quanta 6
//              count 6,7 -> PCP 3/4 -> quanta 3
//              count 8,9 -> PCP 3/4 -> quanta 0 (XON)
//
// PFC configuration is programmed through RAL registers and the
// value is read back before driving the sequence item.
//
//******************************************************************//

`ifndef ETH_PFC_STRESS_SEQ_SV
`define ETH_PFC_STRESS_SEQ_SV

class eth_pfc_stress_seq extends base_seq;

  `uvm_object_utils(eth_pfc_stress_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  eth_cnfg cfg_h;

  uvm_status_e   status;
  uvm_reg_data_t tx_vlan_enable;
  uvm_reg_data_t rx_vlan_enable;

  int num_pkts;
  int count;

  bit quanta_ctrl;

  function new(string name = "eth_pfc_stress_seq");
    super.new(name);
  endfunction


  //****************************************************************//
  // SET MULTIPLE PFC STRESS
  //
  // Selects PCP 3 / PCP 4 depending on packet count.
  //
  // count 2,3 -> quanta 10
  // count 4,5 -> quanta 6
  // count 6,7 -> quanta 3
  // count 8,9 -> quanta 0
  //
  //****************************************************************//

  task set_multiple_pfc_stress(
    ref int count,
    ref eth_seq_item req
  );

    bit [2:0]  pfc_prio;
    bit [15:0] pfc_quanta;


    //==============================================================
    // PFC FRAME CONFIGURATION
    //==============================================================

    req.pfc_frame_en          = 1'b1;

    // PFC frame is always untagged
    req.tx_single_vlan_enable = 1'b0;
    req.rx_single_vlan_enable = 1'b0;

    req.TPID                  = 16'h0000;
    req.PCP                   = 3'd0;
    req.DEI                   = 1'b0;
    req.VID                   = 12'd0;

    // PFC destination MAC
    req.da                    = 48'h0180_C200_0001;

    // PFC opcode
    req.pause_opc             = 16'h0101;

    // MAC Control EtherType
    req.ether_type            = 16'h8808;


    //==============================================================
    // SELECT PRIORITY
    //
    // Even count -> PCP 3
    // Odd  count -> PCP 4
    //
    // Example:
    //
    // count 2 -> PCP 3
    // count 3 -> PCP 4
    // count 4 -> PCP 3
    // count 5 -> PCP 4
    // ...
    //==============================================================

    if (count % 2 == 0)
      pfc_prio = 3;
    else
      pfc_prio = 4;


    //==============================================================
    // SELECT PAUSE QUANTA
    //
    // 2,3 -> 10
    // 4,5 -> 6
    // 6,7 -> 3
    // 8,9 -> 0
    //==============================================================

    if ((count == 2) || (count == 3))
      pfc_quanta = 16'd10;

    else if ((count == 4) || (count == 5))
      pfc_quanta = 16'd6;

    else if ((count == 6) || (count == 7))
      pfc_quanta = 16'd3;

    else
      pfc_quanta = 16'd0;


    //==============================================================
    // WRITE PAUSE QUANTA INTO RAL REGISTER
    //
    // Only write when quanta_ctrl is enabled.
    //==============================================================

    if (quanta_ctrl)
      write_pause_quanta_reg(
        pfc_prio,
        pfc_quanta
      );


    //==============================================================
    // READ BACK PAUSE QUANTA FROM RAL REGISTER
    //
    // req will use the actual register value.
    //==============================================================

    read_pause_quanta_reg(
      pfc_prio,
      pfc_quanta
    );


    //==============================================================
    // PRIORITY ENABLE VECTOR
    //
    // Only the currently selected PCP is enabled.
    //
    // PCP 3 -> 0000_0000_0000_1000
    // PCP 4 -> 0000_0000_0001_0000
    //==============================================================

    req.priority_en_vector = 16'h0000;

    req.priority_en_vector[pfc_prio] = 1'b1;


    //==============================================================
    // CLEAR ALL PAUSE TIMES
    //==============================================================

    for (int i = 0; i < 8; i++)
      req.pfc_pause_time[i] = 16'h0000;


    //==============================================================
    // DRIVE SELECTED PCP WITH READ-BACK QUANTA
    //==============================================================

    req.pfc_pause_time[pfc_prio] = pfc_quanta;


    //==============================================================
    // TEMP PCP
    //
    // Useful if the driver/monitor uses temp_pcp for identifying
    // the active priority.
    //==============================================================

    req.temp_pcp = pfc_prio;


    //==============================================================
    // DEBUG
    //==============================================================

    `uvm_info(
      "PFC_MULTIPLE_STRESS",
      $sformatf(
        "PFC STRESS: COUNT=%0d PCP=%0d QUANTA=%0d VECTOR=%04h",
        count,
        pfc_prio,
        pfc_quanta,
        req.priority_en_vector
      ),
      UVM_LOW
    )

  endtask


  //****************************************************************//
  // BODY
  //****************************************************************//

  task body();

    if (cfg_h == null)
      `uvm_fatal(
        "CFG_NULL",
        "eth_cnfg handle is null in eth_pfc_multiple_stress_seq"
      )


    num_pkts = 0;
    count    = 0;


    //==============================================================
    // GENERATE PACKETS
    //==============================================================

    repeat (no_of_pkts) begin

      req = eth_seq_item::type_id::create("req");

      start_item(req);

      //============================================================
      // RANDOMIZE NORMAL PACKET FIELDS
      //============================================================

      randomise_item();


      //============================================================
      // READ VLAN CONFIGURATION FROM RAL
      //============================================================

      cfg_h.ral_model.tx_single_vlan_enable.read(
        status,
        tx_vlan_enable,
        UVM_FRONTDOOR
      );

      cfg_h.ral_model.rx_single_vlan_enable.read(
        status,
        rx_vlan_enable,
        UVM_FRONTDOOR
      );


      req.tx_single_vlan_enable = tx_vlan_enable[0];
      req.rx_single_vlan_enable = rx_vlan_enable[0];


      //============================================================
      // PFC STRESS WINDOW
      //
      // count = 2 through 9
      //
      // Keep enough packets at the end of the test so that the
      // stress sequence does not consume the final packets.
      //============================================================

      if ((count >= 2) &&
          (count <= 9) &&
          (num_pkts < (no_of_pkts - 30))) begin

        set_multiple_pfc_stress(
          count,
          req
        );

      end


      //============================================================
      // NORMAL PACKET
      //============================================================

      else begin

        // ---------------------------------------------------------
        // Explicitly clear PFC fields
        // ---------------------------------------------------------

        req.pfc_frame_en = 1'b0;

        req.pfc_sel = 1'b0;

        req.priority_en_vector = 16'h0000;

        for (int i = 0; i < 8; i++)
          req.pfc_pause_time[i] = 16'h0000;


        // ---------------------------------------------------------
        // Normal packet follows VLAN RAL configuration
        // ---------------------------------------------------------

        if (tx_vlan_enable[0] || rx_vlan_enable[0]) begin

          req.TPID = 16'h8100;

          req.PCP = $urandom_range(0,7);

          req.DEI = $urandom_range(0,1);

          req.VID = $urandom_range(1,4094);

        end


        `uvm_info(
          "PFC_MULTIPLE_STRESS",
          $sformatf(
            "NORMAL: PKT=%0d COUNT=%0d TX_VLAN=%0d RX_VLAN=%0d PCP=%0d VID=%0d",
            num_pkts + 1,
            count,
            tx_vlan_enable[0],
            rx_vlan_enable[0],
            req.PCP,
            req.VID
          ),
          UVM_LOW
        )

      end


      //============================================================
      // UPDATE COUNTERS
      //============================================================

      count++;
      num_pkts++;


      finish_item(req);

    end

  endtask


  //****************************************************************//
  // WRITE PAUSE QUANTA REGISTER
  //
  // Writes the selected priority's pause quanta register.
  //
  // Also enables that priority in tx_pfc_priority_enable.
  //
  //****************************************************************//

  task write_pause_quanta_reg(
    bit [2:0]  prio,
    bit [15:0] quanta
  );

    uvm_status_e   wstatus;
    uvm_reg_data_t enable_mask;


    //==============================================================
    // WRITE PAUSE QUANTA
    //==============================================================

    case (prio)

      0:
        cfg_h.ral_model.tx_pause_quanta_0.write(
          wstatus,
          quanta,
          UVM_FRONTDOOR
        );

      1:
        cfg_h.ral_model.tx_pause_quanta_1.write(
          wstatus,
          quanta,
          UVM_FRONTDOOR
        );

      2:
        cfg_h.ral_model.tx_pause_quanta_2.write(
          wstatus,
          quanta,
          UVM_FRONTDOOR
        );

      3:
        cfg_h.ral_model.tx_pause_quanta_3.write(
          wstatus,
          quanta,
          UVM_FRONTDOOR
        );

      4:
        cfg_h.ral_model.tx_pause_quanta_4.write(
          wstatus,
          quanta,
          UVM_FRONTDOOR
        );

      5:
        cfg_h.ral_model.tx_pause_quanta_5.write(
          wstatus,
          quanta,
          UVM_FRONTDOOR
        );

      6:
        cfg_h.ral_model.tx_pause_quanta_6.write(
          wstatus,
          quanta,
          UVM_FRONTDOOR
        );

      7:
        cfg_h.ral_model.tx_pause_quanta_7.write(
          wstatus,
          quanta,
          UVM_FRONTDOOR
        );

    endcase


    //==============================================================
    // ENABLE SELECTED PRIORITY
    //
    // PCP 3 -> 0000_0000_0000_1000
    // PCP 4 -> 0000_0000_0001_0000
    //==============================================================

    enable_mask = (32'h1 << prio);

    cfg_h.ral_model.tx_pfc_priority_enable.write(
      wstatus,
      enable_mask,
      UVM_FRONTDOOR
    );


    `uvm_info(
      "PFC_RAL_WRITE",
      $sformatf(
        "WRITE: PCP=%0d QUANTA=%0d ENABLE_MASK=%08h",
        prio,
        quanta,
        enable_mask
      ),
      UVM_LOW
    )

  endtask


  //****************************************************************//
  // READ PAUSE QUANTA REGISTER
  //
  // Reads the actual value from the RAL/DUT register.
  //
  //****************************************************************//

  task read_pause_quanta_reg(
    bit [2:0]  prio,
    ref bit [15:0] quanta_out
  );

    uvm_status_e   rstatus;
    uvm_reg_data_t rdata;


    case (prio)

      0:
        cfg_h.ral_model.tx_pause_quanta_0.read(
          rstatus,
          rdata,
          UVM_FRONTDOOR
        );

      1:
        cfg_h.ral_model.tx_pause_quanta_1.read(
          rstatus,
          rdata,
          UVM_FRONTDOOR
        );

      2:
        cfg_h.ral_model.tx_pause_quanta_2.read(
          rstatus,
          rdata,
          UVM_FRONTDOOR
        );

      3:
        cfg_h.ral_model.tx_pause_quanta_3.read(
          rstatus,
          rdata,
          UVM_FRONTDOOR
        );

      4:
        cfg_h.ral_model.tx_pause_quanta_4.read(
          rstatus,
          rdata,
          UVM_FRONTDOOR
        );

      5:
        cfg_h.ral_model.tx_pause_quanta_5.read(
          rstatus,
          rdata,
          UVM_FRONTDOOR
        );

      6:
        cfg_h.ral_model.tx_pause_quanta_6.read(
          rstatus,
          rdata,
          UVM_FRONTDOOR
        );

      7:
        cfg_h.ral_model.tx_pause_quanta_7.read(
          rstatus,
          rdata,
          UVM_FRONTDOOR
        );

    endcase


    //==============================================================
    // RETURN READ-BACK VALUE
    //==============================================================

    quanta_out = rdata[15:0];


    `uvm_info(
      "PFC_RAL_READ",
      $sformatf(
        "READ: PCP=%0d QUANTA=%0d",
        prio,
        quanta_out
      ),
      UVM_LOW
    )

  endtask


endclass

`endif

