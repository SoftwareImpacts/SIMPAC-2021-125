#!/usr/bin/env bash

n_procs=$1
n_iters=$2
msg_size=$3
n_nodes=$4
slurm_queue=$5
slurm_time_limit=$6
run_idx_low=$7
run_idx_high=$8
results_root=$9
example_paths_dir=${10}
nd_start=${11}
nd_iter=${12}
nd_end=${13}
impl=${14}

source ${example_paths_dir}/example_paths_slurm.config
#example_paths_dir=$(pwd)
#echo ${example_paths_dir}
#echo ${anacin_x_root}

function join_by { local IFS="$1"; shift; echo "$*"; }

proc_placement=("pack")
comm_pattern_run_script=${anacin_x_root}/apps/comm_pattern_generator/slurm/message_race_run.sh
n_procs_per_node=$((n_procs/n_nodes))

queue=${slurm_queue}
time_limit=${slurm_time_limit}

for proc_placement in ${proc_placement[@]};
do
    #echo "Launching run ${run_idx} for: proc. placement = ${proc_placement}, # procs. = ${n_procs}, msg. size = ${msg_size}"
    #echo "Submitting job for run ${run_idx} of the Message Race communication pattern on scheduler=slurm."

    runs_root=${results_root}/msg_size_${msg_size}/n_procs_${n_procs}/n_iters_${n_iters}/ndp_${nd_start}_${nd_iter}_${nd_end}/proc_placement_${proc_placement}/
    
    # Launch intra-execution jobs
    kdts_job_deps=()
    for run_idx in `seq -f "%03g" ${run_idx_low} ${run_idx_high}`; 
    do
    
	#echo "Launching run ${run_idx} for: proc. placement = ${proc_placement}, # procs. = ${n_procs}, msg. size = ${msg_size}"
        echo "Submitting job for run ${run_idx} of the Message Race communication pattern on scheduler=slurm."
	# Set up results dir
        run_dir=${runs_root}/run_${run_idx}/
        mkdir -p ${run_dir}
	
        comm_pattern_run_name=message_race_run_$(date +%s.%N)
	comm_pattern_run_stdout=$( sbatch -N ${n_nodes} -p ${queue} -J ${comm_pattern_run_name} -t ${time_limit} -n ${n_procs} --ntasks-per-node=$((n_procs_per_node+1)) ${comm_pattern_run_script} ${n_procs} ${msg_size} ${n_iters} ${proc_placement} ${run_dir} ${example_paths_dir} ${nd_start} ${nd_iter} ${nd_end} ${impl} )
        while [ -z "$comm_pattern_run_id" ]; do
            comm_pattern_run_id=$( sacct -n -X --format jobid --name ${comm_pattern_run_name} )
        done
        kdts_job_deps+=${comm_pattern_run_id}
        comm_pattern_run_id=""
	
    done # runs
    
    # Compute kernel distances for each slice
    kdts_job_dep_str=$( join_by : ${kdts_job_deps[@]} )
    cd ${runs_root}
    echo "Submitting job to compute KDTS data for Message Race communication pattern with $((run_idx_high+1)) runs on scheduler=slurm."
    compute_kdts_stdout=$( sbatch -N ${n_nodes} -p ${queue} -t ${time_limit} -n ${n_procs} --ntasks-per-node=$((n_procs_per_node+1)) -o compute_kdts_out.txt -e compute_kdts_err.txt --dependency=afterok:${kdts_job_dep_str} ${job_script_compute_kdts} ${n_procs} ${compute_kdts_script} ${runs_root} ${graph_kernel} )
    compute_kdts_job_id=$( echo ${compute_kdts_stdout} | sed 's/[^0-9]*//g' )
    
done # proc placement
