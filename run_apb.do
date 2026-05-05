#====================================================
# QuestaSim script to test APB
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
vlog -sv rtl/apb_bridge.sv
vlog -sv tb/apb_if.sv
vlog -sv tb/drv_int.sv
vlog -sv standalone/apb_conv_part.sv
vlog -sv standalone/tb_apb.sv

# Load simulation
vsim -voptargs=+acc work.tb_apb

# Add waves
add wave -radix hex /tb_apb/vif/*
add wave -radix hex /tb_apb/dut/apb_bridge_inst/rd_en
add wave -radix hex /tb_apb/dut/apb_bridge_inst/rd_valid
add wave -radix hex /tb_apb/dut/apb_bridge_inst/rd_data

# Run simulation
run -all

# Print coverage
coverage save -onexit coverage.ucdb