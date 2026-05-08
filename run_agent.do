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
vlog -sv tb/agent.sv
vlog -sv standalone/tb_agent.sv

# Load simulation
vsim -voptargs=+acc work.tb_agent

# Run simulation
run -all

# Print coverage
coverage save -onexit coverage.ucdb