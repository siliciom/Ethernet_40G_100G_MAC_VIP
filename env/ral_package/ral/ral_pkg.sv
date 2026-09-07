package ral_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  `include "registers/eth_reg.sv"
  `include "reg_model.sv"
  `include "adapter/master_reg_adapter.sv"
  `include "predictor/master_reg_predictor.sv"
  //`include "slave/eth_slave_reg_state.sv"
  `include "sequences/ral_base_seq.sv"
  `include "sequences/reg_write_seq.sv"
  `include "sequences/reg_read_seq.sv"
  `include "sequences/reg_write_read_seq.sv"
  `include "sequences/all_reg_reset_seq.sv"
  `include "sequences/reg_access_test_seq.sv"
  `include "sequences/ral_smoke_test.sv"

endpackage
