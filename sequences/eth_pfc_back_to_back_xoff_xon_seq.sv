//******************************************************************//
//                  ETH PFC XOFF...GAP...XON SEQUENCE
//
// Generates PFC XOFF, then a 3-frame gap of normal packets, then
// PFC XON for the same priority. Uses the same RAL register
// write/read-back approach as eth_pfc_basic_seq (tx_pause_quanta_N +
// tx_pfc_priority_enable). XON fires deterministically once the gap
// count reaches zero -- it does not depend on another random pfc_en
// draw, so every XOFF is guaranteed to get its matching XON.
//******************************************************************//

`ifndef ETH_PFC_BACK_TO_BACK_XOFF_XON_SEQ_SV
`define ETH_PFC_BACK_TO_BACK_XOFF_XON_SEQ_SV

class eth_pfc_back_to_back_xoff_xon_seq extends base_seq;
    uvm_status_e   wstatus;
    uvm_reg_data_t enable_mask, data;

  `uvm_object_utils(eth_pfc_back_to_back_xoff_xon_seq)
  `uvm_declare_p_sequencer(eth_seqr)

  eth_cnfg              cfg_h;
  int                   wt_dist0;
  int                   wt_dist1;
  bit                   pfc_en;
  bit                   xoff_xon_pfc_en;
  bit                   quanta_ctrl;
  bit            [ 2:0] forced_prio;

  uvm_status_e          status;
  uvm_reg_data_t        tx_vlan_enable;
  uvm_reg_data_t        rx_vlan_enable;

  int                   num_pkts;

  bit                   waiting_for_xon;
  bit            [ 2:0] paused_prio;
  bit            [ 2:0] pfc_prio;
  bit            [15:0] pfc_quanta;

  // Gap-between-XOFF-and-XON control. GAP_PKTS is the number of
  // normal packets sent between XOFF and its matching XON.
  int                   GAP_PKTS               = 3;
  int                   gap_remaining;

  bit                   pcp_xoff_xon_en;
  static bit     [ 2:0] shared_pfc_prio;
  static int            shared_pfc_credits;
  static int            shared_min_follow_pkts = 3;
  static int            shared_max_follow_pkts = 5;

  function new(string name = "eth_pfc_back_to_back_xoff_xon_seq");
    super.new(name);
  endfunction

  task body();

    if (cfg_h == null)
      `uvm_fatal("CFG_NULL", "eth_cnfg handle is null in eth_pfc_back_to_back_xoff_xon_seq")

    cfg_h.ral_model.tx_single_vlan_enable.read(status, tx_vlan_enable, UVM_FRONTDOOR);
    cfg_h.ral_model.rx_single_vlan_enable.read(status, rx_vlan_enable, UVM_FRONTDOOR);

    repeat (no_of_pkts) begin
      req = eth_seq_item::type_id::create("req");
      start_item(req);

      randomise_item();

      req.tx_single_vlan_enable = tx_vlan_enable[0];
      req.rx_single_vlan_enable = rx_vlan_enable[0];

      // Only roll the dice for a *new* XOFF if we're not already
      // mid-sequence waiting to send the matching XON.
      if (!waiting_for_xon)
        void'(std::randomize(
            pfc_en
        ) with {
          pfc_en dist {
            0 := wt_dist0,
            1 := wt_dist1
          };
        });

      // ---------------------------------------------------------
      // Decide whether this packet is: new XOFF / gap filler /
      // due XON / plain normal packet.
      // ---------------------------------------------------------

      // Case 1: we're waiting for XON and the gap has elapsed ->
      // force XON now, deterministically, regardless of pfc_en.
      if (waiting_for_xon && gap_remaining == 0) begin

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
        req.priority_en_vector    = '0;

        pfc_quanta                = 16'h0000;
        if (quanta_ctrl) write_pause_quanta_reg(pfc_prio, pfc_quanta);
        read_pause_quanta_reg(pfc_prio, pfc_quanta);

        req.priority_en_vector[pfc_prio] = 1'b1;
        for (int i = 0; i < 8; i++) req.pfc_pause_time[i] = 16'h0000;
        req.pfc_pause_time[pfc_prio] = pfc_quanta;

        waiting_for_xon = 0;

        `uvm_info("PFC_B2B",
                  $sformatf("XON generated: PCP=%0d Pause=%0d", paused_prio, pfc_quanta), UVM_LOW)
      end  // Case 2: mid-gap (already fired XOFF, XON not due yet) ->
           // plain normal packet, decrement the gap counter.
      else if (waiting_for_xon && gap_remaining > 0) begin

        req.pfc_frame_en = 0;
        fixed_ethertype_item($urandom_range(42, 64));
        gap_remaining--;

        if (shared_pfc_credits > 0) begin
          forced_prio = shared_pfc_prio;
          shared_pfc_credits--;
        end else begin
          forced_prio = $urandom_range(0, 7);
        end
      end  // Case 3: not waiting on anything -> roll for a new XOFF.
      else if (xoff_xon_pfc_en && pfc_en && num_pkts < (no_of_pkts - 30)) begin

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
        req.priority_en_vector    = '0;

        void'(std::randomize(pfc_prio) with {pfc_prio inside {[0 : 7]};});
        forced_prio = pfc_prio;
        paused_prio = pfc_prio;
        void'(std::randomize(pfc_quanta) with {pfc_quanta inside {[1 : 10]};});

        if (quanta_ctrl == 1) write_pause_quanta_reg(pfc_prio, pfc_quanta);
        read_pause_quanta_reg(pfc_prio, pfc_quanta);

        shared_pfc_prio = forced_prio;
        shared_pfc_credits = $urandom_range(shared_min_follow_pkts, shared_max_follow_pkts);

        req.priority_en_vector[pfc_prio] = 1'b1;
        for (int i = 0; i < 8; i++) req.pfc_pause_time[i] = 16'h0000;
        req.pfc_pause_time[pfc_prio] = pfc_quanta;

        waiting_for_xon = 1;
        gap_remaining = GAP_PKTS;  // exactly 3 frames before XON fires
      end  // Case 4: plain normal packet (no PFC activity in flight).
      else begin

        req.pfc_frame_en = 0;
        fixed_ethertype_item($urandom_range(42, 64));

        if (shared_pfc_credits > 0) begin
          forced_prio = shared_pfc_prio;
          shared_pfc_credits--;
        end else begin
          forced_prio = $urandom_range(0, 7);
        end
        for (int i = 0; i < 8; i++) 
          req.priority_en_vector[i] = 1'b0;
        cfg_h.ral_model.tx_pfc_priority_enable.write(wstatus, 32'h0, UVM_FRONTDOOR);
      end

      // ---------------------------------------------------------
      // VLAN fields
      // ---------------------------------------------------------
      if (tx_vlan_enable[0] || rx_vlan_enable[0]) begin
        req.TPID = 16'h8100;
        req.PCP  = forced_prio;
        req.DEI  = 0;
        req.VID  = 0;
      end

      num_pkts++;
    `uvm_info("",$sformatf("3333333333333333333333333333 -- %0h",enable_mask),UVM_LOW) 
      cfg_h.ral_model.tx_pfc_priority_enable.write(wstatus, enable_mask, UVM_FRONTDOOR);
      cfg_h.ral_model.tx_pfc_priority_enable.read(wstatus, data, UVM_FRONTDOOR);
    `uvm_info("",$sformatf("5555555555555555555555555555 Readed Data -- %0h -- %0h",data, req.priority_en_vector),UVM_LOW) 
      finish_item(req);
    end

  endtask

  //--------------------------------------------------------------
  task write_pause_quanta_reg(bit [2:0] prio, bit [15:0] quanta);

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
  task read_pause_quanta_reg(bit [2:0] prio, ref bit [15:0] quanta);
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

    quanta = rdata[15:0];
  endtask

endclass

`endif
