#====================================================
# QuestaSim script to test RAMS
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
vlog -sv standalone/tb_ram.sv

# Load simulation
vsim -voptargs=+acc work.tb_ram

# Add waves
add wave -radix hex /tb_ram/ram_dut/*

# Run simulation
run -all

# Print coverage
coverage save -onexit coverage.ucdb