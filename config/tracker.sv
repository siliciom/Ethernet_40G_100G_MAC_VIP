//******************************************************************//
//              ETHERNET PACKET TRACKER FILE
//
// Defines the Ethernet packet tracker used to log transmitted and
// received packets for each MAC agent. It creates agent-specific
// log files and records packet information along with interface
// cycle-level traces for debugging and analysis.
//
//******************************************************************//
class eth_packet_tracker;
  // keyed by string "mac_0", "mac_1", ... — no dependency on NO_OF_AGENTS sizing
  static int fd[string];
  static bit opened[string];
  static string test_name_s;   // cached once, reused everywhere
 
  //--------------------------------------------------------------------------
  // Get (and cache) test name once
  //--------------------------------------------------------------------------
  static function string get_test_name();
    if (test_name_s == "") begin
      void'(uvm_cmdline_processor::get_inst().get_arg_value("+UVM_TESTNAME=", test_name_s));
      if (test_name_s == "")
        test_name_s = "default_test";
    end
    return test_name_s;
  endfunction
 
  //--------------------------------------------------------------------------
  // Extract numeric agent index from full hierarchical path
  // e.g. uvm_test_top.env_h.agnt_mac[0].drv_h  ->  returns 0
  //--------------------------------------------------------------------------
  static function int get_mac_index(string full_name);
    int start_pos, end_pos;
    string idx_str;
 
    start_pos = -1;
    for (int i = 0; i <= full_name.len()-9; i++) begin
      if (full_name.substr(i, i+8) == "agnt_mac[") begin
        start_pos = i + 9;
        break;
      end
    end
 
    if (start_pos == -1)
      return -1;
 
    end_pos = start_pos;
    while (end_pos < full_name.len() && full_name.substr(end_pos,end_pos) != "]")
      end_pos++;
 
    idx_str = full_name.substr(start_pos, end_pos-1);
    return idx_str.atoi();
  endfunction
 
  //--------------------------------------------------------------------------
  // Extract agent tag for filename, e.g. "mac_0"
  //--------------------------------------------------------------------------
  static function string get_mac_tag(string full_name);
    int idx = get_mac_index(full_name);
    if (idx == -1)
      return "mac_unknown";
    return $sformatf("mac_%0d", idx);
  endfunction
 
  //--------------------------------------------------------------------------
  // Open file for a specific agent (lazy, once per agent, on first use)
  //--------------------------------------------------------------------------
  static function void open_file(string mac_tag);
    string log_dir;
    string log_file;
    string tname;
 
    if (!opened.exists(mac_tag) || !opened[mac_tag]) begin
      tname = get_test_name();
 
      log_dir  = $sformatf("./sim/%s", tname);
      log_file = $sformatf("%s/eth_packet_tracker_%s.log", log_dir, mac_tag);
 
      fd[mac_tag] = $fopen(log_file, "w");
      $display("Tracker File Handle=%0d, path=%s", fd[mac_tag], log_file);
 
      if (fd[mac_tag] == 0)
        `uvm_fatal("TRACKER", $sformatf("Unable to open %s", log_file))
 
      $fdisplay(fd[mac_tag], "===============================================");
      $fdisplay(fd[mac_tag], "  Ethernet MAC VIP Packet Tracker - %s  ", mac_tag);
      $fdisplay(fd[mac_tag], "  Test Name  : %s", tname);
      $fdisplay(fd[mac_tag], "===============================================");
      $fflush(fd[mac_tag]);
 
      opened[mac_tag] = 1;
    end
  endfunction
 
  //--------------------------------------------------------------------------
  // Print Ethernet Frame
  // direction: "TX"/"DRV_TX" -> ==>(TX_PKT:MAC[n])
  //            "RX"/"MON_RX" -> <==(RX_PKT:MAC[n])
  // Pass this.get_full_name() from driver/monitor - no new variable needed
  //--------------------------------------------------------------------------
static function void print_packet(string direction,
                                     string full_name,
                                     eth_seq_item tr);
    string pkt;
    string mac_tag;
    int    mac_idx;
    string arrow;
    string dir_tag;
    string header_line;
 
    mac_tag = get_mac_tag(full_name);
    mac_idx = get_mac_index(full_name);
    open_file(mac_tag);
 
    if (direction.substr(direction.len()-2, direction.len()-1) == "TX") begin
      arrow   = "==>";
      dir_tag = direction;
    end
    else if (direction.substr(direction.len()-2, direction.len()-1) == "RX") begin
      arrow   = "<==";
      dir_tag = direction;
    end
    else begin
      arrow   = "--";
      dir_tag = direction;
    end
    header_line = $sformatf("%s(%s_PKT:MAC[%0d])", arrow, dir_tag, mac_idx);
 
    // ---------------- 1) Per-posedge cycle trace first ----------------
    // ---------------- 1) Per-posedge cycle trace first (TX only, if present) ----------------
    pkt = "";
    if (tr.tx_trace_q.size() > 0) begin
      pkt = {pkt, $sformatf("---------------- TX CYCLE TRACE (%s) ----------------\n", mac_tag)};
      foreach (tr.tx_trace_q[i]) begin
        pkt = {pkt, $sformatf("==>@%0t ns --> TXD=%016h TXC=%02h\n",
                               tr.tx_trace_q[i].t,
                               tr.tx_trace_q[i].txd,
                               tr.tx_trace_q[i].txc)};
      end
     // pkt = {pkt, "==============================================================\n"};
    end
    pkt = {pkt, "==============================================================\n"};
 
    // ---------------- 2) Full packet after all posedges ----------------
    pkt = {pkt, $sformatf("\n==============================================================\n")};
    pkt = {pkt, $sformatf("@%0t ns  Test=%s  %s\n", $realtime, get_test_name(), header_line)};
    pkt = {pkt, "==============================================================\n"};
    pkt = {pkt, $sformatf("DA           : %012h\n", tr.da)};
    pkt = {pkt, $sformatf("SA           : %012h\n", tr.sa)};
    pkt = {pkt, $sformatf("Length/Type  : %04h\n", tr.ether_type)};
    pkt = {pkt, $sformatf("CRC          : %08h\n", tr.crc)};
    pkt = {pkt, $sformatf("Payload Size : %0d Bytes\n", tr.payload.size())};
    pkt = {pkt, "Payload:\n"};
 
    for (int i = 0; i < tr.payload.size(); i += 16) begin
      pkt = {pkt, $sformatf("[%0d] = 'h", i)};
      for (int j = 0; j < 16; j++) begin
        if (i+j < tr.payload.size())
          pkt = {pkt, $sformatf("%02h ", tr.payload[i+j])};
      end
      pkt = {pkt, "\n"};
    end
    pkt = {pkt, "==============================================================\n"};
 
    $fdisplay(fd[mac_tag], "%s", pkt);
    $fflush(fd[mac_tag]);
  endfunction
 
  //--------------------------------------------------------------------------
  static function void close_file(string mac_tag);
    if (opened.exists(mac_tag) && opened[mac_tag]) begin
      $fclose(fd[mac_tag]);
      opened[mac_tag] = 0;
    end
  endfunction
 
  static function void close_all();
    string key;
    if (fd.first(key)) begin
      do close_file(key);
      while (fd.next(key));
    end
  endfunction
endclass
