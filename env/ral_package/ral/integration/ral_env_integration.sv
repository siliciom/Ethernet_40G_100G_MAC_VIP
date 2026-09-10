// RAL integration for the DUT-less APB VIP.
//
// The register agent is an APB MASTER. There is intentionally no DUT/APB
// slave connected in this VIP. The driver's reg_mem remains the register
// state/response model.
//
// eth_env already connects the RAL model to ral_reg_agent.seqr and connects
// ral_reg_agent.mon.analysis_port to the RAL predictor.
//
// APB interface configuration from the test/top should be:
//
//   uvm_config_db#(virtual apb_if)::set(null,
//       "uvm_test_top.env.ral_reg_agent.drv", "vif", apb_vif);
//   uvm_config_db#(virtual apb_if)::set(null,
//       "uvm_test_top.env.ral_reg_agent.mon", "vif", apb_vif);
//
// APB behavior in this VIP:
//   * PCLK is the APB clock.
//   * SETUP:  PSEL=1, PENABLE=0.
//   * ACCESS: PSEL=1, PENABLE=1.
//   * PREADY is permanently 1'b1 because there is no slave wait-state logic.
//   * PSLVERR is driven 1'b0.
//   * PRDATA is driven by reg_driver from reg_mem for reads.
//   * Writes update reg_mem.
//
// RAL auto prediction remains disabled; the monitor transaction is sent to
// the predictor so the RAL mirror is updated from the APB transaction.
