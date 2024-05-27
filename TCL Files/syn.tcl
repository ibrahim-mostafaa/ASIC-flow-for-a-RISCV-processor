# Set your top module name as design
set design riscv_core

# Set the search_path, link_library, and target_library Synopsys application variables
set_app_var search_path "/home/standard_cell_libraries/NangateOpenCellLibrary_PDKv1_3_v2010_12/lib/Front_End/Liberty/NLDM"
set_app_var link_library "* NangateOpenCellLibrary_ff1p25vn40c.db"
set_app_var target_library "NangateOpenCellLibrary_ff1p25vn40c.db"

# Remove any residing work directory from previous runs
sh rm -rf work

# Make the directory work
sh mkdir -p work

# Set the directory work to be the work library for this synthesis run
define_design_lib work -path ./work

# Analyze and elaborate your top module
analyze -library work -format verilog ../rtl/${design}.v
elaborate $design -lib work

# Make sure that the current design is your top module in dc_shell memory
current_design 

# Check design for any inconsistencies
check_design

# Read the timing constraints file
source ./cons/cons.tcl

# Resolve references
link  

# Synthesize and optimize the gate-level netlist 
compile -boundary_optimization -map_effort medium -power_effort high -gate_clock
compile_ultra -gate_clock
# Report the area of your design
report_area > ./report/synth_area.rpt

# Report the cells in your design
report_cell > ./report/synth_cells.rpt

# Report Quality of results of your design
report_qor  > ./report/synth_qor.rpt

# Report any consumed DesignWare resources in your design 
report_resources > ./report/synth_resources.rpt

# Report the worst max. timing paths in your design
report_timing -max_paths 10 > ./report/synth_timing.rpt

# Report the power consumption of your design
report_power > ./report/synth_power.rpt

# Write the .SDC constraints file for your PnR tool  
write_sdc  output/${design}.sdc 

# Define rules for names in your gate-level netlist to comply with the Netlist Reader of your PnR tool
define_name_rules  no_case -case_insensitive
change_names -rule no_case -hierarchy
change_names -rule verilog -hierarchy

# Enforce DC to not output any "assign" statements or any "tri" nets in your netlist
set verilogout_no_tri	 true
set verilogout_equation  false

# Write your design into .V gate-level netlist
write -hierarchy -format verilog -output output/${design}.v 

# Write your design into .DDC internal Synopsys database
write -f ddc -hierarchy -output output/${design}.ddc     
