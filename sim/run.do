# ============================================================
#  run.do  –  ModelSim simulation script
#  Usage: vsim -do sim/run.do
# ============================================================

# Create work library
vlib work
vmap work work

# Compile RTL sources
vlog -sv rtl/alu.sv
vlog -sv rtl/register_file.sv
vlog -sv rtl/control_unit.sv
vlog -sv rtl/imm_extend.sv
vlog -sv rtl/pipeline/if_stage.sv
vlog -sv rtl/pipeline/id_stage.sv
vlog -sv rtl/pipeline/ex_stage.sv
vlog -sv rtl/pipeline/mem_stage.sv
vlog -sv rtl/pipeline/wb_stage.sv
vlog -sv rtl/hazard/hazard_detection.sv
vlog -sv rtl/hazard/forwarding_unit.sv
vlog -sv rtl/riscv_core.sv
vlog -sv rtl/top.sv

# Compile testbench
vlog -sv sim/tb_top.sv

# Simulate
vsim -t 1ps work.tb_top

# Add waves
add wave -divider "Clock/Reset"
add wave /tb_top/clk
add wave /tb_top/rst

add wave -divider "IF Stage"
add wave -hex /tb_top/dut/pc_f
add wave -hex /tb_top/dut/instr_f

add wave -divider "ID Stage"
add wave -hex /tb_top/dut/pc_d
add wave -hex /tb_top/dut/instr_d
add wave -hex /tb_top/dut/rd1_d
add wave -hex /tb_top/dut/rd2_d

add wave -divider "EX Stage"
add wave -hex /tb_top/dut/alu_result_e_wire
add wave      /tb_top/dut/zero_e
add wave      /tb_top/dut/pc_src_e
add wave -hex /tb_top/dut/forward_a_e
add wave -hex /tb_top/dut/forward_b_e

add wave -divider "MEM Stage"
add wave -hex /tb_top/dut/alu_result_m
add wave -hex /tb_top/dut/read_data_m

add wave -divider "WB Stage"
add wave -hex /tb_top/dut/result_w
add wave      /tb_top/dut/reg_write_w
add wave -uns /tb_top/dut/rd_w

add wave -divider "Hazard Unit"
add wave /tb_top/dut/stall_f
add wave /tb_top/dut/stall_d
add wave /tb_top/dut/flush_e
add wave /tb_top/dut/flush_d

# Run
run -all

# View waveforms
wave zoom full
