#!/usr/bin/env bash

#SBATCH -o build_graph-%j.out
#SBATCH -e build_graph-%j.err

n_procs=$1
dumpi_to_graph_bin=$2
dumpi_to_graph_config=$3
trace_dir=$4

#echo $SLURM_JOB_ID

#echo $@

# Determine number of nodes we need to run on
#system=$(hostname | sed 's/[0-9]*//g')
#if [ ${system} == "quartz" ]; then
#    n_procs_per_node=36
#elif [ ${system} == "catalyst" ]; then
#    n_procs_per_node=24
#fi
#n_procs_per_node=32
#n_nodes=$(echo "(${n_procs} + ${n_procs_per_node} - 1)/${n_procs_per_node}" | bc)

mpirun -np ${n_procs} ${dumpi_to_graph_bin} ${dumpi_to_graph_config} ${trace_dir}
