#
# user core constraints
#
# put your clock groups in here as well as any net assignments
#

# ==============================================================================
# Set Input Delay
# ==============================================================================
# set_input_delay -clock dram_clk -max 6.4 [get_ports dram_dq[*]]
# set_input_delay -clock dram_clk -min 3.1 [get_ports dram_dq[*]]

# ==============================================================================
# Set Output Delay
# ==============================================================================
# tDH, hold time, spec is 0.8ns
# tDS, setup time, spec is 1.5ns
# set_output_delay -clock dram_clk -min -0.8 [get_ports {dram_a[*] dram_ba[*] dram_cke dram_dqm[*] dram_dq[*] dram_ras_n dram_cas_n dram_we_n}]
# set_output_delay -clock dram_clk -max 1.5 [get_ports {dram_a[*] dram_ba[*] dram_cke dram_dqm[*] dram_dq[*] dram_ras_n dram_cas_n dram_we_n}]

# set_clock_groups -asynchronous \
#  -group { bridge_spiclk } \
#  -group { clk_74a } \
#  -group { clk_74b } \
#  -group { dram_clk, sys_clk, vid_clk } \
#  -group { vid2_clk } \
#  -group { audio_clk0 } \
#  -group { audio_clk1 }

set_clock_groups -asynchronous \
 -group { bridge_spiclk } \
 -group { clk_74a } \
 -group { clk_74b } \
 -group { ic|core_pll|mf_pllbase_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk } \
 -group { ic|core_pll|mf_pllbase_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk } \
 -group { ic|core_pll|mf_pllbase_inst|altera_pll_i|general[2].gpll~PLL_OUTPUT_COUNTER|divclk } \
 -group { ic|core_pll|mf_pllbase_inst|altera_pll_i|general[3].gpll~PLL_OUTPUT_COUNTER|divclk } \
 -group { ic|core_pll|mf_pllbase_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk } \
 -group { ic|core_pll|mf_pllbase_inst|altera_pll_i|cyclonev_pll|counter[1].output_counter|divclk } \
 -group { ic|core_pll|mf_pllbase_inst|altera_pll_i|cyclonev_pll|counter[2].output_counter|divclk } \
 -group { ic|core_pll|mf_pllbase_inst|altera_pll_i|cyclonev_pll|counter[3].output_counter|divclk } \
 -group { ic|u_pocket_audio_mixer|audio_pll|mf_audio_pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk } \
 -group { ic|u_pocket_audio_mixer|audio_pll|mf_audio_pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk }

# Set False Path
set_false_path -from [get_ports {bridge_1wire}]
set_false_path -from [get_ports {bridge_spimiso}]
set_false_path -from [get_ports {bridge_spimosi}]
set_false_path -from [get_ports {bridge_spiss}]

set_false_path -to   [get_ports {bridge_1wire}]
set_false_path -to   [get_ports {bridge_spimiso}]
set_false_path -to   [get_ports {bridge_spimosi}]
set_false_path -to   [get_ports {scal_auddac}]
set_false_path -to   [get_ports {scal_audlrck}]
set_false_path -to   [get_ports {scal_audmclk}]
set_false_path -to   [get_ports {scal_clk}]
set_false_path -to   [get_ports {scal_de}]
set_false_path -to   [get_ports {scal_hs}]
set_false_path -to   [get_ports {scal_skip}]
set_false_path -to   [get_ports {scal_vid[*]}]
set_false_path -to   [get_ports {scal_vs}]


