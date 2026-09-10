class error_cb extends uvm_callback;
  `uvm_object_utils(error_cb)

  bit bad_fcs_en;
  bit ctrl_error_en;
  bit len_mismatch_en;
  bit bad_preamble_en;
  bit invalid_control_en;
  bit start_char_en;
  bit end_char_en;
  bit missing_terminate_en;
  bit data_txc_error_en;

  function new(string name = "error_cb");
    super.new(name);
  endfunction

  virtual task inject_error(eth_seq_item tr);
    if (bad_fcs_en) begin
      tr.corrupt_fcs_en = 1;
      `uvm_info(get_name(), "Injected Bad FCS Error", UVM_LOW)
    end
    if (ctrl_error_en) begin
      tr.err_b      = 1;
      tr.err_offset = $urandom_range(23, 64);
      `uvm_info(get_name(), $sformatf("Injected Control Error at offset %0d", tr.err_offset),
                UVM_LOW)
    end
    if (len_mismatch_en) begin
      tr.ether_type = $urandom_range(46, 1500);
      `uvm_info(get_name(), "Injected Length/Payload Mismatch", UVM_LOW)
    end
    if (bad_preamble_en) begin
      tr.preamble[4] = 8'hFF;
      `uvm_info(get_name(), "Injected Bad Preamble Error", UVM_LOW)
    end

    if (invalid_control_en) begin
      tr.invalid = 1;
      `uvm_info(get_name(), "Injected Invalid character Error", UVM_LOW)
    end

    if (start_char_en) begin
      tr.start_char   = 1;
      tr.start_offset = $urandom_range(25, 64);
      `uvm_info(get_name(), "Injected start character Error in payload", UVM_LOW)
    end

    if (end_char_en) begin
      tr.end_char   = 1;
      tr.end_offset = $urandom_range(25, 64);
      `uvm_info(get_name(), "Injected end character Error in payload", UVM_LOW)
    end

    if (missing_terminate_en) begin
      tr.missing_terminate = 1;
      `uvm_info(get_name(), "Injected Missing Terminate Error", UVM_LOW)
    end

    if (data_txc_error_en) begin
      tr.data_txc_error  = 1;
      tr.data_txc_offset = $urandom_range(23, 64);

      `uvm_info(get_name(), $sformatf("Inject TXC=1 for DATA at offset %0d", tr.data_txc_offset),
                UVM_LOW)
    end

  endtask
endclass



