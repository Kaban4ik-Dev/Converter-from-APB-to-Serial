#====================================================
# QuestaSim script to test DUT
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
vlog -sv rtl/serial_bridge.sv
vlog -sv rtl/converter.sv
vlog -sv tb/apb_if.sv
vlog -sv tb/drv_int.sv
vlog -sv tb/serial_if.sv
vlog -sv tb/drv_ext.sv
vlog -sv tb/tests.sv
vlog -sv tb/tb_top.sv

# Load simulation
vsim -voptargs=+acc work.tb_top

# Add waves
add wave -radix hex /tb_top/apb_vif/*
add wave -radix hex /tb_top/s_vif/*

# Run simulation
run -all

# Print coverage
coverage save -onexit coverage.ucdb