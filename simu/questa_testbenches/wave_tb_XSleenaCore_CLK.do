# wave.do - grouped signal layout for XSleenaCore_CLK
onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {Clocking / Reset}
add wave -noupdate /tb_XSleenaCore_CLK/clk
add wave -noupdate /tb_XSleenaCore_CLK/clk_12_cen
add wave -noupdate /tb_XSleenaCore_CLK/RSTn
add wave -noupdate /tb_XSleenaCore_CLK/P1_P2n

add wave -noupdate -divider {H counter}
add wave -noupdate /tb_XSleenaCore_CLK/dut/HCLK
add wave -noupdate /tb_XSleenaCore_CLK/dut/HCLKn
add wave -noupdate -radix hexadecimal /tb_XSleenaCore_CLK/dut/HN
add wave -noupdate -radix unsigned   /tb_XSleenaCore_CLK/dut/HPOS
add wave -noupdate -radix unsigned   /tb_XSleenaCore_CLK/dut/DHPOS
add wave -noupdate /tb_XSleenaCore_CLK/dut/M4Hn
add wave -noupdate /tb_XSleenaCore_CLK/dut/VCUNT
add wave -noupdate /tb_XSleenaCore_CLK/dut/DVCUNT

add wave -noupdate -divider {V counter}
add wave -noupdate /tb_XSleenaCore_CLK/dut/VI
add wave -noupdate -radix unsigned /tb_XSleenaCore_CLK/dut/VPOS
add wave -noupdate -radix unsigned /tb_XSleenaCore_CLK/dut/DVPOS
add wave -noupdate /tb_XSleenaCore_CLK/dut/IMS

add wave -noupdate -divider {Video sync / blank}
add wave -noupdate /tb_XSleenaCore_CLK/dut/HSYNC
add wave -noupdate /tb_XSleenaCore_CLK/dut/VSYNC
add wave -noupdate /tb_XSleenaCore_CLK/dut/VSYNC2
add wave -noupdate /tb_XSleenaCore_CLK/dut/CSYNC
add wave -noupdate /tb_XSleenaCore_CLK/dut/HBLKn
add wave -noupdate /tb_XSleenaCore_CLK/dut/VBLK
add wave -noupdate /tb_XSleenaCore_CLK/dut/VBLKn

add wave -noupdate -divider {Timing / control}
add wave -noupdate /tb_XSleenaCore_CLK/dut/T1n
add wave -noupdate /tb_XSleenaCore_CLK/dut/T2n
add wave -noupdate /tb_XSleenaCore_CLK/dut/T3n
add wave -noupdate /tb_XSleenaCore_CLK/dut/T3
add wave -noupdate /tb_XSleenaCore_CLK/dut/M0n
add wave -noupdate /tb_XSleenaCore_CLK/dut/M1n
add wave -noupdate /tb_XSleenaCore_CLK/dut/M2n
add wave -noupdate /tb_XSleenaCore_CLK/dut/M3n
add wave -noupdate /tb_XSleenaCore_CLK/dut/CLRn
add wave -noupdate /tb_XSleenaCore_CLK/dut/BLKn
add wave -noupdate /tb_XSleenaCore_CLK/dut/EDIT
add wave -noupdate /tb_XSleenaCore_CLK/dut/EDITn
add wave -noupdate /tb_XSleenaCore_CLK/dut/OBJCHG
add wave -noupdate /tb_XSleenaCore_CLK/dut/OBJCHGn
add wave -noupdate /tb_XSleenaCore_CLK/dut/OBJCLRn
add wave -noupdate /tb_XSleenaCore_CLK/dut/RAMCLRn
add wave -noupdate /tb_XSleenaCore_CLK/dut/OBCH

configure wave -namecolwidth  200
configure wave -valuecolwidth 90
configure wave -timelineunits us
update
WaveRestoreZoom {0 ns} {200 us}
