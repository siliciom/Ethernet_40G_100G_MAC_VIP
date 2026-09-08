//******************************************************************//
//                       ETHERNET DRIVER FILE
//
// Implements the Ethernet UVM driver. The driver receives Ethernet
// sequence items from the sequencer and converts them into pin-level
// signal activity on the configured Ethernet interface.
// It is responsible for transmitting frames, idles,
// control characters, errors, and protocol-specific signaling.
// TODO:- Need to update the pause and pfc scenarios.
//
// Author: Ankitha, Sanjeev
//
//******************************************************************//
class eth_drv extends uvm_driver #(eth_seq_item);
  `uvm_component_utils(eth_drv);
  `uvm_register_cb(eth_drv, error_cb)

  eth_seq_item tr;
  eth_cnfg cfg;
  virtual eth_interface v_intf;
  bit [`DATA_WIDTH-1:0] frame_q[$];
  bit [`CRC-1:0] next_crc32;
  localparam int NUM_LANES = `DATA_WIDTH / 8;
  int idx;
  //logic [`DATA_WIDTH-1:0] tx_word;
  int tx_idx;
  int deficit_cnt = 0;
  bit frame_in_progress = 0;
  int PAUSE_QUANTA_CYCLES;
  int fd_lane;
  int pad_within_word;
  int pad_cnt;
  bit [`MAC_ADDR-1:0] mac_addr;
  eth_seq_item pause_hold_q[$];
  bit pause_drain_in_progress = 0;
  semaphore tx_sem;
  int frame_count = 0;
  bit final_frame = 0;
  bit tx_busy = 0;
  bit frame_aborted = 0;
  eth_seq_item pfc_hold_q[8][$];  // per-priority hold queues
  int resumed_pcp_q[$];  // priorities that just went XON, pening drain
  bit drain_in_progress[8];  // per-priority drain-in-flight flag
  bit current_tx_vlan_en = 0;  // vlan_en of frame currently on the wire
  bit [2:0] current_tx_pcp;
  bit [15:0] pause_time;
  bit local_fault_detect;
  bit remote_fault_detect;
  bit frame_in_prg;
  bit local_fault_en;

  typedef struct packed {
    logic [`DATA_WIDTH-1:0] txd;
    logic [`CTRL_WIDTH-1:0] txc;
  } xlgmii_word_t;

  xlgmii_word_t xlgmii_q[$];


  function new(string name = "eth_drv", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual eth_interface)::get(this, "", "vif", v_intf))
      `uvm_fatal(get_type_name(), "CONNECTION_FAILED")
    else `uvm_info(get_type_name(), "CONNECTION_PASSED", UVM_LOW)

    if (!uvm_config_db#(eth_cnfg)::get(this, "", "cfg", cfg)) `uvm_fatal(get_type_name(), "No cfg")
    PAUSE_QUANTA_CYCLES = (512 / $bits(v_intf.drv_cb.TXD));
    tx_sem = new(1);

  endfunction

  //**********************************************************//
  // This task do the handshake mechanism and get the data
  // from sequence.
  //**********************************************************// 
  task run_phase(uvm_phase phase);
    drive_reset();
    reset_counters();
    wait (v_intf.rst);
    send_idle();
    repeat ($urandom_range(1, 5)) @(v_intf.drv_cb);
    fork
      update_counters();
      pause_timer();
      pfc_timer();
      drain_pause_queue();
      drain_resumed_frames();
      local_fault_check();
      remote_fault_check();
    join_none

    forever begin
      wait (statistics::pause_flag[mac_addr] == 0);
      wait(statistics::local_fault_detect[this.mac_addr] == 0 && statistics::remote_fault_detect[this.mac_addr] == 0);

      seq_item_port.get_next_item(tr);
      frame_count++;
      final_frame = (frame_count == `NO_OF_PKTS);
      if (tr.tx_single_vlan_enable && (statistics::pfc_flag[mac_addr][tr.PCP])) begin
        pfc_hold_q[tr.PCP].push_back(tr);
        `uvm_info("PFC_HOLD_Q", $sformatf("mac_addr=%h frame queued during pause, size=%0d",
                                          mac_addr, pfc_hold_q[tr.PCP].size()), UVM_LOW)
        `uvm_info("HOLD_Q", $sformatf("valn_en=%h,pcp=%h,len=%h,payload=%p",
                                      tr.tx_single_vlan_enable, tr.PCP, tr.ether_type, tr.payload),
                  UVM_LOW)
      end else if (statistics::pause_flag[mac_addr]) begin
        pause_hold_q.push_back(tr);
        `uvm_info("PAUSE_HOLD_Q", $sformatf("mac_addr=%h frame queued during pause, size=%0d",
                                            mac_addr, pause_hold_q.size()), UVM_LOW)
        //tx_sem.put(1);
      end else begin
        //tx_sem.get(1);
        wait_for_drain_complete(.hold_sem(0));
        tx_sem.get(1);
        if(tr.tx_single_vlan_enable && (statistics::pfc_flag[mac_addr][tr.PCP] || drain_in_progress[tr.PCP])) begin
          pfc_hold_q[tr.PCP].push_back(tr);
          `uvm_info("Re_PFC_HOLD_Q", $sformatf("pcp=%d pushed", tr.PCP), UVM_LOW)
          `uvm_info("HOLD_Q", $sformatf("valn_en=%h,pcp=%h,len=%h,payload=%p",
                                        tr.tx_single_vlan_enable, tr.PCP, tr.ether_type,
                                        tr.payload), UVM_LOW)
          tx_sem.put(1);
        end else if (statistics::pause_flag[mac_addr]) begin
          pause_hold_q.push_back(tr);
          `uvm_info("Re_PAUSE_HOLD_Q", $sformatf("mac=%h re-queued after sem grant", mac_addr),
                    UVM_LOW)
          tx_sem.put(1);
        end else begin
          tx_busy = 1;
          frame_pack(tr);
          rs_encode(tr);
          drive_frame(tr, 0);
          tx_busy = 0;
          if (!frame_aborted)
            // tx_busy=0; 
            send_dic_idle();

          tx_sem.put(1);
        end
      end
      `uvm_info("",$sformatf("cccccccccccccccccccccccccccc"),UVM_LOW) 
      #0.8;
      `uvm_info("",$sformatf("dddddddddddddddddddddddddddd"),UVM_LOW) 
      seq_item_port.item_done();
    end
  endtask

  //**********************************************************//
  // This tasks do the reset of all signals. 
  // it just drive zero all signals
  //**********************************************************// 
  task drive_reset();
    v_intf.drv_cb.TXD <= 0;
    v_intf.drv_cb.TXC <= 0;
  endtask

  //**********************************************************//
  // Waits for the monitor to raise pause_flag (i.e. a valid
  // PAUSE frame with PV was received), waits until any frame
  // currently on the wire finishes, then drives continuous
  // XLGMII idle for PV * PAUSE_QUANTA_CYCLES clock cycles.
  // If PV is updated while waiting (e.g. XON, PV=0), reloads
  // immediately so TX resumes without waiting out the old PV.
  //**********************************************************//
  task pause_timer();
    int local_pause_cycles;
    int prev_pause_value;

    forever begin
      wait (statistics::pause_flag[mac_addr] == 1);
      wait (tx_busy == 0);
      //  @(v_intf.drv_cb);
      // wait(frame_in_progress == 0);
      prev_pause_value   = statistics::pause_value[mac_addr];
      local_pause_cycles = prev_pause_value * PAUSE_QUANTA_CYCLES;
      // pause_started=1;
      //statistics::pause_update[mac_addr] = 0;

      `uvm_info("PAUSE_DBG", $sformatf(
                "mac=%0d PV=%0d cycles=%0d", mac_addr[7:0], prev_pause_value, local_pause_cycles),
                UVM_LOW)

      while (local_pause_cycles > 0) begin
        @(v_intf.drv_cb);
        v_intf.drv_cb.TXD <= {8{`IDLE_CH}};
        v_intf.drv_cb.TXC <= 8'hFF;
        //@(v_intf.drv_cb);


        if (statistics::pause_update[mac_addr]) begin
          prev_pause_value = statistics::pause_value[mac_addr];
          local_pause_cycles = prev_pause_value * PAUSE_QUANTA_CYCLES;
          //pause_started=1;
          statistics::pause_update[mac_addr] = 0;
          `uvm_info("PAUSE_UPDATE", $sformatf("New PV=%0d -> cycles=%0d", prev_pause_value,
                                              local_pause_cycles), UVM_LOW)
        end
        `uvm_info("PAUSE_CYCLES", $sformatf("pause_cycles=%0d", local_pause_cycles), UVM_LOW)
        local_pause_cycles--;

      end
      statistics::pause_flag[mac_addr] = 0;
      `uvm_info("PAUSE", $sformatf("TX Resume mac_id=%0d", mac_addr[7:0]), UVM_LOW)
    end
  endtask

  //**********************************************************//
  // Runs one clock-synchronous state machine per priority (0-7).
  // On a fresh PFC XOFF for priority i: starts the countdown
  // immediately, unless a frame belonging to that same priority
  // is currently on the wire, in which case it defers ("pending")
  // until that frame finishes. XON (pfc_value==0) resumes
  // immediately. Mid-count updates (pfc_update) reload the timer.
  // On expiry, pushes the priority into resumed_pcp_q for draining.
  //**********************************************************//
  task pfc_timer();
    int local_pfc_cycles[8];
    int prev_pfc_value[8];
    bit pfc_pending[8];
    bit pfc_just_started[8];
    forever begin
      @(v_intf.drv_cb);
      for (int i = 0; i < 8; i++) begin
        // Deferred start: frame for this priority just finished
        if(pfc_pending[i] && !(frame_in_progress && current_tx_vlan_en && current_tx_pcp == i)) begin
          pfc_pending[i]                      = 0;
          prev_pfc_value[i]                   = statistics::pfc_value[mac_addr][i];
          local_pfc_cycles[i]                 = prev_pfc_value[i] * PAUSE_QUANTA_CYCLES;
          pfc_just_started[i]                 = 1;
          statistics::pfc_update[mac_addr][i] = 0;
          `uvm_info("PFC_TIMER_START", $sformatf("pcp=%0d start_time=%0t", i, $time), UVM_LOW)
        end

        // Fresh PFC flag
        if (statistics::pfc_flag[mac_addr][i] && local_pfc_cycles[i] == 0 && !pfc_pending[i]) begin
          `uvm_info("DRV_TIMER_START", $sformatf("pcp=%0d pfc_value=%0d", i,
                                                 statistics::pfc_value[mac_addr][i]), UVM_LOW)
          if (statistics::pfc_value[mac_addr][i] == 0) begin
            // XON — nothing to wait out
            local_pfc_cycles[i]                 = 0;
            statistics::pfc_flag[mac_addr][i]   = 0;
            statistics::pfc_update[mac_addr][i] = 0;
            push_resumed_pcp(i);
          end else if (frame_in_progress && current_tx_vlan_en && current_tx_pcp == i) begin
            pfc_pending[i] = 1;
            `uvm_info("PFC_WAIT", $sformatf("pcp=%0d frame in progress, deferring timer start", i),
                      UVM_LOW)
          end else begin
            prev_pfc_value[i]                   = statistics::pfc_value[mac_addr][i];
            local_pfc_cycles[i]                 = prev_pfc_value[i] * PAUSE_QUANTA_CYCLES;
            pfc_just_started[i]                 = 1;
            statistics::pfc_update[mac_addr][i] = 0;
            `uvm_info("PFC_TIMER_START", $sformatf("pcp=%0d start_time=%0t", i, $time), UVM_LOW)
          end
        end
      end

      // Timer running
      for (int i = 0; i < 8; i++) begin
        if (local_pfc_cycles[i] > 0) begin
          if (statistics::pfc_update[mac_addr][i]) begin
            if (statistics::pfc_value[mac_addr][i] == 0) begin
              // XON update mid-count
              local_pfc_cycles[i]                 = 0;
              prev_pfc_value[i]                   = statistics::pfc_value[mac_addr][i];
              statistics::pfc_flag[mac_addr][i]   = 0;
              statistics::pfc_update[mac_addr][i] = 0;
              `uvm_info("DRV_TIMER", $sformatf("local=%0d,i=%0d", local_pfc_cycles[i], i), UVM_LOW)
              push_resumed_pcp(i);
              continue;
            end else begin
              prev_pfc_value[i]                   = statistics::pfc_value[mac_addr][i];
              local_pfc_cycles[i]                 = prev_pfc_value[i] * PAUSE_QUANTA_CYCLES;
              statistics::pfc_update[mac_addr][i] = 0;
              pfc_just_started[i]                 = 1;
            end
          end

          if (pfc_just_started[i]) begin
            `uvm_info("DRV_TIMER", $sformatf("local=%0d,i=%0d", local_pfc_cycles[i], i), UVM_LOW)
            pfc_just_started[i] = 0;
            continue;
          end

          local_pfc_cycles[i]--;
          `uvm_info("DRV_TIMER", $sformatf("local=%0d,i=%0d", local_pfc_cycles[i], i), UVM_LOW)
          if (local_pfc_cycles[i] == 0) begin
            if (statistics::pfc_update[mac_addr][i]) begin
              // fresh XOFF already visible for this same edge — reload instead of expiring
              prev_pfc_value[i] = statistics::pfc_value[mac_addr][i];
              local_pfc_cycles[i] = prev_pfc_value[i] * PAUSE_QUANTA_CYCLES;
              statistics::pfc_update[mac_addr][i] = 0;
              pfc_just_started[i] = 1;
            end else begin
              statistics::pfc_flag[mac_addr][i] = 0;
              push_resumed_pcp(i);
            end
          end
        end
      end
    end
  endtask



  task wait_for_drain_complete(bit hold_sem = 0);
    bit any_draining;
    forever begin
      any_draining = 0;
      // check all 8 priority queues
      for (int i = 0; i < 8; i++) begin
        if (pfc_hold_q[i].size() > 0 && !statistics::pfc_flag[mac_addr][i]) begin
          any_draining = 1;
          `uvm_info("DRV_YIELD", $sformatf("pcp=%0d draining (%0d frames) — new frame waiting",
                                           i, pfc_hold_q[i].size()), UVM_LOW)
          break;
        end
      end
      // also check resumed_pcp_q entries
      if (!any_draining && resumed_pcp_q.size() > 0) begin
        foreach (resumed_pcp_q[k]) begin
          if (pfc_hold_q[resumed_pcp_q[k]].size() > 0) begin
            any_draining = 1;
            `uvm_info("DRV_YIELD_RESUMEQ",
                      $sformatf("resumed_pcp_q has pcp=%0d with %0d frames pending",
                                resumed_pcp_q[k], pfc_hold_q[resumed_pcp_q[k]].size()), UVM_LOW)
            break;
          end
        end
      end
      if (!any_draining) break;
      if (hold_sem) tx_sem.put(1);
      @(v_intf.drv_cb);
      if (hold_sem) tx_sem.get(1);
    end
  endtask


  //**********************************************************//
  // Pushes a priority (pcp) onto resumed_pcp_q so it can be
  // picked up for draining. Skips the push if that pcp is
  // already queued, to avoid double-draining.
  //**********************************************************//
  task push_resumed_pcp(int pcp);
    foreach (resumed_pcp_q[k]) begin
      if (resumed_pcp_q[k] == pcp) begin
        `uvm_info("RESUMED_DUP", $sformatf("pcp=%0d already in resumed_pcp_q — skipped", pcp),
                  UVM_LOW)
        return;
      end
    end
    resumed_pcp_q.push_back(pcp);
    `uvm_info("RESUMED_PUSH", $sformatf("pcp=%0d pushed, q_size=%0d", pcp, resumed_pcp_q.size()),
              UVM_LOW)
  endtask


  //**********************************************************//
  // Watches resumed_pcp_q. When a priority shows up (pushed by
  // pfc_timer on XON/expiry), kicks off a drain thread for that
  // priority's held frames — unless one is already draining.
  //**********************************************************//
  task drain_resumed_frames();
    forever begin
      int pcp;
      wait (resumed_pcp_q.size() > 0);
      pcp = resumed_pcp_q.pop_front();
      if (drain_in_progress[pcp]) begin
        `uvm_info("DRAIN_SKIP",
                  $sformatf("pcp=%0d already draining — existing thread will pick up new frames",
                            pcp), UVM_LOW)
      end else begin
        fork
          begin
            automatic int my_pcp = pcp;
            drain_one_pcp(my_pcp);
          end
        join_none
      end
    end
  endtask

  //**********************************************************//
  // Drains all held frames for one priority. Sends frames one
  // at a time under tx_sem (so it never collides with the main
  // run_phase loop transmitting a normal frame). If PFC
  // reasserts for this priority mid-drain, stops immediately —
  // pfc_timer will re-add this pcp to resumed_pcp_q later.
  //**********************************************************//
  task drain_one_pcp(int pcp);
    eth_seq_item local_tr;
    if (pfc_hold_q[pcp].size() > 0) begin
      drain_in_progress[pcp] = 1;
      `uvm_info("DRAIN_START", $sformatf("pcp=%0d frames=%0d drain_in_progress[%0d]=1", pcp,
                                         pfc_hold_q[pcp].size(), pcp), UVM_LOW)
    end
    while (pfc_hold_q[pcp].size() > 0) begin
      if (statistics::pfc_flag[mac_addr][pcp]) begin
        drain_in_progress[pcp] = 0;
        `uvm_info("PFC_REBLOCK_EXIT",
                  $sformatf("pcp=%0d re-XOFF mid-drain — exiting, will resume via resumed_pcp_q",
                            pcp), UVM_LOW)
        return;
      end
      // tr=local_tr;
      local_tr = pfc_hold_q[pcp].pop_front();
      // tr=local_tr;
      tx_sem.get(1);
      if (statistics::pfc_flag[mac_addr][pcp]) begin
        pfc_hold_q[pcp].push_front(local_tr);
        `uvm_info("PFC_HOLD_Q", $sformatf("mac_addr=%h frame queued during pause, size=%0d",
                                          mac_addr, pfc_hold_q[local_tr.PCP].size()), UVM_LOW)
        `uvm_info("HOLD_Q", $sformatf("valn_en=%h,pcp=%h,len=%h,payload=%p", local_tr.vlan_en,
                                      local_tr.PCP, local_tr.ether_type, local_tr.payload), UVM_LOW)
        tx_sem.put(1);
        //continue;
        drain_in_progress[pcp] = 0;
        return;
      end
      //tr=local_tr;
      /*   if (vlan_active &&
        statistics::pfc_flag[mac_addr][tr.PCP]) begin

      pfc_hold_q[pcp].push_front(local_tr);

      tx_sem.put(1);

      `uvm_info("PFC_REBLOCK_BEFORE_TX",
        $sformatf("pcp=%0d XOFF detected for frame ready to send frame NOT transmitted",tr.PCP),UVM_LOW)

      drain_in_progress[pcp] = 0;
      return;
    end  */

      tx_busy = 1;
      frame_pack(local_tr);
      rs_encode(local_tr);
      `uvm_info("RESUMED_PFCpayloa", $sformatf(
                "PCP=%0d payload=%p hold frame transmitted successfully,tr", pcp, local_tr.payload),
                UVM_LOW)

      drive_frame(local_tr, 1);
      tx_busy = 0;
      if (frame_aborted) begin

        `uvm_info(
            "DRAIN_ABORT_EXIT",
            $sformatf(
                "PCP=%0d PFC reasserted while resuming hold frame Frame is already pushed FRONT. Stop drain.",
                pcp), UVM_LOW)

        drain_in_progress[pcp] = 0;
        tx_sem.put(1);

        return;
      end

      send_dic_idle();

      `uvm_info("RESUMED_PFC", $sformatf("PCP=%0d hold frame transmitted successfully,tr", pcp),
                UVM_LOW)

      tx_sem.put(1);
    end
    drain_in_progress[pcp] = 0;
    `uvm_info("DRAIN_DONE", "", UVM_LOW)
  endtask



  task drain_pause_queue();
    forever begin
      eth_seq_item local_tr;
      wait (pause_hold_q.size() > 0);
      wait (statistics::pause_flag[mac_addr] == 0);
      pause_drain_in_progress = 1;
      `uvm_info("PAUSE_DRAIN_START", $sformatf("mac=%h frames=%0d", mac_addr, pause_hold_q.size()),
                UVM_LOW)

      while (pause_hold_q.size() > 0) begin
        tx_sem.get(1);
        if (statistics::pause_flag[mac_addr]) begin
          tx_sem.put(1);
          `uvm_info("PAUSE_REBLOCK", "pause reasserted mid-drain", UVM_LOW)
          break;
        end
        //tr=local_tr;
        local_tr = pause_hold_q.pop_front();
        //tr=local_tr;
        tx_busy  = 1;
        frame_pack(local_tr);
        rs_encode(local_tr);
        drive_frame(local_tr, 0);
        tx_busy = 0;
        if (!frame_aborted)

          // tx_busy = 0;
          send_dic_idle();
        //tx_busy = 0;
        tx_sem.put(1);
      end

      if (pause_hold_q.size() == 0) begin
        pause_drain_in_progress = 0;
        `uvm_info("PAUSE_DRAIN_DONE", "all held frames sent", UVM_LOW)
      end
    end
  endtask



  function void phase_ready_to_end(uvm_phase phase);
    bit all_done;
    all_done = 1;

    // check 1: any PFC timer still active?
    for (int i = 0; i < 8; i++) begin
      if (statistics::pfc_flag[mac_addr][i]) begin
        all_done = 0;
        break;
      end
    end
    //check 2: any held frames still in queue?
    for (int i = 0; i < 8; i++) begin
      if (pfc_hold_q[i].size() > 0) begin
        all_done = 0;
        break;
      end
    end
    // check 3: any pending resumes not yet drained?
    if (resumed_pcp_q.size() > 0) all_done = 0;
    if (!all_done) begin
      phase.raise_objection(this, "PFC timers/queues still pending");
      fork
        begin
          forever begin
            all_done = 1;
            for (int i = 0; i < 8; i++) begin
              if (statistics::pfc_flag[mac_addr][i]) begin
                all_done = 0;
                break;
              end
            end
            for (int i = 0; i < 8; i++) begin
              if (pfc_hold_q[i].size() > 0) begin
                all_done = 0;
                break;
              end
            end
            if (resumed_pcp_q.size() > 0) all_done = 0;
            if (all_done) begin
              `uvm_info("PFC_DRAIN_DONE", $sformatf("All PFC timers expired mac=%0h", mac_addr),
                        UVM_LOW)
              phase.drop_objection(this, "PFC timers done");
              break;
            end
            @(v_intf.drv_cb);
          end
        end
      join_none
    end
  endfunction




  //**********************************************************//
  // This task packs an eth_seq_item transaction into frame_q
  // as a byte stream (preamble, SFD, DA, SA, VLAN tags,
  // ether_type, payload, padding, CRC) ready to be driven.
  //**********************************************************//

  task frame_pack(ref eth_seq_item tr);
    uvm_status_e   status;
    uvm_reg_data_t rd_data;
    idx = 0;
    frame_q.delete();
    `uvm_do_callbacks(eth_drv, error_cb, inject_error(tr));

    //Preamble packing
    foreach (tr.preamble[i]) frame_q[idx++] = tr.preamble[i];
    //SFD Packing
    frame_q[idx++] = tr.sfd[7:0];
    //DA packing
    for (int i = 5; i >= 0; i--) frame_q[idx++] = tr.da[i*8+:8];
    //SA packing
    for (int i = 5; i >= 0; i--)  //6 bytes of Source Address
      frame_q[idx++] = tr.sa[i*8+:8];

    //cfg.ral_model.tx_single_vlan_enable.read( status, tx_single_vlan_en, UVM_FRONTDOOR);
    //cfg.ral_model.tx_double_vlan_enable.read( status, tx_double_vlan_en, UVM_FRONTDOOR);
    if (tr.tx_double_vlan_en) begin
      // Outer VLAN
      frame_q[idx++] = tr.outer_TPID[15:8];
      frame_q[idx++] = tr.outer_TPID[7:0];
      frame_q[idx++] = {tr.outer_PCP, tr.outer_DEI, tr.outer_VID[11:8]};
      frame_q[idx++] = tr.outer_VID[7:0];

      // Inner VLAN
      frame_q[idx++] = tr.TPID[15:8];
      frame_q[idx++] = tr.TPID[7:0];
      frame_q[idx++] = {tr.PCP, tr.DEI, tr.VID[11:8]};
      frame_q[idx++] = tr.VID[7:0];

    end else if (tr.tx_single_vlan_enable) begin
      // Single VLAN
      frame_q[idx++] = tr.TPID[15:8];
      frame_q[idx++] = tr.TPID[7:0];
      frame_q[idx++] = {tr.PCP, tr.DEI, tr.VID[11:8]};
      frame_q[idx++] = tr.VID[7:0];
    end

    //Type/Length packing
    frame_q[idx++] = tr.ether_type[15:8];
    frame_q[idx++] = tr.ether_type[7:0];

    //Pause frame packing 
    $display("@@@@@@@@@@@@@@@@@@@ pfc_en=%0d", tr.pfc_frame_en);
    if (tr.pause_frame_en || tr.pfc_frame_en) begin
      frame_q[idx++] = tr.pause_opc[15:8];
      frame_q[idx++] = tr.pause_opc[7:0];
      if (tr.pfc_frame_en) begin  // logic for pfc frame 
        frame_q[idx++] = tr.priority_en_vector[15:8];
        frame_q[idx++] = tr.priority_en_vector[7:0];
        for (int i = 0; i < 8; i++) begin
          frame_q[idx++] = tr.pfc_pause_time[i][15:8];
          frame_q[idx++] = tr.pfc_pause_time[i][7:0];
        end
        //payload
        for (int i = 0; i < 26; i++) frame_q[idx++] = 8'h00;

        `uvm_info(
            "DRIVING DATA",
            $sformatf(
                "\n\t da=%h\n\t sa=%h\n\t type=%0h\n\t opcode=%0h\n\t priority_en_vector=%0d \n\t pfc_pause_time=%p	\n\t payload=%0d\n\t Frame size=%0d",
                tr.da, tr.sa, tr.ether_type, tr.pause_opc, tr.priority_en_vector,
                tr.pfc_pause_time, tr.payload.size(), idx), UVM_LOW)
      end else begin  ///logic for pause frame 

        //cfg.ral_model.tx_pauseframe_quanta.read( status, pause_time, UVM_FRONTDOOR);
        frame_q[idx++] = tr.pause_time[15:8];
        frame_q[idx++] = tr.pause_time[7:0];
        for (int i = 0; i < 42; i++) frame_q[idx++] = 0;
        `uvm_info("DRIVING DATA", $sformatf(
                  "pause_frame_en=%0b,da=%p,sa=%p,type=%0h,opcode=%0h,payload=%0d,Frame size = %0d",
                  tr.pause_frame_en,
                  tr.da,
                  tr.sa,
                  tr.ether_type,
                  tr.pause_opc,
                  tr.payload.size(),
                  idx
                  ), UVM_LOW)
      end
    end else begin

      //Payload packing
      for (int i = (tr.payload.size() - 1); i >= 0; i--) frame_q[idx++] = tr.payload[i];
      //Zero Padding if payload is less than 46 bytes for normal frame and
      // bytes for vlan tagged frame

      if (tr.tx_double_vlan_en ) 
	      pad_cnt = 38;
      else if (tr.tx_single_vlan_enable) pad_cnt = 42;
      else pad_cnt = 46;

      if (tr.payload.size() < pad_cnt && tr.padding_en == 1) begin
        for (int i = tr.payload.size(); i < pad_cnt; i++) frame_q[idx++] = 0;
      end
    end

    //CRC packing
    next_crc32 = 32'hFFFFFFFF;
    for (int i = 0; i < idx; i++) begin
      if (i > 7)  //Avoiding the Preamble and SFD Bytes
        next_crc32 = tr.crc_32(next_crc32, frame_q[i]);
    end
    next_crc32 = ~next_crc32;
    tr.crc = next_crc32;
    //BAD FCS 
    if (tr.corrupt_fcs_en == 1) begin
      next_crc32[7:0] = ~next_crc32[7:0];
      `uvm_info("BAD_FCS", $sformatf("Transmitting incorrect CRC=%h", next_crc32), UVM_LOW)
    end
    //  tr.CRC =next_crc32;
    for (int i = 3; i >= 0; i--) frame_q[idx++] = next_crc32[8*i+:8];
    tx_idx = 0;
    // Print full frame format always
    $display("*****************************ETH_DRIVER***********************************");
    `uvm_info(
        "DRIVER PACKING",
        $sformatf(
            "\n\t preamble = %p\n\t sfd = 0x%0h\n\t DA = %h\n\t SA = %h\n\t ether_type = 0x%0h\n\t payload = %h bytes\n\t crc = 0x%h\n\t Total frame size = %0d, Frame size from DA = %0d\n\t Payload size = %0d\n\n\t VLAN_EN = %b\n\t VLAN_TPID = %h\n\t PCP = %h, DEI = %h, VID = %h ,OUTER_TPID =%h,OUTER_PCP =%h,OUTER_DEI =%h,OUTER_VID =%h ,",
            tr.preamble, tr.sfd, tr.da, tr.sa, tr.ether_type, tr.payload.size(), next_crc32, idx,
            idx - 8, tr.payload.size(), tr.tx_single_vlan_enable, tr.TPID, tr.PCP, tr.DEI, tr.VID,
            tr.outer_TPID, tr.outer_PCP, tr.outer_DEI, tr.outer_VID), UVM_LOW)

    `uvm_info("DRIVING DATA", $sformatf("Frame size = %0d, CRC = %h", idx, next_crc32), UVM_LOW);
  endtask

  //**********************************************************//
  // This task drives XLGMII idle characters (0x07 on every
  // lane) with TXC all high, indicating no valid data on the
  // bus, then waits for one clock edge on the driver clocking
  // block.
  //**********************************************************// 
  task send_idle();
    v_intf.drv_cb.TXD <= {NUM_LANES{`IDLE_CH}};
    v_intf.drv_cb.TXC <= {NUM_LANES{1'b1}};
    @(v_intf.drv_cb);

  endtask

  //**********************************************************//
  // This task encodes the packed frame (frame_q) into XLGMII
  // words: adds START/TERMINATE control chars, pads/aligns
  // idle per Deficit Idle Count rules, packs into 8-byte words
  // (xlgmii_q).
  //**********************************************************// 
  task rs_encode(eth_seq_item tr);

    byte rs_frame[$];
    bit rs_ctrl[$];
    xlgmii_word_t word;
    int idx;
    int bytes_used_in_word;


    rs_frame.delete();
    rs_ctrl.delete();
    xlgmii_q.delete();

    //--------------------------------------------------
    // 1. START character (FB)
    //--------------------------------------------------
    rs_frame.push_back(`START_CH);
    rs_ctrl.push_back(1'b1);

    //--------------------------------------------------
    // 2. Remaining Ethernet frame (skip preamble byte 0)
    //--------------------------------------------------
    for (int i = 1; i < frame_q.size(); i++) begin
      rs_frame.push_back(frame_q[i]);
      rs_ctrl.push_back(0);
    end

    //--------------------------------------------------
    // 3. TERMINATE
    //--------------------------------------------------
    if (!tr.missing_terminate) begin
      rs_frame.push_back(`TERMINATE_CH);
      rs_ctrl.push_back(1'b1);
    end else begin
      `uvm_info(get_type_name(), "Skipping Terminate character (0xFD)", UVM_LOW)
    end

    //--------------------------------------------------
    // 4. Find which lane FD landed on
    //--------------------------------------------------
    bytes_used_in_word = rs_frame.size() % NUM_LANES;      // 1..8 (never 0 exactly here since FD just pushed)
    if (bytes_used_in_word == 0) fd_lane = NUM_LANES - 1;  // FD exactly filled last lane
    else fd_lane = bytes_used_in_word - 1;

    pad_within_word = (NUM_LANES - rs_frame.size()%NUM_LANES) % NUM_LANES;  // bytes left in the FD's own word

    //--------------------------------------------------
    // 5. Fill rest of FD's word with idle
    //--------------------------------------------------
    repeat (pad_within_word) begin
      rs_frame.push_back(`IDLE_CH);
      rs_ctrl.push_back(1);
    end

    //--------------------------------------------------
    // 8. Convert to XLGMII words
    //--------------------------------------------------
    idx = 0;
    while (idx < rs_frame.size()) begin
      word.txd = 0;
      word.txc = 0;
      for (int lane = 0; lane < NUM_LANES; lane++) begin
        word.txd[lane*8+:8] = rs_frame[idx];
        word.txc[lane]      = rs_ctrl[idx];
        idx++;
      end
      xlgmii_q.push_back(word);
    end

    // NEW - inject a single invalid control char at a chosen word/lane,
    // AFTER the frame is fully encoded, so only one lane is corrupted
    if (tr.invalid) begin
      xlgmii_q[0].txd[0*8+:8] = 8'h1E;
      xlgmii_q[0].txc[0]      = 1'b1;

      `uvm_info(get_type_name(), "Driving INVALID ctrl char=0x1E at word=0 lane=0", UVM_LOW)
    end
  endtask

  //**********************************************************//
  // This task computes and drives the mandatory/DIC idle
  // words that follow a frame, per the Deficit Idle Count
  // algorithm. Kept separate from rs_encode()/drive_frame()
  // so pause can preempt it without waiting for the full
  // IPG idle to complete.
  //**********************************************************//
  task send_dic_idle();
    int natural_idle;
    int surplus, shortfall;
    int extra_words;
    extra_words = 0;
    surplus     = 0;
    shortfall   = 0;

    //--------------------------------------------------
    // 6. Mandatory one full idle word so next frame's
    //    FB starts at lane0 of a fresh word
    //--------------------------------------------------
    if (pad_within_word < 5) begin
      $display("-----------------------------pad_within_word=%0d,natural_idle=%0d",
               pad_within_word, natural_idle);
      natural_idle = pad_within_word + NUM_LANES;
      $display("-----------------------------pad_within_word=%0d,natural_idle=%0d",
               pad_within_word, natural_idle);
      extra_words = 1;
    end else begin
      natural_idle = pad_within_word;
      extra_words  = 0;
    end

    //--------------------------------------------------
    // 7. Deficit Idle Count
    //--------------------------------------------------
    if (natural_idle >= 12) begin

      surplus = natural_idle - 12;
      if (deficit_cnt > 0) begin
        if (surplus >= deficit_cnt) begin
          surplus     = surplus - deficit_cnt;
          deficit_cnt = 0;
        end else begin
          deficit_cnt = deficit_cnt - surplus;
          surplus     = 0;
        end
      end
    end else begin
      shortfall = 12 - natural_idle;

      deficit_cnt = deficit_cnt + shortfall;

      if (deficit_cnt > 7) begin
        extra_words++;
        deficit_cnt  = deficit_cnt - 8;
        natural_idle = natural_idle + 8;
        `uvm_info("DIC_OVERFLOW",
                  $sformatf(" Inserted extra 8-byte idle word DEFICIT_CNT reduced to %0d",
                            deficit_cnt), UVM_LOW)
      end
    end


    //--------------------------------------------------
    // 8. Drive the computed idle words onto the bus
    //--------------------------------------------------
    for (int i = 0; i < extra_words; i++) begin
      @(v_intf.drv_cb);
      /*`uvm_info("DIC_IDLE",
      $sformatf("Driving DIC IDLE word %0d TXD=%016h TXC=%02h",
                i, {8{`IDLE_CH}}, 8'hFF),
      UVM_LOW) */
      v_intf.drv_cb.TXD <= {8{`IDLE_CH}};
      v_intf.drv_cb.TXC <= 8'hFF;
      // `uvm_info("EXTRA_WORDS",$sformatf("txd=%0h",v_intf.drv_cb.TXD),UVM_LOW)
    end
    `uvm_info("FD_LANE_INFO", $sformatf("FD_LANE=%0d NATURAL_IDLE=%0d DEFICIT_CNT=%0d", fd_lane,
                                        natural_idle, deficit_cnt), UVM_LOW)


    //--------------------------------------------------
    // FINAL FRAME HANDLING
    //--------------------------------------------------
    if (final_frame) begin

      `uvm_info("FINAL_FRAME", $sformatf("Final frame detected. Remaining DIC=%0d", deficit_cnt),
                UVM_LOW)

      //--------------------------------------------------
      // Flush remaining DIC
      //--------------------------------------------------
      if (deficit_cnt > 0) begin

        @(v_intf.drv_cb);

        // v_intf.drv_cb.TXD <= {8{`IDLE_CH}};
        //v_intf.drv_cb.TXC <= 8'hFF;
        //
        for (int lane = 0; lane < deficit_cnt; lane++) begin
          v_intf.drv_cb.TXD[lane*8+:8] <= `IDLE_CH;
          v_intf.drv_cb.TXC[lane]      <= 1'b1;
        end

        `uvm_info("FINAL_DIC_FLUSH", $sformatf("Final DIC=%0h flushed with idle word,txd=%0h",
                                               deficit_cnt, v_intf.drv_cb.TXD), UVM_LOW)

        deficit_cnt = 0;

      end

      //--------------------------------------------------
      // Always leave interface in IDLE after final frame
      //--------------------------------------------------
      @(v_intf.drv_cb);

      v_intf.drv_cb.TXD <= {8{`IDLE_CH}};
      v_intf.drv_cb.TXC <= 8'hFF;

      `uvm_info("FINAL_IDLE", $sformatf("Final frame completed. XLGMII driven to IDLE. txd=%0d",
                                        v_intf.drv_cb.TXD), UVM_LOW)

    end
  endtask


  //**********************************************************//
  // This task drives the encoded XLGMII words onto the
  // interface, optionally injecting an ERROR control char at
  // a chosen byte offset, and logs each driven word for
  // tracing.
  //**********************************************************//
  task drive_frame(eth_seq_item tr, bit from_hold_q = 0);

    xlgmii_word_t word;
    int byte_cnt = 0;
    int col_cnt;
    frame_in_progress  = 1;
    frame_aborted      = 0;
    current_tx_vlan_en = tr.tx_single_vlan_enable;
    current_tx_pcp     = tr.PCP;


    foreach (xlgmii_q[i]) begin
      @(v_intf.drv_cb);
      if (i == 0) begin
        if (statistics::pause_flag[mac_addr]) begin
          frame_q.delete();
          frame_in_progress = 0;
          frame_aborted = 1;
          pause_hold_q.push_front(tr);
          // Never leave stale FD/data on the bus for this edge
          v_intf.drv_cb.TXD <= {8{`IDLE_CH}};
          v_intf.drv_cb.TXC <= 8'hFF;

          `uvm_info("PAUSE_ABORT_FRAME",
                    "Frame aborted at i=0 due to pause reassertion, driving idle", UVM_LOW)
          return;
        end

        if (tr.tx_single_vlan_enable && statistics::pfc_flag[mac_addr][tr.PCP]) begin

          frame_q.delete();
          frame_in_progress = 0;
          frame_aborted = 1;

          if (from_hold_q) begin
            // This frame came from hold queue.
            // Keep it at the FRONT so it resumes first.
            pfc_hold_q[tr.PCP].push_front(tr);

            `uvm_info(
                "PFC_REHOLD",
                $sformatf(
                    "PCP=%0d PFC detected at i=0 whileresuming hold frame -> PUSH_FRONT, Q=%0d",
                    tr.PCP, pfc_hold_q[tr.PCP].size()), UVM_LOW)
          end else begin
            // New frame from sequencer.
            pfc_hold_q[tr.PCP].push_back(tr);

            `uvm_info("PFC_HOLD_Q", $sformatf(
                      "PCP=%0d PFC detected at i=0 for new frame> PUSH_BACK, Q=%0d",
                      tr.PCP,
                      pfc_hold_q[tr.PCP].size()
                      ), UVM_LOW)
          end

          v_intf.drv_cb.TXD <= {8{`IDLE_CH}};
          v_intf.drv_cb.TXC <= 8'hFF;

          return;
        end

      end
      word = xlgmii_q[i];
      //`uvm_info("DRIVE_WORD",
      //$sformatf("WORD=%0d TXD=%016h TXC=%02h",
      //         i, word.txd, word.txc),
      //UVM_LOW)
      for (int lane = 0; lane < NUM_LANES; lane++) begin
        // Count only DATA bytes
        if (word.txc[lane] == 0) begin
          if (tr.err_b && (byte_cnt == tr.err_offset)) begin
            // Replace data byte with ERROR control character
            word.txd[lane*8+:8] = 8'hFE;
            word.txc[lane]      = 1'b1;

            `uvm_info("ERROR_INJECT", $sformatf("Inserted FE at Word=%0d Lane=%0d Byte=%0d", i,
                                                lane, byte_cnt), UVM_LOW)
          end
          // Inject START control character in payload
          if (tr.start_char && (byte_cnt == tr.start_offset)) begin
            word.txd[lane*8+:8] = `START_CH;
            word.txc[lane]      = 1'b1;
            `uvm_info("START_IN_PAYLOAD", $sformatf(
                                              "Inserted START(0xFB) at Word=%0d Lane=%0d Byte=%0d",
                                              i, lane, byte_cnt), UVM_LOW)
          end
          // Inject  End character in payload
          if (tr.end_char && (byte_cnt == tr.end_offset)) begin
            word.txd[lane*8+:8] = `TERMINATE_CH;
            word.txc[lane]      = 1'b1;
            `uvm_info("END_IN_PAYLOAD", $sformatf(
                                            "Inserted END(0xFD) at Word=%0d Lane=%0d Byte=%0d", i,
                                            lane, byte_cnt), UVM_LOW)
          end
          //Sending TXC as High when TXD have DATA 
          if (tr.data_txc_error && (byte_cnt == tr.data_txc_offset)) begin
            word.txc[lane] = 1'b1;
            //  word.txc[lane] =56;
            word.txd[lane*8+:8] = $urandom_range(10, 100);
            `uvm_info("DATA_TXC_ERROR",
                      $sformatf(
                          "Forced TXC=1 for DATA byte at Word=%0d Lane=%0d Byte=%0d Data=0x%02h",
                          i, lane, byte_cnt, word.txd[lane*8+:8]), UVM_LOW)
          end
          byte_cnt++;
        end
      end
      if(col_cnt == 3 && this.local_fault_en && statistics::v_uif[mac_addr].tx_good_pkt_count == 0) begin
        word.txd = {`LOCAL_FAULT_SEQ, `LOCAL_FAULT_SEQ};
        word.txc = 8'hFF;
        local_fault_en = 0;
      end
      col_cnt++;

      if (statistics::remote_fault_detect[this.mac_addr] && !remote_fault_detect) begin
        remote_fault_detect = 1;
        if (xlgmii_q.size() > 0) frame_in_prg = 1;
      end else if (statistics::local_fault_detect[this.mac_addr] && !local_fault_detect) begin
        local_fault_detect = 1;
        if (xlgmii_q.size() > 0) frame_in_prg = 1;
      end

      if (local_fault_detect && statistics::local_fault_detect[this.mac_addr]) begin
        word.txd = {`REMOTE_FAULT_SEQ, `REMOTE_FAULT_SEQ};
        word.txc = 8'hFF;
        frame_aborted = 1;
      end else if (remote_fault_detect && statistics::remote_fault_detect[this.mac_addr]) begin
        word.txd = {`IDLE_BYTES, `IDLE_BYTES};
        word.txc = 8'hFF;
      end

      v_intf.drv_cb.TXD <= word.txd;
      v_intf.drv_cb.TXC <= word.txc;
      tr.tx_trace_q.push_back('{t: $time, txd: word.txd, txc: word.txc});
    end
    frame_in_prg = 0;
    frame_in_progress = 0;
  endtask

  //*******************************************************//
  // This task monitors Local Fault status and detects fault
  // entry and exit conditions. During an active Local Fault,
  // drives Remote Fault ordered sets when no frame is
  // currently being transmitted.
  //*******************************************************//
  task local_fault_check();
    forever begin
      @(v_intf.drv_cb);
      if(statistics::local_fault_detect[this.mac_addr] && !local_fault_detect && v_intf.drv_cb.TXD == {8{8'h07}} &&
	v_intf.drv_cb.TXC == 8'hFF) begin
        local_fault_detect = 1;
        if (xlgmii_q.size() > 0) frame_in_prg = 1;
      end

      if (statistics::local_fault_detect[this.mac_addr] == 0 && local_fault_detect) begin
        local_fault_detect = 0;
        frame_in_prg = 0;
      end

      if(local_fault_detect && !frame_in_prg && statistics::local_fault_detect[this.mac_addr]) begin
        v_intf.drv_cb.TXD <= {`REMOTE_FAULT_SEQ, `REMOTE_FAULT_SEQ};
        v_intf.drv_cb.TXC <= 8'hFF;
      end

    end
  endtask

  //*******************************************************//
  // This task monitors Remote Fault status and detects fault 
  // entryand exit conditions. During an active Remote Fault,
  // drives IDLE characters when no frame transmission
  // is in progress.
  //*******************************************************//
  task remote_fault_check();
    forever begin
      @(v_intf.drv_cb);
      if(statistics::remote_fault_detect[this.mac_addr] && !remote_fault_detect && v_intf.drv_cb.TXD == {8{8'h07}} &&
        v_intf.drv_cb.TXC == 8'hFF) begin
        remote_fault_detect = 1;
        if (xlgmii_q.size() > 0) frame_in_prg = 1;
      end

      if (statistics::remote_fault_detect[this.mac_addr] == 0 && remote_fault_detect) begin
        remote_fault_detect = 0;
        frame_in_prg = 0;
      end

      if(remote_fault_detect && !frame_in_prg && statistics::remote_fault_detect[this.mac_addr]) begin
        v_intf.drv_cb.TXD <= {`IDLE_BYTES, `IDLE_BYTES};
        v_intf.drv_cb.TXC <= 8'hFF;
      end
    end
  endtask

  //**********************************************************//
  // This task runs forever and, on every clock edge, updates
  // all the TX and RX statistics counters for this mac_addr
  // from their pending values into the visible interface
  // counters.
  //**********************************************************//

  task update_counters();
    forever begin
      @(v_intf.drv_cb);
      statistics::v_uif[mac_addr].tx_good_pkt_count <= statistics::tx_good_pkt_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_bad_pkt_count <= statistics::tx_bad_pkt_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_unicast_count <= statistics::tx_unicast_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_multicast_count <= statistics::tx_multicast_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_broadcast_count <= statistics::tx_broadcast_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_fragment_count <= statistics::tx_fragment_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_runt_count <= statistics::tx_runt_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pause_count <= statistics::tx_pause_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_vlan_count <= statistics::tx_vlan_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_jumbo_count <= statistics::tx_jumbo_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_jabber_count <= statistics::tx_jabber_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_ipg_violation_count <= statistics::tx_ipg_violation_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xon_count <= statistics::tx_pfc_xon_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xoff_count <= statistics::tx_pfc_xoff_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_carrier_ext_count   <= statistics::tx_carrier_ext_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pause_xon_count <= statistics::tx_pause_xon_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pause_xoff_count    <= statistics::tx_pause_xoff_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_control_pkt_count   <= statistics::tx_control_pkt_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xon_prio0_count <= statistics::tx_pfc_xon_prio0_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xon_prio1_count <= statistics::tx_pfc_xon_prio1_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xon_prio2_count <= statistics::tx_pfc_xon_prio2_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xon_prio3_count <= statistics::tx_pfc_xon_prio3_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xon_prio4_count <= statistics::tx_pfc_xon_prio4_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xon_prio5_count <= statistics::tx_pfc_xon_prio5_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xon_prio6_count <= statistics::tx_pfc_xon_prio6_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xon_prio7_count <= statistics::tx_pfc_xon_prio7_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xoff_prio0_count<= statistics::tx_pfc_xoff_prio0_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xoff_prio1_count<= statistics::tx_pfc_xoff_prio1_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xoff_prio2_count<= statistics::tx_pfc_xoff_prio2_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xoff_prio3_count<= statistics::tx_pfc_xoff_prio3_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xoff_prio4_count<= statistics::tx_pfc_xoff_prio4_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xoff_prio5_count<= statistics::tx_pfc_xoff_prio5_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xoff_prio6_count<= statistics::tx_pfc_xoff_prio6_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_pfc_xoff_prio7_count<= statistics::tx_pfc_xoff_prio7_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_drop_count <= statistics::tx_drop_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_oversized_count <= statistics::tx_oversized_pending[mac_addr];
      statistics::v_uif[mac_addr].tx_idle_fault_seq_cnt  <= statistics::tx_idle_fault_seq_cnt[mac_addr];
      statistics::v_uif[mac_addr].tx_remote_fault_seq_cnt<= statistics::tx_remote_fault_seq_cnt[mac_addr];

      statistics::v_uif[mac_addr].rx_good_pkt_count <= statistics::rx_good_pkt_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_bad_pkt_count <= statistics::rx_bad_pkt_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_unicast_count <= statistics::rx_unicast_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_multicast_count <= statistics::rx_multicast_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_broadcast_count <= statistics::rx_broadcast_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_fragment_count <= statistics::rx_fragment_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_runt_count <= statistics::rx_runt_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pause_count <= statistics::rx_pause_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_vlan_count <= statistics::rx_vlan_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_jumbo_count <= statistics::rx_jumbo_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_jabber_count <= statistics::rx_jabber_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_ipg_violation_count <= statistics::rx_ipg_violation_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xon_count <= statistics::rx_pfc_xon_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xoff_count <= statistics::rx_pfc_xoff_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_carrier_ext_count   <= statistics::rx_carrier_ext_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pause_xon_count <= statistics::rx_pause_xon_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pause_xoff_count    <= statistics::rx_pause_xoff_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_control_pkt_count   <= statistics::rx_control_pkt_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xon_prio0_count <= statistics::rx_pfc_xon_prio0_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xon_prio1_count <= statistics::rx_pfc_xon_prio1_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xon_prio2_count <= statistics::rx_pfc_xon_prio2_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xon_prio3_count <= statistics::rx_pfc_xon_prio3_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xon_prio4_count <= statistics::rx_pfc_xon_prio4_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xon_prio5_count <= statistics::rx_pfc_xon_prio5_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xon_prio6_count <= statistics::rx_pfc_xon_prio6_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xon_prio7_count <= statistics::rx_pfc_xon_prio7_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xoff_prio0_count<= statistics::rx_pfc_xoff_prio0_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xoff_prio1_count<= statistics::rx_pfc_xoff_prio1_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xoff_prio2_count<= statistics::rx_pfc_xoff_prio2_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xoff_prio3_count<= statistics::rx_pfc_xoff_prio3_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xoff_prio4_count<= statistics::rx_pfc_xoff_prio4_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xoff_prio5_count<= statistics::rx_pfc_xoff_prio5_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xoff_prio6_count<= statistics::rx_pfc_xoff_prio6_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_pfc_xoff_prio7_count<= statistics::rx_pfc_xoff_prio7_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_drop_count <= statistics::rx_drop_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_oversized_count <= statistics::rx_oversized_pending[mac_addr];
      statistics::v_uif[mac_addr].rx_idle_fault_seq_cnt  <= statistics::rx_idle_fault_seq_cnt[mac_addr];
      statistics::v_uif[mac_addr].rx_remote_fault_seq_cnt<= statistics::rx_remote_fault_seq_cnt[mac_addr];
    end
  endtask

  //**********************************************************//
  // This function resets all TX and RX statistics counters
  // for this mac_addr back to zero.
  //**********************************************************//
  function void reset_counters();
    statistics::v_uif[mac_addr].tx_good_pkt_count       <= 0;
    statistics::v_uif[mac_addr].tx_bad_pkt_count        <= 0;
    statistics::v_uif[mac_addr].tx_unicast_count        <= 0;
    statistics::v_uif[mac_addr].tx_multicast_count      <= 0;
    statistics::v_uif[mac_addr].tx_broadcast_count      <= 0;
    statistics::v_uif[mac_addr].tx_fragment_count       <= 0;
    statistics::v_uif[mac_addr].tx_runt_count           <= 0;
    statistics::v_uif[mac_addr].tx_pause_count          <= 0;
    statistics::v_uif[mac_addr].tx_vlan_count           <= 0;
    statistics::v_uif[mac_addr].tx_jumbo_count          <= 0;
    statistics::v_uif[mac_addr].tx_jabber_count         <= 0;
    statistics::v_uif[mac_addr].tx_ipg_violation_count  <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_count        <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_count       <= 0;
    statistics::v_uif[mac_addr].tx_carrier_ext_count    <= 0;
    statistics::v_uif[mac_addr].tx_pause_xon_count      <= 0;
    statistics::v_uif[mac_addr].tx_pause_xoff_count     <= 0;
    statistics::v_uif[mac_addr].tx_control_pkt_count    <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio0_count  <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio1_count  <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio2_count  <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio3_count  <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio4_count  <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio5_count  <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio6_count  <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xon_prio7_count  <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio0_count <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio1_count <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio2_count <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio3_count <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio4_count <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio5_count <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio6_count <= 0;
    statistics::v_uif[mac_addr].tx_pfc_xoff_prio7_count <= 0;
    statistics::v_uif[mac_addr].tx_drop_count           <= 0;
    statistics::v_uif[mac_addr].tx_oversized_count      <= 0;
    statistics::v_uif[mac_addr].tx_idle_fault_seq_cnt   <= 0;
    statistics::v_uif[mac_addr].tx_remote_fault_seq_cnt <= 0;

    statistics::v_uif[mac_addr].rx_good_pkt_count       <= 0;
    statistics::v_uif[mac_addr].rx_bad_pkt_count        <= 0;
    statistics::v_uif[mac_addr].rx_unicast_count        <= 0;
    statistics::v_uif[mac_addr].rx_multicast_count      <= 0;
    statistics::v_uif[mac_addr].rx_broadcast_count      <= 0;
    statistics::v_uif[mac_addr].rx_fragment_count       <= 0;
    statistics::v_uif[mac_addr].rx_runt_count           <= 0;
    statistics::v_uif[mac_addr].rx_pause_count          <= 0;
    statistics::v_uif[mac_addr].rx_vlan_count           <= 0;
    statistics::v_uif[mac_addr].rx_jumbo_count          <= 0;
    statistics::v_uif[mac_addr].rx_jabber_count         <= 0;
    statistics::v_uif[mac_addr].rx_ipg_violation_count  <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_count        <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_count       <= 0;
    statistics::v_uif[mac_addr].rx_carrier_ext_count    <= 0;
    statistics::v_uif[mac_addr].rx_pause_xon_count      <= 0;
    statistics::v_uif[mac_addr].rx_pause_xoff_count     <= 0;
    statistics::v_uif[mac_addr].rx_control_pkt_count    <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio0_count  <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio1_count  <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio2_count  <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio3_count  <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio4_count  <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio5_count  <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio6_count  <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xon_prio7_count  <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio0_count <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio1_count <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio2_count <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio3_count <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio4_count <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio5_count <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio6_count <= 0;
    statistics::v_uif[mac_addr].rx_pfc_xoff_prio7_count <= 0;
    statistics::v_uif[mac_addr].rx_drop_count           <= 0;
    statistics::v_uif[mac_addr].rx_oversized_count      <= 0;
    statistics::v_uif[mac_addr].rx_idle_fault_seq_cnt   <= 0;
    statistics::v_uif[mac_addr].rx_remote_fault_seq_cnt <= 0;

  endfunction


  //**********************************************************//
  // This function returns the index of this mac_addr within
  // the eth_seq_item's mac_addr list.
  //**********************************************************//
  function int mac_no(bit [47:0] mac_t);
    eth_seq_item tr;
    tr = eth_seq_item::type_id::create("tr", this);
    foreach (tr.mac_addr[i]) begin
      if (tr.mac_addr[i] == mac_addr) return i;
    end
  endfunction

  //**********************************************************//
  // This function builds and prints a formatted TX/RX counter
  // summary report for this mac_addr at the end of the test.
  //**********************************************************//

  function void report_phase(uvm_phase phase);
    string tx_rx_report;

    tx_rx_report =
        $sformatf("\n================ COUNTER SUMMARY =================\nMAC_ADDR=%h\n", mac_addr);

    tx_rx_report = {
      tx_rx_report,
      $sformatf("\n---------------- MAC %0d : TX COUNTERS ----------------\n", mac_no(mac_addr))
    };

    tx_rx_report = {
      tx_rx_report,
      $sformatf("TX Good Packets          = %0d\n", statistics::v_uif[mac_addr].tx_good_pkt_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("TX Bad Packets           = %0d\n", statistics::v_uif[mac_addr].tx_bad_pkt_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("TX Unicast               = %0d\n", statistics::v_uif[mac_addr].tx_unicast_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("TX Multicast             = %0d\n", statistics::v_uif[mac_addr].tx_multicast_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("TX Broadcast             = %0d\n", statistics::v_uif[mac_addr].tx_broadcast_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("TX Runt                  = %0d\n", statistics::v_uif[mac_addr].tx_runt_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("TX Fragment              = %0d\n", statistics::v_uif[mac_addr].tx_fragment_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("TX Jumbo                 = %0d\n", statistics::v_uif[mac_addr].tx_jumbo_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("TX Jabber                = %0d\n", statistics::v_uif[mac_addr].tx_jabber_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("TX Oversize              = %0d\n", statistics::v_uif[mac_addr].tx_oversized_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("TX Pause                 = %0d\n", statistics::v_uif[mac_addr].tx_pause_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("TX VLAN                  = %0d\n", statistics::v_uif[mac_addr].tx_vlan_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX IPG Violation         = %0d\n", statistics::v_uif[mac_addr].tx_ipg_violation_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("TX PFC XON               = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("TX PFC XOFF              = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX_carrier_ext_cnt       = %0d\n", statistics::v_uif[mac_addr].tx_carrier_ext_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("TX Pause XON             = %0d\n", statistics::v_uif[mac_addr].tx_pause_xon_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("Tx Pause XOFF            = %0d\n", statistics::v_uif[mac_addr].tx_pause_xoff_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX control pkt           = %0d\n", statistics::v_uif[mac_addr].tx_control_pkt_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX PFC_XON_PRIO[0]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio0_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX PFC_XON_PRIO[1]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio1_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX PFC_XON_PRIO[2]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio2_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX PFC_XON_PRIO[3]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio3_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX PFC_XON_PRIO[4]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio4_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX PFC_XON_PRIO[5]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio5_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX PFC_XON_PRIO[6]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio6_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX PFC_XON_PRIO[7]       = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xon_prio7_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX PFC_XOFF_PRIO[0]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio0_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX PFC_XOFF_PRIO[1]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio1_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX PFC_XOFF_PRIO[2]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio2_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX PFC_XOFF_PRIO[3]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio3_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX PFC_XOFF_PRIO[4]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio4_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX PFC_XOFF_PRIO[5]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio5_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX PFC_XOFF_PRIO[6]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio6_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX PFC_XOFF_PRIO[7]      = %0d\n", statistics::v_uif[mac_addr].tx_pfc_xoff_prio7_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX Remote Fault Cnt      = %0d\n", statistics::v_uif[mac_addr].tx_remote_fault_seq_cnt
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "TX Idle Fault Cnt        = %0d\n", statistics::v_uif[mac_addr].tx_idle_fault_seq_cnt
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("TX DROP COUNT            = %0d\n", statistics::v_uif[mac_addr].tx_drop_count)
    };

    tx_rx_report = {
      tx_rx_report,
      $sformatf("---------------- MAC %0d : RX COUNTERS ----------------\n", mac_no(mac_addr))
    };

    tx_rx_report = {
      tx_rx_report,
      $sformatf("RX Good Packets          = %0d\n", statistics::v_uif[mac_addr].rx_good_pkt_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("RX Bad Packets           = %0d\n", statistics::v_uif[mac_addr].rx_bad_pkt_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("RX Unicast               = %0d\n", statistics::v_uif[mac_addr].rx_unicast_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("RX Multicast             = %0d\n", statistics::v_uif[mac_addr].rx_multicast_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("RX Broadcast             = %0d\n", statistics::v_uif[mac_addr].rx_broadcast_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("RX Runt                  = %0d\n", statistics::v_uif[mac_addr].rx_runt_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("RX Fragment              = %0d\n", statistics::v_uif[mac_addr].rx_fragment_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("RX Jumbo                 = %0d\n", statistics::v_uif[mac_addr].rx_jumbo_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("RX Jabber                = %0d\n", statistics::v_uif[mac_addr].rx_jabber_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("RX Oversize              = %0d\n", statistics::v_uif[mac_addr].rx_oversized_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("RX Pause                 = %0d\n", statistics::v_uif[mac_addr].rx_pause_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("RX VLAN                  = %0d\n", statistics::v_uif[mac_addr].rx_vlan_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("RX PFC XON               = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("RX PFC XOFF              = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX IPG Violation         = %0d\n", statistics::v_uif[mac_addr].rx_ipg_violation_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX_carrier_ext_cnt       = %0d\n", statistics::v_uif[mac_addr].rx_carrier_ext_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("RX Pause XON             = %0d\n", statistics::v_uif[mac_addr].rx_pause_xon_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("Rx Pause XOFF            = %0d\n", statistics::v_uif[mac_addr].rx_pause_xoff_count)
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX control pkt           = %0d\n", statistics::v_uif[mac_addr].rx_control_pkt_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX PFC_XON_PRIO[0]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio0_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX PFC_XON_PRIO[1]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio1_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX PFC_XON_PRIO[2]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio2_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX PFC_XON_PRIO[3]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio3_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX PFC_XON_PRIO[4]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio4_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX PFC_XON_PRIO[5]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio5_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX PFC_XON_PRIO[6]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio6_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX PFC_XON_PRIO[7]       = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xon_prio7_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX PFC_XOFF_PRIO[0]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio0_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX PFC_XOFF_PRIO[1]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio1_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX PFC_XOFF_PRIO[2]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio2_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX PFC_XOFF_PRIO[3]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio3_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX PFC_XOFF_PRIO[4]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio4_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX PFC_XOFF_PRIO[5]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio5_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX PFC_XOFF_PRIO[6]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio6_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX PFC_XOFF_PRIO[7]      = %0d\n", statistics::v_uif[mac_addr].rx_pfc_xoff_prio7_count
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX Remote Fault Cnt      = %0d\n", statistics::v_uif[mac_addr].rx_remote_fault_seq_cnt
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf(
          "RX Idle Fault Cnt        = %0d\n", statistics::v_uif[mac_addr].rx_idle_fault_seq_cnt
      )
    };
    tx_rx_report = {
      tx_rx_report,
      $sformatf("RX DROP COUNT            = %0d\n", statistics::v_uif[mac_addr].rx_drop_count)
    };
    tx_rx_report = {tx_rx_report, "\n================================================"};

    `uvm_info("COUNTER_REPORT", tx_rx_report, UVM_NONE)
  endfunction


endclass



