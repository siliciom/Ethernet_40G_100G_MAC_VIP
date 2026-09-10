Register Agent - APB Master
===========================

This agent is a DUT-less APB MASTER used by the RAL model.

Files:
  apb_if.sv       : APB interface and constant PREADY=1.
  reg_seq_item.sv : RAL bus transaction.
  reg_sequencer.sv
  reg_driver.sv   : Generates APB SETUP/ACCESS cycles and maintains reg_mem.
  reg_monitor.sv  : Samples completed APB ACCESS transfers.
  reg_agent.sv

There is intentionally no DUT/APB slave connected. The driver's reg_mem is
kept as the register-state model.

APB signals:
  Master -> PADDR, PSEL, PENABLE, PWRITE, PWDATA
  Slave  -> PRDATA, PREADY, PSLVERR

PREADY is permanently HIGH and PSLVERR is permanently LOW.
PCLK is the clock used for APB transfers.
