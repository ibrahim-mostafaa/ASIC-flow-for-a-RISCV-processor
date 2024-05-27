##############################################
########### 1. DESIGN SETUP ##################
##############################################

# Set your top module name as design
set design riscv_core

# Remove any residing directory for your top module from previous runs
sh rm -rf $design

# Set your source directory as sc_dir
set sc_dir "/home/standard_cell_libraries/NangateOpenCellLibrary_PDKv1_3_v2010_12"

# Set the search_path, link_library, and target_library Synopsys application variables
set_app_var search_path "/home/standard_cell_libraries/NangateOpenCellLibrary_PDKv1_3_v2010_12/lib/Front_End/Liberty/NLDM \
			 /home/ahesham/Desktop/rerun/rtl"
set_app_var link_library "* NangateOpenCellLibrary_ff1p25vn40c.db"
set_app_var target_library "NangateOpenCellLibrary_ff1p25vn40c.db"

# Create the MilkyWay library and open it
create_mw_lib   ./${design} \
                -technology $sc_dir/tech/techfile/milkyway/FreePDK45_10m.tf \
                -mw_reference_library $sc_dir/lib/Back_End/mdb \
                -hier_separator {/} \
                -bus_naming_style {[%d]} \
                -open

# Set user-defined variables for the TLU Plus estimating parasitics files; max, and min, and also the technology map file
set tlupmax "$sc_dir/tech/rcxt/FreePDK45_10m_Cmax.tlup"
set tlupmin "$sc_dir/tech/rcxt/FreePDK45_10m_Cmin.tlup"
set tech2itf "$sc_dir/tech/rcxt/FreePDK45_10m.map"

# Pass the above variables and let the ICC read it for parasitics estimation for wiring
set_tlu_plus_files -max_tluplus $tlupmax \
                   -min_tluplus $tlupmin \
     		   -tech2itf_map $tech2itf

# Import the gate-level netlist into the PnR tool's memory
import_designs  ../syn/output/${design}.v \
                -format verilog \
                -top ${design} \
                -cel ${design}

# Read the timing constraints file form synthesis step
read_sdc  ../syn/output/${design}.sdc

# Tell the tool that it is dealing with realistic clock tree for accurate timing extraction
set_propagated_clock [get_clocks clk_i]

# Save the current stage into CEL view and call it "${design}_1_imported"
save_mw_cel -as ${design}_1_imported

# Use the next comment to open already saved design
#open_mw_lib $design ${design}_1_imported

##############################################
########### 2. Floorplan #####################
##############################################

# Create Starting Floorplan (check manual for options)-core_utilization 0.6 \
create_floorplan -control_type aspect_ratio \
		 -core_utilization 0.25 \
		 -core_width 300 \
		 -core_height 300 \
                 -start_first_row -flip_first_row \
                 -left_io2core 12.4 -bottom_io2core 12.4 -right_io2core 12.4 -top_io2core 12.4

# Floorplan Constraints
# Set the maximum routing layer as the 5th highest metal layer (leaving the top 4 for power)
report_ignored_layers
remove_ignored_layers -all

# metal7,8,9,10 for power
set_ignored_layers -max_routing_layer metal6 

# Add placement blockage if needed to have specific parts of the die for routing
# Use the gui. Floorplan > Create Placement Blockage

# Initial Virtual Flat Placement (check manual for other options for different specs)
create_fp_placement -effort high -timing_driven -congestion_driven

save_mw_cel -as ${design}_2_fp

##################################################
########### 3. POWER NETWORK #####################
##################################################

# Defining Logical POWER/GROUND Connections
derive_pg_connection -power_net VDD  \
                     -ground_net VSS \
                     -power_pin VDD  \
                     -ground_pin VSS	
		     
# Define Power Ring 
set_fp_rail_constraints -set_ring -nets  {VDD VSS}               \
                        -horizontal_ring_layer { metal7 metal9 } \
                        -vertical_ring_layer { metal8 metal10 }  \
                        -ring_spacing 0.8                        \
                        -ring_width 5                            \
                        -ring_offset 0.8                         \
                        -extend_strap core_ring

# Define Power Mesh 
# 1st method
set_fp_rail_constraints -add_layer  -layer metal10 -direction vertical   -max_strap 128 -min_strap 20 -min_width 2.5 -spacing minimum
set_fp_rail_constraints -add_layer  -layer metal9  -direction horizontal -max_strap 128 -min_strap 20 -min_width 2.5 -spacing minimum
set_fp_rail_constraints -add_layer  -layer metal8  -direction vertical   -max_strap 128 -min_strap 20 -min_width 2.5 -spacing minimum
set_fp_rail_constraints -add_layer  -layer metal7  -direction horizontal -max_strap 128 -min_strap 20 -min_width 2.5 -spacing minimum
set_fp_rail_constraints -add_layer  -layer metal6  -direction vertical   -max_strap 128 -min_strap 20 -min_width 2.5 -spacing minimum


set_fp_rail_constraints -set_global

# Creating virtual PG pads
# Use the gui. Preroute > Create Virtual Power Pad
# Following points are from using the gui, 
# If placed wrong use the command remove_fp_virtual_pad -all to remove all placed virtual pads and place manually instead:
set die_llx [lindex [lindex [ get_attribute [get_die_area] bbox] 0] 0]
set die_lly [lindex [lindex [ get_attribute [get_die_area] bbox] 0] 1]
set die_urx [lindex [lindex [ get_attribute [get_die_area] bbox] 1] 0]
set die_ury [lindex [lindex [ get_attribute [get_die_area] bbox] 1] 1]

for {set i "[expr $die_llx + 20]"} {$i < "[expr $die_urx - 40]"} {set i [expr $i + 80]} {
	create_fp_virtual_pad -net VSS -point "{$i $die_lly}"
	create_fp_virtual_pad -net VDD -point "{[expr $i + 40] $die_lly}"

	create_fp_virtual_pad -net VSS -point "{$i $die_ury}"
	create_fp_virtual_pad -net VDD -point "{[expr $i + 40] $die_ury}"
}

for {set i "[expr $die_lly + 20]"} {$i < "[expr $die_ury - 40]"} {set i [expr $i + 80]} {
	create_fp_virtual_pad -net VSS -point "{$die_llx $i}"
	create_fp_virtual_pad -net VDD -point "{$die_llx [expr $i + 40]}"

	create_fp_virtual_pad -net VSS -point "{$die_urx $i}"
	create_fp_virtual_pad -net VDD -point "{$die_urx [expr $i + 40] }"
}

# Analyze IR-drop; Modify power network constraints and re-synthesize, as needed.
# Max IR is 2% of Nominal Supply. In our case, 0.02 x 1.1v= 22mv
synthesize_fp_rail  -nets {VDD VSS} -synthesize_power_plan -target_voltage_drop 22 -voltage_supply 1.1 -power_budget 500

# Generate the real power network
commit_fp_rail

# Set maximum metal layer in DRC for power network connections for standard cells 
set_preroute_drc_strategy -max_layer metal6

# Connect standard cells power and ground pins to the power and ground rings and straps
preroute_standard_cells -fill_empty_rows -remove_floating_pieces

# Analyze IR-drop; Modify power network constraints and re-synthesize, as needed.
analyze_fp_rail  -nets {VDD VSS} -power_budget 500 -voltage_supply 1.1

# Final Floorplan Assessment
# Updates fp placement after PG mesh creation.
create_fp_placement -incremental all


# Add Well Tie Cells
add_tap_cell_array -master   TAP \
                   -distance 30  \
                   -pattern  stagger_every_other_row

save_mw_cel -as ${design}_3_power

##############################################
########### 4. Placement #####################
##############################################

puts "start_place"

# Checks
# ignored layer
report_ignored_layers

# physical design and constraints 
check_physical_design -stage pre_place_opt
check_physical_constraints

# Initial placement (check manual for other options for different specs)
place_opt -effort high -power -congestion -optimize_icgs

# Perform incremental timing-driven (setup timing, by default) logic optimization with placement legalization (check manual for other options). 
psynopt -power

# Check legality of current placement 
check_legality











# Defining Power/Ground Nets and Pins			 
derive_pg_connection -power_net VDD  \
                     -ground_net VSS \
                     -power_pin VDD  \
                     -ground_pin VSS	

# Tie fixed values
set tie_pins [get_pins -all -filter "constant_value == 0 || constant_value == 1 && name !~ V* && is_hierarchical == false "]
derive_pg_connection -power_net VDD  \
                     -ground_net VSS \
                     -tie

if {[sizeof_collection $tie_pins] > 0 } {
	connect_tie_cells -objects $tie_pins \
                  -obj_type port_inst \
		  -tie_low_lib_cell  LOGIC0_X1 \
		  -tie_high_lib_cell LOGIC1_X1
}

puts "finish_place"

save_mw_cel -as ${design}_4_placed

##############################################
################ 5. CTS ######################
##############################################

puts "start_cts"

# Checks
# physical design and constraints 
check_physical_design -stage pre_clock_opt 
check_clock_tree 
report_clock_tree


# Constraints related to CTS
set_driving_cell -lib_cell BUF_X16 -pin Z [get_ports clk_i]

# Set Clock Control/Targets
set_clock_tree_options -clock_trees clk_i        \
                       -target_early_delay 0.1 \
                       -target_skew 0.5	       \
                       -max_capacitance 300    \
                       -max_fanout 10          \
                       -max_transition 0.3

set_clock_tree_options -clock_trees clk_i        \
                       -buffer_relocation true \
                       -buffer_sizing true     \
                       -gate_relocation true   \
                       -gate_sizing true 

# Selection of CTS cells
set_clock_tree_references -references [get_lib_cells */CLKBUF*] 

#set_clock_tree_references -references [get_lib_cells */BUF*] 
#set_clock_tree_references -references [get_lib_cells */INV*] 

# Check clock tree settings
report_clock_tree -settings

#pre-CTS  power  optimization before clock tree synthesis
set_optimize_pre_cts_power_options -low_power_placement true -merge_clock_gates true
set_optimize_pre_cts_power_options -honor_dont_touch
optimize_pre_cts_power
compile_clock_tree
# Clock Tree; Synhtesis, Optimization, and Routing (check manual for other options)
clock_opt -fix_hold_all_clocks -power -insert_self_gating

# Report Timing
report_timing
# Defining Power/Ground Nets and Pins			 
derive_pg_connection -power_net VDD  \
                     -ground_net VSS \
                     -power_pin VDD  \
                     -ground_pin VSS	
			 
save_mw_cel -as ${design}_5_cts

puts "finish_cts"

##############################################
########### 6. Routing   #####################
##############################################

# Before starting to route, add spare cells
insert_spare_cells -lib_cell {NOR2_X4 NAND2_X4} \
                   -num_instances 20 \
                   -cell_name SPARE_PREFIX_NAME \
                   -tie
set_dont_touch  [all_spare_cells] true
set_attribute [all_spare_cells]  is_soft_fixed true

puts "start_route"

# Checks
# physical design, nets and routeability
check_physical_design -stage pre_route_opt
all_ideal_nets
all_high_fanout -nets -threshold 100
check_routeability

# Define the delay model used to compute a timing arc delay value for a cell or net
set_delay_calculation_options -arnoldi_effort low
			      
# Set routing options
set_route_options -groute_timing_driven true \
                  -groute_incremental true \
                  -track_assign_timing_driven true \
                  -same_net_notch check_and_fix 

# Set Signal Integrity options
set_si_options -route_xtalk_prevention true \
               -delta_delay true \
               -min_delta_delay true \
               -static_noise true\
               -timing_window true 

# Initial Routing (check manual for other options)
set_route_opt_strategy -power_aware_optimization true
route_opt -effort medium -power -stage track -xtalk_reduction -incremental 


# Perform optimization for hold and congestion (check manual for other options)
psynopt  -only_hold_time -congestion

# Defining Power/Ground Nets and Pins	
derive_pg_connection -power_net VDD  \
                     -ground_net VSS \
                     -power_pin VDD  \
                     -ground_pin VSS
	
#route_eco -auto -search_repair_loop 5\
#-utilize_dangling_wires -scope local\
#-reroute modified_nets_first_then_others
save_mw_cel -as ${design}_6_routed

puts "finish_route"

##############################################
########### 7. Finishing #####################
##############################################

# Add Filler cells
insert_stdcell_filler -cell_without_metal {FILLCELL_X32 FILLCELL_X16 FILLCELL_X8 FILLCELL_X4 FILLCELL_X2 FILLCELL_X1} \
	              -connect_to_power VDD -connect_to_ground VSS

 
# Defining Power/Ground Nets and Pins	
derive_pg_connection -power_net VDD  \
                     -ground_net VSS \
                     -power_pin VDD  \
                     -ground_pin VSS	

save_mw_cel -as ${design}_7_finished

save_mw_cel -as ${design}

##############################################
########### 8. Checks and Outputs ############
##############################################

# Verify that power and ground nets are connected to all cells
verify_pg_nets  -pad_pin_connection all

# LVS
verify_lvs -ignore_floating_port -ignore_floating_net -check_open_locator -check_short_locator

# Set options for .gds file
set_write_stream_options -map_layer $sc_dir/tech/strmout/FreePDK45_10m_gdsout.map  -output_filling fill  -child_depth 20  -output_outdated_fill   -output_pin  {text geometry}

# Write your design in .gds file
write_stream -lib $design -format gds -cells $design ./output/${design}.gds

# Define rules for names in your gate-level netlist to comply with the Netlist Reader of your PnR tool
define_name_rules  no_case -case_insensitive
change_names -rule no_case -hierarchy
change_names -rule verilog -hierarchy

# Enforce ICC to not output any "assign" statements or any "tri" nets in your netlist
set verilogout_no_tri	 true
set verilogout_equation  false

# Write your design into .V gate-level netlist 
write_verilog -pg -no_physical_only_cells ./output/${design}_icc.v

# Write your design into .V gate-level netlist without power grid
write_verilog -no_physical_only_cells ./output/${design}_icc_nopg.v

# Extract parasitics and write them into .spef we take this file and .v file and run in star rc to obtain more accurate estimation then take the output file and apply it in prime time 
extract_rc
write_parasitics -output {./output/riscv_core.spef}

# Close Milkyway
close_mw_cel
close_mw_lib

exit
