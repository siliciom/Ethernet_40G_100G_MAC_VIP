`ifndef APB_IF_SV
`define APB_IF_SV

interface apb_if #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32
) (
    input logic PCLK,
    input logic PRESETn
);

  // APB master driven signals
  logic [ADDR_WIDTH-1:0] PADDR;
  logic                  PSEL;
  logic                  PENABLE;
  logic                  PWRITE;
  logic [DATA_WIDTH-1:0] PWDATA;

  // APB slave response signals
  logic [DATA_WIDTH-1:0] PRDATA;
  logic                  PSLVERR;

  // This VIP has no DUT/slave behind it, and the slave has no wait states.
  // Therefore PREADY is permanently asserted.
  wire                   PREADY = 1'b1;

endinterface

`endif
