utl::set_metrics_stage "globalplace__{}"
source $::env(SCRIPTS_DIR)/load.tcl
load_design 3_2_place_iop.odb 2_floorplan.sdc

set_dont_use $::env(DONT_USE_CELLS)

# set fastroute layer reduction
if {[info exist env(FASTROUTE_TCL)]} {
  source $env(FASTROUTE_TCL)
} else {
  set_global_routing_layer_adjustment $env(MIN_ROUTING_LAYER)-$env(MAX_ROUTING_LAYER) 0.5
  set_routing_layers -signal $env(MIN_ROUTING_LAYER)-$env(MAX_ROUTING_LAYER)
  if {[info exist env(MACRO_EXTENSION)]} {
    set_macro_extension $env(MACRO_EXTENSION)
  }
}

# check the lower boundary of the PLACE_DENSITY and add PLACE_DENSITY_LB_ADDON if it exists
if {[info exist ::env(PLACE_DENSITY_LB_ADDON)]} {
  set place_density_lb [gpl::get_global_placement_uniform_density \
  -pad_left $::env(CELL_PAD_IN_SITES_GLOBAL_PLACEMENT) \
  -pad_right $::env(CELL_PAD_IN_SITES_GLOBAL_PLACEMENT)]
  set place_density [expr $place_density_lb + ((1.0 - $place_density_lb) * $::env(PLACE_DENSITY_LB_ADDON)) + 0.01]
  if {$place_density > 1.0} {
    utl::error FLW 24 "Place density exceeds 1.0 (current PLACE_DENSITY_LB_ADDON = $::env(PLACE_DENSITY_LB_ADDON)). Please check if the value of PLACE_DENSITY_LB_ADDON is between 0 and 0.99."
  }
} else {
  set place_density $::env(PLACE_DENSITY)
}

set global_placement_args {}

# Parameters for routability mode in global placement
if {$::env(GPL_ROUTABILITY_DRIVEN)} {
  lappend global_placement_args {-routability_driven}
    if { [info exists ::env(GPL_TARGET_RC)] } { 
      lappend global_placement_args {-routability_target_rc_metric} $::env(GPL_TARGET_RC)
  }
}

# Parameters for timing driven mode in global placement
if {$::env(GPL_TIMING_DRIVEN)} {
  lappend global_placement_args {-timing_driven}
}

proc do_placement {place_density global_placement_args} {
  set all_args [concat [list -density $place_density \
    -pad_left $::env(CELL_PAD_IN_SITES_GLOBAL_PLACEMENT) \
    -pad_right $::env(CELL_PAD_IN_SITES_GLOBAL_PLACEMENT)] \
    $global_placement_args]

  if { 0 != [llength [array get ::env GLOBAL_PLACEMENT_ARGS]] } {
    lappend all_args {*}$::env(GLOBAL_PLACEMENT_ARGS)
  }

  log_cmd global_placement {*}$all_args
}

set result [catch {do_placement $place_density $global_placement_args} errMsg]
if {$result != 0} {
  write_db $::env(RESULTS_DIR)/3_3_place_gp-failed.odb
  error $errMsg
}

estimate_parasitics -placement

if {[info exist ::env(CLUSTER_FLOPS)]} {
  cluster_flops
  estimate_parasitics -placement
}

report_metrics 5 "global place" false false

write_db $::env(RESULTS_DIR)/3_3_place_gp.odb
