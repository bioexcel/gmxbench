#============
# PIZ DAINT
#=============
if [ "$SMT" == 1 ]; then
    HYPERTHREAD_HINT="nomultithread"
elif [ "$SMT" == 2 ]; then
    HYPERTHREAD_HINT="multithread"
fi

# Write job script
cat > job.script <<EOF
#!/bin/bash -l
#SBATCH --account prce08
#SBATCH --job-name=$BENCHMARK_NAME
#SBATCH --time=$WALLTIME
#SBATCH --partition=normal
#SBATCH --nodes=$NODES
#SBATCH --constraint=gpu
#SBATCH --ntasks-per-node=$RANKSPERNODE
#SBATCH --cpus-per-task=$THREADSPERRANK
#SBATCH --ntasks-per-core=$SMT
#SBATCH --hint=$HYPERTHREAD_HINT

module swap PrgEnv-cray PrgEnv-gnu
module load daint-gpu
module load cray-fftw 
module load craype-accel-nvidia60
module list

export CRAY_CUDA_MPS=1  # Should allow multiple MPI ranks to use GPU at the same time, otherwise only possible with thread-mpi on single node
export OMP_NUM_THREADS=$THREADSPERRANK

srun $EXE mdrun -s $BENCHMARK $MDRUN_CMD

rm -f *.trr *.cpt core*

EOF


sbatch job.script

