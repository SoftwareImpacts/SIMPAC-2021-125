#!/usr/bin/env bash

n_procs=$1
n_iters=$2
msg_size=$3
n_nodes=$4
#run_idx_low=$5
#run_idx_high=$6
#results_root=$7
run_idx=$5
example_paths_dir=$6
run_dir=$7
nd_start=$8
nd_iter=$9
nd_end=${10}
impl=${11}

source ${example_paths_dir}/example_paths_lsf.config
#example_paths_dir=$(pwd)


debugging_path=${run_dir}/debug
mkdir -p ${debugging_path}
app_config=${anacin_x_root}/apps/comm_pattern_generator/config/amg2013_msg_size_${msg_size}_niters_${n_iters}_ndp_${nd_start}_${nd_iter}_${nd_end}.json
#app_config=${anacin_x_root}/apps/comm_pattern_generator/config/message_race_msg_size_${msg_size}.json

#Set up csmpi configuration
trace_dir=${run_dir}
default_config="default_config_${impl}_run_${run_idx}.json"
mkdir -p ${trace_dir}
python3 ${csmpi_conf}/generate_config.py -o ${csmpi_conf}/${default_config} --backtrace_impl ${impl} -d ${trace_dir}
export CSMPI_CONFIG=${csmpi_conf}/${default_config}

# Create app config if doesn't exist
if [ ! -f "$app_config" ]; then
    python3 > ${debugging_path}/create_json_output.txt 2> ${debugging_path}/create_json_error.txt ${anacin_x_root}/apps/comm_pattern_generator/config/json_gen.py "amg2013" ${msg_size} ${n_iters} "${example_paths_dir}/../" ${nd_start} ${nd_iter} ${nd_end}
fi

#echo ${app_config}
# Trace execution
LD_PRELOAD=${pnmpi} PNMPI_LIB_PATH=${pnmpi_lib_path} PNMPI_CONF=${pnmpi_conf} mpirun -np ${n_procs} > ${debugging_path}/trace_exec_output.txt 2> ${debugging_path}/trace_exec_error.txt ${app_bin} ${app_config}
#mv dumpi-* ${run_dir}
#mv pluto_out* ${run_dir}

# Build event graph
mpirun -np ${n_procs} > ${debugging_path}/build_graph_output.txt 2> ${debugging_path}/build_graph_error.txt ${dumpi_to_graph_bin} ${dumpi_to_graph_config} ${run_dir}
event_graph=${run_dir}/event_graph.graphml

# Extract slices
mpirun -np ${n_procs} > ${debugging_path}/extract_slices_output.txt 2> ${debugging_path}/extract_slices_error.txt ${extract_slices_script} ${event_graph} ${slicing_policy} -o "slices"



if [ "yes" = "no" ]; then
for run_idx in `seq -f "%03g" ${run_idx_low} ${run_idx_high}`; 
do
    # Create needed paths
    run_dir=${results_root}/msg_size_${msg_size}/without_ninja/run_${run_idx}/
    mkdir -p ${run_dir}
    debugging_path=${run_dir}/debug
    mkdir -p ${debugging_path}
    app_config=${anacin_x_root}/apps/comm_pattern_generator/config/amg2013_msg_size_${msg_size}_niters_${n_iters}.json

    # Create app config if doesn't exist
    if [ ! -f "$app_config" ]; then
	python3 > ${debugging_path}/create_json_output.txt 2> ${debugging_path}/create_json_error.txt ${anacin_x_root}/apps/comm_pattern_generator/config/json_gen.py "amg2013" ${msg_size} ${n_iters} "${example_paths_dir}/../" ${nd_start} ${nd_iter} ${nd_end}
    fi

    # Trace execution
    LD_PRELOAD=${pnmpi} PNMPI_LIB_PATH=${pnmpi_lib_path} PNMPI_CONF=${pnmpi_conf} mpirun -np ${n_procs} > ${debugging_path}/trace_exec_output.txt 2> ${debugging_path}/trace_exec_error.txt ${app_bin} ${app_config}
    mv dumpi-* ${run_dir}
    mv pluto_out* ${run_dir}

    # Build event graph
    mpirun -np ${n_procs} > ${debugging_path}/build_graph_output.txt 2> ${debugging_path}/build_graph_error.txt ${dumpi_to_graph_bin} ${dumpi_to_graph_config} ${run_dir}
    event_graph=${run_dir}/event_graph.graphml

    # Extract slices
    mpirun -np ${n_procs} > ${debugging_path}/extract_slices_output.txt 2> ${debugging_path}/extract_slices_error.txt ${extract_slices_script} ${event_graph} ${slicing_policy} -o "slices"

    #cp ${event_graph} ${results_root}/../comm_pattern_graphs/graph_amg2013_niters_${n_iters}_nprocs_${n_procs}_msg_size_${msg_size}_run_${run_idx}.graphml

done

# Compute KDTS
mpirun -np ${n_procs} > ${debugging_path}/../../compute_kdts_output.txt 2> ${debugging_path}/../../compute_kdts_error.txt ${compute_kdts_script} "${results_root}/msg_size_${msg_size}/without_ninja/" ${graph_kernel} --slice_dir_name "slices" -o "kdts.pkl"
fi
