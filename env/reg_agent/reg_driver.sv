class reg_driver extends uvm_driver #(reg_seq_item);

  `uvm_component_utils(reg_driver)

  virtual apb_if vif;

  // Keep the DUT-less register state. The VIP has no DUT/register target,
  // so this memory models the APB slave register space.
  bit [31:0] reg_mem[bit [31:0]];

  function new(string name = "reg_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("REG_DRV_VIF", "virtual apb_if not found")
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    reg_seq_item req;

    // APB IDLE defaults.
    vif.PSEL    <= 1'b0;
    vif.PENABLE <= 1'b0;
    vif.PWRITE  <= 1'b0;
    vif.PADDR   <= '0;
    vif.PWDATA  <= '0;
    vif.PRDATA  <= '0;
    vif.PSLVERR <= 1'b0;

    forever begin
      seq_item_port.get_next_item(req);

      // --------------------------------------------------------
      // APB SETUP phase: PSEL=1, PENABLE=0
      // --------------------------------------------------------
      @(posedge vif.PCLK);
      vif.PSEL <= 1'b1;
      vif.PENABLE <= 1'b0;
      vif.PWRITE <= req.write;
      vif.PADDR <= req.addr;
      vif.PWDATA <= req.write ? req.wdata : '0;
      vif.PSLVERR <= 1'b0;

      `uvm_info("REG_DRV", $sformatf(
                "APB SETUP: ADDR=0x%08h WRITE=%0d WDATA=0x%08h", req.addr, req.write, req.wdata),
                UVM_LOW)

      // --------------------------------------------------------
      // APB ACCESS phase: PSEL=1, PENABLE=1
      // PREADY is permanently HIGH from apb_if.
      // --------------------------------------------------------
      @(posedge vif.PCLK);
      vif.PENABLE <= 1'b1;

      if (req.write) begin
        // DUT-less APB slave model.
        reg_mem[req.addr] = req.wdata;
        req.rdata = '0;
        vif.PRDATA <= '0;
      end else begin
        if (reg_mem.exists(req.addr)) req.rdata = reg_mem[req.addr];
        else req.rdata = '0;

        vif.PRDATA <= req.rdata;
      end

      req.error    = 1'b0;
      req.response = 1'b0;
      vif.PSLVERR <= 1'b0;

      // PREADY is constant 1, so the transfer completes on this ACCESS cycle.
      `uvm_info("REG_DRV", $sformatf(
                "APB ACCESS COMPLETE: ADDR=0x%08h WRITE=%0d RDATA=0x%08h PREADY=%0d",
                req.addr,
                req.write,
                req.rdata,
                vif.PREADY
                ), UVM_LOW)

      // Return to APB IDLE.
      @(posedge vif.PCLK);
      vif.PSEL    <= 1'b0;
      vif.PENABLE <= 1'b0;
      vif.PWRITE  <= 1'b0;
      vif.PADDR   <= '0;
      vif.PWDATA  <= '0;
      vif.PRDATA  <= '0;
      vif.PSLVERR <= 1'b0;

      seq_item_port.item_done();
    end
  endtask

endclass
