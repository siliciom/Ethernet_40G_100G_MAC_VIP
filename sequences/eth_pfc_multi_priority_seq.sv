
//******************************************************************//
//              ETH PFC MULTIPLE PRIORITY XOFF SEQUENCE
//
// MAC[0]:
//   - Normal traffic
//   - Every 20th packet generates a PFC XOFF frame
//   - Enables exactly 4 random priorities
//   - Random pause quanta
//   - PFC configuration is written/read through RAL registers
//
// MAC[1]:
//   - Normal traffic only
//   - No PFC
//
// PFC frames are always untagged.
// Normal traffic follows the VLAN RAL configuration.
//
//******************************************************************//

`ifndef ETH_PFC_MULTI_PRIORITY_SEQ_SV
`define ETH_PFC_MULTI_PRIORITY_SEQ_SV

class eth_pfc_multi_priority_seq extends base_seq;

  `uvm_object_utils(eth_pfc_multi_priority_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  eth_cnfg cfg_h;

  uvm_status_e status;
  uvm_reg_data_t tx_vlan_enable;
  uvm_reg_data_t rx_vlan_enable;

  int num_pkts;
  int count;

  bit quanta_ctrl;
  bit basic_pfc_en;

  // Four selected PFC priorities
  bit [2:0] pfc_prio[4];

  // Random pause quanta
  bit [15:0] pfc_quanta;

  function new(string name = "eth_pfc_multi_priority_seq");
    super.new(name);
  endfunction


  //****************************************************************//
  // BODY
  //****************************************************************//

  task body();

    if (cfg_h == null)
      `uvm_fatal("CFG_NULL", "eth_cnfg handle is null in eth_pfc_multi_priority_seq")

    repeat (no_of_pkts) begin

      int        pri             [$];
      bit [31:0] pfc_enable_mask;
      bit        pfc_packet;

      req = eth_seq_item::type_id::create("req");

      start_item(req);

      // ------------------------------------------------------------
      // Randomize normal packet fields first
      // ------------------------------------------------------------
      randomise_item();

      // ------------------------------------------------------------
      // Read VLAN configuration from RAL
      // ------------------------------------------------------------
      cfg_h.ral_model.tx_single_vlan_enable.read(status, tx_vlan_enable, UVM_FRONTDOOR);

      cfg_h.ral_model.rx_single_vlan_enable.read(status, rx_vlan_enable, UVM_FRONTDOOR);

      req.tx_single_vlan_enable = tx_vlan_enable[0];
      req.rx_single_vlan_enable = rx_vlan_enable[0];


      // ------------------------------------------------------------
      // Default = normal packet
      // ------------------------------------------------------------
      pfc_packet = 0;
      req.pfc_frame_en = 0;


      // ============================================================
      // PFC PACKET
      // ============================================================

      if (basic_pfc_en &&count != 0 &&((count + 1) % 20 == 0) &&num_pkts < (no_of_pkts - 30)) begin

        pfc_packet = 1;

        // ----------------------------------------------------------
        // Random pause quanta
        // ----------------------------------------------------------
        void'(std::randomize(pfc_quanta) with {pfc_quanta inside {[1 : 10]};});


        // ----------------------------------------------------------
        // Create list containing all 8 priorities
        // ----------------------------------------------------------
        pri.delete();

        for (int i = 0; i < 8; i++) pri.push_back(i);

        // Randomize the order
        pri.shuffle();


        // ----------------------------------------------------------
        // Select exactly 4 UNIQUE priorities
        // ----------------------------------------------------------
        for (int i = 0; i < 4; i++) pfc_prio[i] = pri[i];


        // ----------------------------------------------------------
        // Create PFC priority enable mask
        //
        // Example:
        // pfc_prio = {3,6,1,7}
        //
        // mask = 10001010
        //       priorities 7,6,3,1 enabled
        // ----------------------------------------------------------
        pfc_enable_mask = 32'h0000_0000;

        for (int i = 0; i < 4; i++) pfc_enable_mask[pfc_prio[i]] = 1'b1;


        // ----------------------------------------------------------
        // WRITE pause quanta to RAL registers
        // and enable all 4 selected priorities
        // ----------------------------------------------------------
        if (quanta_ctrl) write_multi_pause_quanta_reg(pfc_prio, pfc_quanta, pfc_enable_mask);


        // ----------------------------------------------------------
        // READ pause quanta back from RAL registers
        // ----------------------------------------------------------
        read_multi_pause_quanta_reg(pfc_prio);


        // ----------------------------------------------------------
        // Identify this packet as PFC
        // ----------------------------------------------------------
        req.pfc_frame_en = 1;


        // ----------------------------------------------------------
        // PFC is ALWAYS UNTAGGED
        // ----------------------------------------------------------
        req.tx_single_vlan_enable = 0;
        req.rx_single_vlan_enable = 0;

        req.TPID = 16'h0000;
        req.PCP = 0;
        req.DEI = 0;
        req.VID = 0;


        // ----------------------------------------------------------
        // PFC Destination MAC
        // ----------------------------------------------------------
        req.da = 48'h0180_C200_0001;


        // ----------------------------------------------------------
        // MAC Control EtherType
        // ----------------------------------------------------------
        req.ether_type = 16'h8808;


        // ----------------------------------------------------------
        // PFC Opcode
        // ----------------------------------------------------------
        req.pause_opc = 16'h0101;


        // ----------------------------------------------------------
        // Set exactly 4 selected priorities in sequence item
        // ----------------------------------------------------------
        req.priority_en_vector = 16'h0000;

        for (int i = 0; i < 4; i++) req.priority_en_vector[pfc_prio[i]] = 1'b1;


        // ----------------------------------------------------------
        // Clear all pause times first
        // ----------------------------------------------------------
        foreach (req.pfc_pause_time[i]) req.pfc_pause_time[i] = 16'h0000;


        // ----------------------------------------------------------
        // Put the READ-BACK quanta into selected priorities
        //
        // pfc_quanta[i] was updated by
        // read_multi_pause_quanta_reg()
        // ----------------------------------------------------------
        for (int i = 0; i < 4; i++) req.pfc_pause_time[pfc_prio[i]] = pfc_quanta;


        // ----------------------------------------------------------
        // Keep original DA behavior
        // ----------------------------------------------------------
        if ($urandom_range(0, 1)) req.da = 48'h0180_C200_0001;

      end


      // ============================================================
      // NORMAL PACKET
      // ============================================================

      if (!pfc_packet) begin

        req.pfc_frame_en = 0;

        // ----------------------------------------------------------
        // Normal traffic follows VLAN RAL configuration
        // ----------------------------------------------------------
        if (tx_vlan_enable[0] || rx_vlan_enable[0]) begin

          req.TPID = 16'h8100;
          req.PCP  = $urandom_range(0, 7);
          req.DEI  = 0;
          req.VID  = 0;

        end

      end


      // ------------------------------------------------------------
      // Packet counters
      // ------------------------------------------------------------
      count++;
      num_pkts++;

      finish_item(req);

    end

  endtask


  //****************************************************************//
  // WRITE MULTIPLE PFC PRIORITIES
  //
  // Writes the same pause quanta into the four selected priority
  // registers and writes one combined enable mask.
  //
  // Example:
  //
  // Selected priorities = 1,3,5,7
  //
  // tx_pause_quanta_1 = quanta
  // tx_pause_quanta_3 = quanta
  // tx_pause_quanta_5 = quanta
  // tx_pause_quanta_7 = quanta
  //
  // tx_pfc_priority_enable = 32'h000000AA
  //
  //****************************************************************//

  task write_multi_pause_quanta_reg(bit [2:0] prio[4], bit [15:0] quanta, bit [31:0] enable_mask);

    uvm_status_e wstatus;

    // --------------------------------------------------------------
    // Priority 0
    // --------------------------------------------------------------
    if (prio[0] == 0) cfg_h.ral_model.tx_pause_quanta_0.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[1] == 0) cfg_h.ral_model.tx_pause_quanta_0.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[2] == 0) cfg_h.ral_model.tx_pause_quanta_0.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[3] == 0) cfg_h.ral_model.tx_pause_quanta_0.write(wstatus, quanta, UVM_FRONTDOOR);


    // --------------------------------------------------------------
    // Priority 1
    // --------------------------------------------------------------
    if (prio[0] == 1) cfg_h.ral_model.tx_pause_quanta_1.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[1] == 1) cfg_h.ral_model.tx_pause_quanta_1.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[2] == 1) cfg_h.ral_model.tx_pause_quanta_1.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[3] == 1) cfg_h.ral_model.tx_pause_quanta_1.write(wstatus, quanta, UVM_FRONTDOOR);


    // --------------------------------------------------------------
    // Priority 2
    // --------------------------------------------------------------
    if (prio[0] == 2) cfg_h.ral_model.tx_pause_quanta_2.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[1] == 2) cfg_h.ral_model.tx_pause_quanta_2.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[2] == 2) cfg_h.ral_model.tx_pause_quanta_2.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[3] == 2) cfg_h.ral_model.tx_pause_quanta_2.write(wstatus, quanta, UVM_FRONTDOOR);


    // --------------------------------------------------------------
    // Priority 3
    // --------------------------------------------------------------
    if (prio[0] == 3) cfg_h.ral_model.tx_pause_quanta_3.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[1] == 3) cfg_h.ral_model.tx_pause_quanta_3.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[2] == 3) cfg_h.ral_model.tx_pause_quanta_3.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[3] == 3) cfg_h.ral_model.tx_pause_quanta_3.write(wstatus, quanta, UVM_FRONTDOOR);


    // --------------------------------------------------------------
    // Priority 4
    // --------------------------------------------------------------
    if (prio[0] == 4) cfg_h.ral_model.tx_pause_quanta_4.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[1] == 4) cfg_h.ral_model.tx_pause_quanta_4.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[2] == 4) cfg_h.ral_model.tx_pause_quanta_4.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[3] == 4) cfg_h.ral_model.tx_pause_quanta_4.write(wstatus, quanta, UVM_FRONTDOOR);


    // --------------------------------------------------------------
    // Priority 5
    // --------------------------------------------------------------
    if (prio[0] == 5) cfg_h.ral_model.tx_pause_quanta_5.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[1] == 5) cfg_h.ral_model.tx_pause_quanta_5.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[2] == 5) cfg_h.ral_model.tx_pause_quanta_5.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[3] == 5) cfg_h.ral_model.tx_pause_quanta_5.write(wstatus, quanta, UVM_FRONTDOOR);


    // --------------------------------------------------------------
    // Priority 6
    // --------------------------------------------------------------
    if (prio[0] == 6) cfg_h.ral_model.tx_pause_quanta_6.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[1] == 6) cfg_h.ral_model.tx_pause_quanta_6.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[2] == 6) cfg_h.ral_model.tx_pause_quanta_6.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[3] == 6) cfg_h.ral_model.tx_pause_quanta_6.write(wstatus, quanta, UVM_FRONTDOOR);


    // --------------------------------------------------------------
    // Priority 7
    // --------------------------------------------------------------
    if (prio[0] == 7) cfg_h.ral_model.tx_pause_quanta_7.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[1] == 7) cfg_h.ral_model.tx_pause_quanta_7.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[2] == 7) cfg_h.ral_model.tx_pause_quanta_7.write(wstatus, quanta, UVM_FRONTDOOR);

    else if (prio[3] == 7) cfg_h.ral_model.tx_pause_quanta_7.write(wstatus, quanta, UVM_FRONTDOOR);


    // --------------------------------------------------------------
    // Enable the four selected priorities
    // --------------------------------------------------------------
    cfg_h.ral_model.tx_pfc_priority_enable.write(wstatus, enable_mask, UVM_FRONTDOOR);

  endtask


  //****************************************************************//
  // READ MULTIPLE PFC PRIORITIES
  //
  // Reads the quanta from the RAL registers.
  //
  // Since the same pfc_quanta was written to all four priorities,
  // readback verifies the actual programmed value.
  //
  //****************************************************************//

  task read_multi_pause_quanta_reg(bit [2:0] prio[4]);

    uvm_status_e   rstatus;
    uvm_reg_data_t rdata;

    for (int i = 0; i < 4; i++) begin

      case (prio[i])

        0: cfg_h.ral_model.tx_pause_quanta_0.read(rstatus, rdata, UVM_FRONTDOOR);

        1: cfg_h.ral_model.tx_pause_quanta_1.read(rstatus, rdata, UVM_FRONTDOOR);

        2: cfg_h.ral_model.tx_pause_quanta_2.read(rstatus, rdata, UVM_FRONTDOOR);

        3: cfg_h.ral_model.tx_pause_quanta_3.read(rstatus, rdata, UVM_FRONTDOOR);

        4: cfg_h.ral_model.tx_pause_quanta_4.read(rstatus, rdata, UVM_FRONTDOOR);

        5: cfg_h.ral_model.tx_pause_quanta_5.read(rstatus, rdata, UVM_FRONTDOOR);

        6: cfg_h.ral_model.tx_pause_quanta_6.read(rstatus, rdata, UVM_FRONTDOOR);

        7: cfg_h.ral_model.tx_pause_quanta_7.read(rstatus, rdata, UVM_FRONTDOOR);

      endcase

      // ------------------------------------------------------------
      // Store actual register readback
      //
      // Since all four priorities were programmed with the same
      // quanta, the final value should be the same.
      // ------------------------------------------------------------
      pfc_quanta = rdata[15:0];

    end

  endtask


endclass

`endif


