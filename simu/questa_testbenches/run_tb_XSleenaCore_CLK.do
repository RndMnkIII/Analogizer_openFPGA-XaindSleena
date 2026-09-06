# run.do - QuestaSim/ModelSim compile + simulate for XSleenaCore_CLK
# Usage:  vsim -c -do run.do        (batch)
#     or  do run.do                 (from the GUI prompt)
#
# The DUT depends on these TTL primitive modules; make sure their .sv files
# are present in this folder (the glob below compiles every *.sv):
#   ttl_74163a_sync, ttl_74161_sync, ttl_74174_sync, ttl_74273_sync,
#   ttl_74112_sync, ttl_74139, ttl_74138, DFF_pseudoAsyncClrPre
#
# To turn off VCD (faster, waves only inside QuestaSim):
#   change the vlog line to:  vlog -sv +define+NO_VCD *.sv
# To dump only DUT top-level ports (smaller .vcd):
#   vlog -sv +define+VCD_TOP_ONLY *.sv

# --- (re)create work library ---
if {[file exists work]} { vdel -all }
vlib work
vmap work work

# --- compile everything in this folder ---
vlog -sv *.sv

# --- elaborate & run ---
# -voptargs=+acc keeps full signal visibility for waves/VCD
# -t 1ps sets the time resolution (DUT uses 10ps, TB uses 1ps)
vsim -t 1ps -voptargs=+acc work.tb_XSleenaCore_CLK +SIM_MS=40 +P1_P2n=1

# --- waves ---
if {[file exists wave.do]} {
    do wave.do
} else {
    add wave -r /tb_XSleenaCore_CLK/dut/*
}

run -all
# In GUI you can zoom to fit with: wave zoom full
