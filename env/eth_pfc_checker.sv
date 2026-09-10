//******************************************************************//
//              ETHERNET PFC CHECKER (XLGMII VERSION)
//******************************************************************//
//
// XLGMII:
//   - 8 lanes
//   - 8 bytes transferred per TX/RX clock
//   - START = 8'hFB on lane 0
//   - TERMINATE = 8'hFD on any lane
//
// PFC:
//   - 1 quanta = 512 bit-times = 64 byte-times
//   - 8-byte XLGMII word
//   - Expected cycles = quanta * 64 / 8
//                    = quanta * 8
//
// Example:
//   Q=1  -> 8 cycles
//   Q=4  -> 32 cycles
//   Q=5  -> 40 cycles
//   Q=7  -> 56 cycles
//   Q=8  -> 64 cycles
//
// IMPORTANT CHECKING RULE:
//
//   If a normal frame is already in progress when PFC arrives,
//   that frame is allowed to complete.
//
//   Only a NEW frame started after the PFC pause becomes active
//   is checked against the paused PCP.
//
//   The same frame is checked only once.
//******************************************************************//

`define XLGMII_START 8'hFB
`define XLGMII_TERM  8'hFD
`define PREAMBLE     8'h55
`define SFD          8'hD5
`define NO_OF_LANES  8

class eth_pfc_checker extends uvm_component;

  `uvm_component_utils(eth_pfc_checker)

  //============================================================//
  // VIRTUAL INTERFACES
  //============================================================//

  virtual eth_interface v_intf[`NO_OF_AGENTS];


  //============================================================//
  // RX FRAME STORAGE
  //============================================================//

  bit [7:0] frame_q[`NO_OF_AGENTS][$];

  // RX byte offset
  int byte_cnt[`NO_OF_AGENTS];


  //============================================================//
  // TX FRAME STORAGE / BYTE COUNTER
  //============================================================//

  // IMPORTANT:
  // This declaration was missing in your previous code.
  //
  // byte_cnt  -> RX side
  // byte_count -> TX side
  //
  int byte_count[`NO_OF_AGENTS];


  //============================================================//
  // RX FRAME FIELDS
  //============================================================//

  bit [47:0] da[`NO_OF_AGENTS];
  bit [47:0] sa[`NO_OF_AGENTS];

  bit [15:0] ether_type[`NO_OF_AGENTS];
  bit [15:0] opcode[`NO_OF_AGENTS];

  bit [15:0] priority_vector[`NO_OF_AGENTS];

  bit [15:0] pfc_quanta[`NO_OF_AGENTS][8];


  //============================================================//
  // PFC STATE
  //============================================================//

  // 1 -> PCP is currently paused
  bit pfc_xoff_en[`NO_OF_AGENTS][8];

  // 1 -> old timer is being overridden
  bit pfc_override_en[`NO_OF_AGENTS][8];

  // Generation counter for each PCP.
  //
  // Every new PFC command for a PCP increments the generation.
  //
  // Old timer:
  //   my_generation = 1
  //
  // New PFC:
  //   pfc_generation = 2
  //
  // Old timer sees mismatch and exits.
  int unsigned pfc_generation[`NO_OF_AGENTS][8];

  // Indicates that a timer task exists for this PCP.
  bit pfc_task_active[`NO_OF_AGENTS][8];


  //============================================================//
  // TX FRAME TRACKING
  //============================================================//

  bit frame_active[`NO_OF_AGENTS];

  // Unique ID for every TX frame.
  //
  // Incremented only when START is detected.
  int unsigned tx_frame_id[`NO_OF_AGENTS];

  // Current TX VLAN PCP.
  bit [2:0] tx_vlan_pcp[`NO_OF_AGENTS];

  // Indicates PCP byte has been decoded.
  bit tx_pcp_valid[`NO_OF_AGENTS];


  //============================================================//
  // TX PFC CONTROL FRAME DETECTION
  //============================================================//

  bit [15:0] tx_ether_type[`NO_OF_AGENTS];

  bit [15:0] tx_opcode_or_tci[`NO_OF_AGENTS];

  // 1 -> current TX frame is a PFC control frame.
  bit tx_pfc_frame[`NO_OF_AGENTS];


  //============================================================//
  // IN-FLIGHT TX FRAME INFORMATION
  //============================================================//

  // TX frame that was already active when PFC became active.
  //
  // That frame is allowed to finish.
  //
  // Example:
  //
  //   Current Frame ID = 100
  //   PFC arrives
  //   inflight ID = 100
  //
  //   Frame 100 -> allowed
  //   Frame 101 -> checked
  int unsigned pfc_inflight_frame_id[`NO_OF_AGENTS][8];


  // Last frame that was checked for this PCP.
  //
  // Prevents repeated PFC_ERR for the same frame.
  int unsigned pfc_last_checked_frame_id[`NO_OF_AGENTS][8];


  //============================================================//
  // STATISTICS
  //============================================================//

  int total_pfc_frames[`NO_OF_AGENTS];

  int actual_no_of_pkts[`NO_OF_AGENTS];

  int no_of_pkts = 200;


  //============================================================//
  // COMPATIBILITY / DEBUG VARIABLES
  //============================================================//

  bit [15:0] vlan_tpid;
  bit [15:0] vlan_tci;

  bit [2:0] vlan_pcp[`NO_OF_AGENTS];

  bit loop_brk[`NO_OF_AGENTS];

  bit loop_brk_p[`NO_OF_AGENTS][8];

  bit loop_brk_done[`NO_OF_AGENTS][8];

  bit zero_pause_time[`NO_OF_AGENTS][8];

  int clk[`NO_OF_AGENTS][8];

  int pause_time[`NO_OF_AGENTS][8];

  int wait_for_pcp[`NO_OF_AGENTS][8];


  //============================================================//
  // CONSTRUCTOR
  //============================================================//

  function new(
      string name = "eth_pfc_checker",
      uvm_component parent = null
  );

    super.new(name, parent);

  endfunction


  //============================================================//
  // BUILD PHASE
  //============================================================//

  function void build_phase(uvm_phase phase);

    super.build_phase(phase);


    //------------------------------------------------------------//
    // NO_OF_PKTS
    //------------------------------------------------------------//

    if ($value$plusargs("NO_OF_PKTS=%0d", no_of_pkts)) begin

      `uvm_info(
        get_type_name(),
        $sformatf(
          "NO_OF_PKTS from plusarg = %0d",
          no_of_pkts
        ),
        UVM_DEBUG
      )

    end
    else begin

      `uvm_info(
        get_type_name(),
        $sformatf(
          "Using default NO_OF_PKTS = %0d",
          no_of_pkts
        ),
        UVM_DEBUG
      )

    end


    //------------------------------------------------------------//
    // Get virtual interfaces
    //------------------------------------------------------------//

    for (int i = 0; i < `NO_OF_AGENTS; i++) begin

      if (!uvm_config_db#(virtual eth_interface)::get(
            this,
            "",
            $sformatf("virf%0d", i),
            v_intf[i]
          )) begin

        `uvm_fatal(
          "PFC_CHK",
          $sformatf(
            "Unable to get virf%0d",
            i
          )
        )

      end

    end


    //------------------------------------------------------------//
    // Initialize state
    //------------------------------------------------------------//

    for (int i = 0; i < `NO_OF_AGENTS; i++) begin

      frame_active[i]      = 0;

      byte_cnt[i]          = 0;

      byte_count[i]        = 0;

      tx_frame_id[i]       = 0;

      tx_pcp_valid[i]      = 0;

      tx_pfc_frame[i]      = 0;

      tx_ether_type[i]     = 0;

      tx_opcode_or_tci[i]  = 0;

      tx_vlan_pcp[i]       = 0;

      actual_no_of_pkts[i] = 0;

      total_pfc_frames[i]  = 0;


      for (int p = 0; p < 8; p++) begin

        pfc_xoff_en[i][p] = 0;

        pfc_override_en[i][p] = 0;

        pfc_generation[i][p] = 0;

        pfc_task_active[i][p] = 0;

        pfc_inflight_frame_id[i][p] = 0;

        pfc_last_checked_frame_id[i][p] = 0;

        loop_brk_p[i][p] = 0;

        loop_brk_done[i][p] = 0;

        zero_pause_time[i][p] = 0;

        clk[i][p] = 0;

        pause_time[i][p] = 0;

        wait_for_pcp[i][p] = 0;

      end

    end

  endfunction


  //============================================================//
  // RUN PHASE
  //============================================================//

  task run_phase(uvm_phase phase);

    wait (v_intf[0].rst);

    for (int i = 0; i < `NO_OF_AGENTS; i++) begin

      fork

        automatic int agent = i;

        sample_pfc_frame(agent);

        sample_transmitter(agent);

      join_none

    end

  endtask


  //****************************************************************//
  //****************************************************************//
  //                    RX PFC FRAME SAMPLER
  //****************************************************************//
  //****************************************************************//

  task sample_pfc_frame(int agent);

    int p;

    int lane;

    bit [7:0] byte_val;

    bit frame_rx_active;

    string frame_dump_str;


    forever begin

      //============================================================//
      // Reset RX frame state
      //============================================================//

      frame_q[agent].delete();

      byte_cnt[agent] = 0;

      priority_vector[agent] = 0;

      frame_rx_active = 0;

      loop_brk[agent] = 0;


      //============================================================//
      // Wait for START on lane 0
      //============================================================//

      forever begin

        @(posedge v_intf[agent].RX_CLK);

        if (
          v_intf[agent].RXC[0] &&
          v_intf[agent].RXD[7:0] == `XLGMII_START
        ) begin

          frame_rx_active = 1;

          break;

        end

      end


      //============================================================//
      // START BEAT
      //
      // lane 0 = FB
      // lane 1..6 = preamble
      // lane 7 = SFD
      //============================================================//

      for (lane = 1; lane < 8; lane++) begin

        byte_val =
          v_intf[agent].RXD[(lane*8)+:8];

        frame_q[agent].push_back(byte_val);


        if (byte_cnt[agent] < 6) begin

          if (byte_val != `PREAMBLE) begin

            `uvm_warning(
              "PFC_PREAMBLE_ERR",
              $sformatf(
                "Agent=%0d Byte=%0d Expected=%02h Got=%02h",
                agent,
                byte_cnt[agent],
                `PREAMBLE,
                byte_val
              )
            )

          end

        end
        else if (byte_cnt[agent] == 6) begin

          if (byte_val != `SFD) begin

            `uvm_warning(
              "PFC_SFD_ERR",
              $sformatf(
                "Agent=%0d Expected=%02h Got=%02h",
                agent,
                `SFD,
                byte_val
              )
            )

          end

        end


        byte_cnt[agent]++;

      end


      `uvm_info(
        "PFC_PREAMBLE_OK",
        $sformatf(
          "Agent=%0d First beat parsed | Bytes=%0d | RXD=0x%016h",
          agent,
          byte_cnt[agent],
          v_intf[agent].RXD
        ),
        UVM_DEBUG
      )


      //============================================================//
      // REMAINING BEATS
      //============================================================//

      while (frame_rx_active) begin

        @(posedge v_intf[agent].RX_CLK);


        for (lane = 0; lane < 8; lane++) begin


          //========================================================//
          // TERMINATE
          //========================================================//

          if (
            v_intf[agent].RXC[lane] &&
            v_intf[agent].RXD[(lane*8)+:8] == `XLGMII_TERM
          ) begin

            frame_rx_active = 0;

            break;

          end


          //========================================================//
          // Capture byte
          //========================================================//

          byte_val =
            v_intf[agent].RXD[(lane*8)+:8];

          frame_q[agent].push_back(byte_val);


          //========================================================//
          // Destination address
          //========================================================//

          if (byte_cnt[agent] == 12) begin

            da[agent] = {

              frame_q[agent][7],
              frame_q[agent][8],
              frame_q[agent][9],
              frame_q[agent][10],
              frame_q[agent][11],
              frame_q[agent][12]

            };

          end


          //========================================================//
          // Source address
          //========================================================//

          if (byte_cnt[agent] == 18) begin

            sa[agent] = {

              frame_q[agent][13],
              frame_q[agent][14],
              frame_q[agent][15],
              frame_q[agent][16],
              frame_q[agent][17],
              frame_q[agent][18]

            };

          end


          //========================================================//
          // EtherType / Opcode
          //========================================================//

          if (byte_cnt[agent] == 24) begin

            ether_type[agent] = {

              frame_q[agent][19],
              frame_q[agent][20]

            };


            opcode[agent] = {

              frame_q[agent][21],
              frame_q[agent][22]

            };


            //======================================================//
            // PFC frame
            //======================================================//

            if (
              ether_type[agent] == 16'h8808 &&
              opcode[agent]     == 16'h0101
            ) begin

              priority_vector[agent] = {

                frame_q[agent][23],
                frame_q[agent][24]

              };

              total_pfc_frames[agent]++;


              `uvm_info(
                "PFC_FRAME_FINAL",
                $sformatf(
                  "Agent=%0d VALID PFC ET=%04h OP=%04h PV=%04h",
                  agent,
                  ether_type[agent],
                  opcode[agent],
                  priority_vector[agent]
                ),
                UVM_LOW
              )

            end


            //======================================================//
            // Normal VLAN packet
            //======================================================//

            else begin

              vlan_tpid = {

                frame_q[agent][19],
                frame_q[agent][20]

              };


              vlan_tci = {

                frame_q[agent][21],
                frame_q[agent][22]

              };


              vlan_pcp[agent] =
                vlan_tci[15:13];


              loop_brk[agent] = 1;

              frame_rx_active = 0;


              `uvm_info(
                "VLAN_PKTS",
                $sformatf(
                  "Agent=%0d TPID=%04h TCI=%04h PCP=%0d",
                  agent,
                  vlan_tpid,
                  vlan_tci,
                  vlan_pcp[agent]
                ),
                UVM_DEBUG
              )


              break;

            end

          end


          byte_cnt[agent]++;

        end

      end


      //============================================================//
      // Raw frame dump
      //============================================================//

      frame_dump_str = "";


      foreach (frame_q[agent][idx]) begin

        if ((idx % 16) == 0) begin

          frame_dump_str = {

            frame_dump_str,

            $sformatf(
              "\n  [%03d] : ",
              idx
            )

          };

        end


        frame_dump_str = {

          frame_dump_str,

          $sformatf(
            "%02h ",
            frame_q[agent][idx]
          )

        };

      end


      `uvm_info(
        "FRAME_Q_RAW",
        $sformatf(
          "\n--- PFC frame Agent=%0d Size=%0d ---\n%s\n",
          agent,
          frame_q[agent].size(),
          frame_dump_str
        ),
        UVM_DEBUG
      )


      //============================================================//
      // PFC DECODE
      //============================================================//

      if (priority_vector[agent] != 0) begin


        `uvm_info(
          "PFC_DECODE",
          $sformatf(
            {"\n================ PFC FRAME DECODED ================\n",
             "Agent          : %0d\n",
             "DA             : %02h:%02h:%02h:%02h:%02h:%02h\n",
             "SA             : %02h:%02h:%02h:%02h:%02h:%02h\n",
             "EtherType      : %04h\n",
             "Opcode         : %04h\n",
             "PriorityVector : %04h\n",
             "===================================================="},
            agent,

            frame_q[agent][7],
            frame_q[agent][8],
            frame_q[agent][9],
            frame_q[agent][10],
            frame_q[agent][11],
            frame_q[agent][12],

            frame_q[agent][13],
            frame_q[agent][14],
            frame_q[agent][15],
            frame_q[agent][16],
            frame_q[agent][17],
            frame_q[agent][18],

            ether_type[agent],
            opcode[agent],
            priority_vector[agent]
          ),
          UVM_LOW
        )


        //==========================================================//
        // Process each active PCP
        //==========================================================//

        for (p = 0; p < 8; p++) begin


          pfc_quanta[agent][p] = {

            frame_q[agent][25+(p*2)],
            frame_q[agent][26+(p*2)]

          };


          if (priority_vector[agent][p]) begin


            `uvm_info(
              "PFC_QUANTA",
              $sformatf(
                "Agent=%0d PCP=%0d ACTIVE | Quanta=%0d | PauseByteTimes=%0d | ExpectedCycles=%0d",
                agent,
                p,
                pfc_quanta[agent][p],
                pfc_quanta[agent][p] * 64,
                pfc_quanta[agent][p] * 8
              ),
              UVM_LOW
            )


            //======================================================//
            // New PFC command -> new generation
            //======================================================//

            pfc_generation[agent][p]++;


            pfc_override_en[agent][p] = 0;

            loop_brk_p[agent][p]    = 0;
            loop_brk_done[agent][p] = 0;


            //======================================================//
            // Save in-flight frame
            //======================================================//

            if (frame_active[agent]) begin

              pfc_inflight_frame_id[agent][p] =
                tx_frame_id[agent];


              `uvm_info(
                "PFC_INFLIGHT_SAVE",
                $sformatf(
                  "Agent=%0d PCP=%0d PFC arrived while TX FrameID=%0d was active. Existing frame is allowed to finish.",
                  agent,
                  p,
                  tx_frame_id[agent]
                ),
                UVM_LOW
              )

            end
            else begin

              pfc_inflight_frame_id[agent][p] =
                tx_frame_id[agent];


              `uvm_info(
                "PFC_NO_INFLIGHT",
                $sformatf(
                  "Agent=%0d PCP=%0d no TX frame active. Current FrameID=%0d",
                  agent,
                  p,
                  tx_frame_id[agent]
                ),
                UVM_DEBUG
              )

            end


            //======================================================//
            // XON
            //======================================================//

            if (pfc_quanta[agent][p] == 0) begin

              pfc_xoff_en[agent][p] = 0;

              pfc_task_active[agent][p] = 0;

              pause_time[agent][p] = 0;

              clk[agent][p] = 0;


              `uvm_info(
                "PFC_XON",
                $sformatf(
                  "Agent=%0d PCP=%0d XON received. Generation=%0d",
                  agent,
                  p,
                  pfc_generation[agent][p]
                ),
                UVM_LOW
              )

            end


            //======================================================//
            // XOFF
            //======================================================//

            else begin

              pfc_xoff_en[agent][p] = 1;


              fork

                automatic int ag = agent;

                automatic int pr = p;

                automatic int unsigned gen =
                  pfc_generation[agent][p];

                automatic int unsigned q =
                  pfc_quanta[agent][p];

                begin

                  check_pfc_pausing_time(
                    ag,
                    pr,
                    q,
                    gen
                  );

                end

              join_none

            end

          end

        end

      end

    end

  endtask


  //****************************************************************//
  //****************************************************************//
  //                  TX FRAME SAMPLER
  //****************************************************************//
  //****************************************************************//

  task sample_transmitter(int i);

    int lane;

    bit [7:0] byte_val;


    forever begin


      //============================================================//
      // Reset TX frame state
      //============================================================//

      byte_count[i] = 0;

      frame_active[i] = 0;

      tx_pcp_valid[i] = 0;

      tx_pfc_frame[i] = 0;

      tx_ether_type[i] = 0;

      tx_opcode_or_tci[i] = 0;

      tx_vlan_pcp[i] = 0;


      //============================================================//
      // Wait for START
      //============================================================//

      forever begin

        @(posedge v_intf[i].TX_CLK);


        if (
          v_intf[i].TXC[0] &&
          v_intf[i].TXD[7:0] == `XLGMII_START
        ) begin


          //========================================================//
          // NEW TX FRAME
          //========================================================//

          tx_frame_id[i]++;


          frame_active[i] = 1;


          actual_no_of_pkts[i]++;


          tx_pcp_valid[i] = 0;

          tx_pfc_frame[i] = 0;


          `uvm_info(
            "TX_FRAME_START",
            $sformatf(
              "Agent=%0d NEW TX FrameID=%0d",
              i,
              tx_frame_id[i]
            ),
            UVM_DEBUG
          )


          break;

        end

      end


      //============================================================//
      // START beat lanes 1..7
      //============================================================//

      for (lane = 1; lane < 8; lane++) begin


        byte_val =
          v_intf[i].TXD[(lane*8)+:8];


        //==========================================================//
        // EtherType byte 19
        //==========================================================//

        if (byte_count[i] == 19)
          tx_ether_type[i][15:8] = byte_val;


        //==========================================================//
        // EtherType byte 20
        //==========================================================//

        if (byte_count[i] == 20)
          tx_ether_type[i][7:0] = byte_val;


        //==========================================================//
        // Byte 21
        //==========================================================//

        if (byte_count[i] == 21) begin

          tx_vlan_pcp[i] =
            byte_val[7:5];

          tx_opcode_or_tci[i][15:8] =
            byte_val;

          tx_pcp_valid[i] = 1;

        end


        //==========================================================//
        // Byte 22
        //==========================================================//

        if (byte_count[i] == 22) begin

          tx_opcode_or_tci[i][7:0] =
            byte_val;


          tx_pfc_frame[i] =
            (
              tx_ether_type[i] == 16'h8808 &&
              tx_opcode_or_tci[i] == 16'h0101
            );


          if (tx_pfc_frame[i]) begin

            `uvm_info(
              "TX_PFC_CTRL_DETECTED",
              $sformatf(
                "Agent=%0d FrameID=%0d outgoing PFC control frame detected",
                i,
                tx_frame_id[i]
              ),
              UVM_DEBUG
            )

          end

        end


        byte_count[i]++;

      end


      //============================================================//
      // Remaining TX beats
      //============================================================//

      while (frame_active[i]) begin


        @(posedge v_intf[i].TX_CLK);


        for (lane = 0; lane < 8; lane++) begin


          //========================================================//
          // TERMINATE
          //========================================================//

          if (
            v_intf[i].TXC[lane] &&
            v_intf[i].TXD[(lane*8)+:8] == `XLGMII_TERM
          ) begin

            frame_active[i] = 0;


            `uvm_info(
              "TX_SAMPLE_OK",
              $sformatf(
                "Agent=%0d FrameID=%0d Pkt#=%0d Bytes=%0d PCP=%0d PCPValid=%0d IsPFC=%0d",
                i,
                tx_frame_id[i],
                actual_no_of_pkts[i],
                byte_count[i],
                tx_vlan_pcp[i],
                tx_pcp_valid[i],
                tx_pfc_frame[i]
              ),
              UVM_DEBUG
            )


            break;

          end


          //========================================================//
          // Capture TX byte
          //========================================================//

          byte_val =
            v_intf[i].TXD[(lane*8)+:8];


          //========================================================//
          // EtherType
          //========================================================//

          if (byte_count[i] == 19)
            tx_ether_type[i][15:8] = byte_val;


          if (byte_count[i] == 20)
            tx_ether_type[i][7:0] = byte_val;


          //========================================================//
          // PCP byte
          //========================================================//

          if (byte_count[i] == 21) begin

            tx_vlan_pcp[i] =
              byte_val[7:5];

            tx_opcode_or_tci[i][15:8] =
              byte_val;

            tx_pcp_valid[i] = 1;

          end


          //========================================================//
          // Opcode / PFC detect
          //========================================================//

          if (byte_count[i] == 22) begin

            tx_opcode_or_tci[i][7:0] =
              byte_val;


            tx_pfc_frame[i] =
              (
                tx_ether_type[i] == 16'h8808 &&
                tx_opcode_or_tci[i] == 16'h0101
              );


            if (tx_pfc_frame[i]) begin

              `uvm_info(
                "TX_PFC_CTRL_DETECTED",
                $sformatf(
                  "Agent=%0d FrameID=%0d outgoing PFC control frame detected",
                  i,
                  tx_frame_id[i]
                ),
                UVM_DEBUG
              )

            end

          end


          byte_count[i]++;

        end

      end


      //============================================================//
      // Reset TX byte count after frame
      //============================================================//

      byte_count[i] = 0;

    end

  endtask


  //****************************************************************//
  //****************************************************************//
  //                    PFC PAUSE TIMER
  //****************************************************************//
  //****************************************************************//

  task check_pfc_pausing_time(
      int agent,
      int p,
      int quanta,
      int unsigned my_generation
  );


    localparam int NUM_LANES = `NO_OF_LANES;


    int expected_clk;

    int cycle;

    int remaining_byte_times;


    //============================================================//
    // Timer already obsolete?
    //============================================================//

    if (
      my_generation !=
      pfc_generation[agent][p]
    ) begin

      `uvm_info(
        "PFC_TIMER_SUPERSEDED",
        $sformatf(
          "Agent=%0d PCP=%0d Timer generation=%0d is obsolete. Current generation=%0d",
          agent,
          p,
          my_generation,
          pfc_generation[agent][p]
        ),
        UVM_DEBUG
      )

      return;

    end


    //============================================================//
    // Mark active
    //============================================================//

    pfc_task_active[agent][p] = 1;

    pfc_xoff_en[agent][p] = 1;


    //============================================================//
    // Convert quanta to byte-times
    //============================================================//

    remaining_byte_times =
      quanta * 64;


    //============================================================//
    // Convert byte-times to clocks
    //============================================================//

    expected_clk =
      remaining_byte_times / NUM_LANES;


    pause_time[agent][p] =
      remaining_byte_times;

    clk[agent][p] =
      0;


    `uvm_info(
      "CHK_TIMER_START",
      $sformatf(
        "Agent=%0d PCP=%0d | Quanta=%0d | PauseByteTimes=%0d | XLGMIIBytesPerClock=%0d | ExpectedCycles=%0d | Generation=%0d | InflightFrameID=%0d",
        agent,
        p,
        quanta,
        remaining_byte_times,
        NUM_LANES,
        expected_clk,
        my_generation,
        pfc_inflight_frame_id[agent][p]
      ),
      UVM_LOW
    )


    //****************************************************************//
    // EXACTLY expected_clk TX clocks
    //****************************************************************//

    for (
      cycle = 1;
      cycle <= expected_clk;
      cycle++
    ) begin


      @(posedge v_intf[agent].TX_CLK);


      //============================================================//
      // New PFC overrides old timer
      //============================================================//

      if (
        my_generation !=
        pfc_generation[agent][p]
      ) begin

        `uvm_info(
          "CHK_TIMER_OVERRIDE",
          $sformatf(
            "Agent=%0d PCP=%0d generation=%0d overridden by generation=%0d at cycle=%0d/%0d",
            agent,
            p,
            my_generation,
            pfc_generation[agent][p],
            cycle,
            expected_clk
          ),
          UVM_LOW
        )

        return;

      end


      //============================================================//
      // XON
      //============================================================//

      if (!pfc_xoff_en[agent][p]) begin

        `uvm_info(
          "CHK_TIMER_XON",
          $sformatf(
            "Agent=%0d PCP=%0d XON received before expiry at cycle=%0d/%0d",
            agent,
            p,
            cycle,
            expected_clk
          ),
          UVM_LOW
        )


        pfc_task_active[agent][p] = 0;

        return;

      end


      //============================================================//
      // Remaining pause time
      //============================================================//

      remaining_byte_times =
        (expected_clk - cycle) * NUM_LANES;


      pause_time[agent][p] =
        remaining_byte_times;

      clk[agent][p] =
        cycle;


      //****************************************************************//
      //                    NEW FRAME CHECK
      //****************************************************************//
      //
      // Existing frame:
      //
      //   tx_frame_id == pfc_inflight_frame_id
      //
      // It was already transmitting when PFC arrived.
      //
      // Therefore it is allowed.
      //
      //
      // New frame:
      //
      //   tx_frame_id != pfc_inflight_frame_id
      //
      // It started after PFC.
      //
      // It must be checked.
      //****************************************************************//

      if (
        frame_active[agent] &&
        tx_pcp_valid[agent] &&
        tx_frame_id[agent] !=
        pfc_inflight_frame_id[agent][p]
      ) begin


        //==========================================================//
        // Check this TX frame only once
        //==========================================================//

        if (
          tx_frame_id[agent] !=
          pfc_last_checked_frame_id[agent][p]
        ) begin


          //--------------------------------------------------------//
          // Mark it as checked BEFORE doing the comparison.
          //--------------------------------------------------------//

          pfc_last_checked_frame_id[agent][p] =
            tx_frame_id[agent];


          //--------------------------------------------------------//
          // Outgoing PFC control frame is always allowed.
          //--------------------------------------------------------//

          if (tx_pfc_frame[agent]) begin

            `uvm_info(
              "PFC_CTRL_EXEMPT",
              $sformatf(
                "Agent=%0d paused PCP=%0d NEW FrameID=%0d is PFC control frame -> allowed",
                agent,
                p,
                tx_frame_id[agent]
              ),
              UVM_LOW
            )

          end


          //--------------------------------------------------------//
          // Same PCP -> violation
          //--------------------------------------------------------//

          else if (
            tx_vlan_pcp[agent] == p
          ) begin

            `uvm_error(
              "PFC_ERR",
              $sformatf(
                "Agent=%0d PFC violation! NEW FrameID=%0d drove paused PCP=%0d at cycle=%0d/%0d",
                agent,
                tx_frame_id[agent],
                p,
                cycle,
                expected_clk
              )
            )

          end


          //--------------------------------------------------------//
          // Different PCP -> allowed
          //--------------------------------------------------------//

          else begin

            `uvm_info(
              "PFC_NEW_FRAME_ALLOWED",
              $sformatf(
                "Agent=%0d paused PCP=%0d | NEW FrameID=%0d TX PCP=%0d -> allowed",
                agent,
                p,
                tx_frame_id[agent],
                tx_vlan_pcp[agent]
              ),
              UVM_DEBUG
            )

          end

        end

      end


      //============================================================//
      // Timer debug
      //============================================================//

      `uvm_info(
        "CHK_TIMER",
        $sformatf(
          "Agent=%0d PCP=%0d | Cycle=%0d/%0d | RemainingCycles=%0d | RemainingByteTimes=%0d | TXFrameID=%0d | InflightFrameID=%0d",
          agent,
          p,
          cycle,
          expected_clk,
          expected_clk - cycle,
          remaining_byte_times,
          tx_frame_id[agent],
          pfc_inflight_frame_id[agent][p]
        ),
        UVM_DEBUG
      )

    end


    //============================================================//
    // Normal expiry
    //============================================================//

    if (
      my_generation ==
      pfc_generation[agent][p]
    ) begin

      pfc_task_active[agent][p] = 0;

      pfc_xoff_en[agent][p] = 0;

      pause_time[agent][p] = 0;

      clk[agent][p] = 0;


      `uvm_info(
        "CHK_TIMER_EXPIRED",
        $sformatf(
          "Agent=%0d PCP=%0d | Quanta=%0d | Completed=%0d/%0d cycles | Pause expired normally | Generation=%0d",
          agent,
          p,
          quanta,
          expected_clk,
          expected_clk,
          my_generation
        ),
        UVM_LOW
      )

    end

  endtask


endclass

