
# SDRAM Controller Constraints for Cyclone V (Analogue Pocket)

create_clock -name clk -period 10.416 [get_ports clk]

# SDRAM external interface
set_input_delay -clock clk 2.0 [get_ports dq*]
set_output_delay -clock clk 2.0 [get_ports dq*]

# Disable false paths through asynchronous resets
set_false_path -from [get_ports reset]
