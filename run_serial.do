#====================================================
# QuestaSim script to test Serial
#====================================================

# Clean previous work
if {[file exists work]} {
    file delete -force work
}

# Create library
vlib work
vmap work work

# Compile all files in correct order
vlog -sv +define+QUESTA rtl/constants.sv
vlog -sv rtl/ram.sv
vlog -sv rtl/serial_bridge.sv
vlog -sv tb/serial_if.sv
vlog -sv tb/drv_ext.sv
vlog -sv standalone/serial_conv_part.sv
vlog -sv standalone/tb_serial.sv

# Load simulation
vsim -voptargs=+acc work.tb_serial

# Add waves
add wave -radix hex /tb_serial/vif/*
#add wave -radix hex /tb_serial/dut/ram_a_inst/rst
add wave -radix hex /tb_serial/dut/ram_b_rd_empty
add wave -radix hex /tb_serial/dut/serial_bridge_inst/rd_en
add wave -radix hex /tb_serial/dut/serial_bridge_inst/rd_valid
add wave -radix hex /tb_serial/dut/serial_bridge_inst/rd_data
add wave -radix hex /tb_serial/dut/serial_bridge_inst/rd_empty
add wave -radix hex /tb_serial/dut/serial_bridge_inst/wr_en
add wave -radix hex /tb_serial/dut/serial_bridge_inst/wr_data
add wave -radix hex /tb_serial/dut/serial_bridge_inst/wr_full
#add wave -radix hex /tb_serial/dut/serial_bridge_inst/state
#add wave -radix hex /tb_serial/dut/serial_bridge_inst/rd_buf

# Run simulation
run -all

# Print coverage
coverage save -onexit coverage.ucdb