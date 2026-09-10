RAL PACKAGE

Register model:
  25 x 32-bit registers
  Single field: Value[31:0]
  Access: RW
  Reset: 0
  Volatile: YES
  No reserved fields

Address map:
  0x0000 through 0x0060
  4-byte spacing
  Little endian

Usage:
  1. Add ral/ral.f to the simulator compile file list.
  2. Import ral_pkg::*.
  3. Instantiate/build eth_reg_block.
  4. Create master_reg_adapter.
  5. Connect default_map to the existing Master sequencer.
  6. Connect master monitor analysis_port to master_reg_predictor.bus_in.
  7. Disable auto prediction when using the explicit predictor.
  8. Reset both the RAL model and the DUT-less Slave register state.

The adapter contains a canonical master_reg_item because the
existing transaction class was not supplied. If the existing
Master agent already has an equivalent transaction, replace
master_reg_item in the adapter with that class rather than
creating a second transaction type.
