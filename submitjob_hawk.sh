#============
# HAWK
#=============

GMX_PATH=${EXE%"gmx_mpi"}

OMPLACE_OPTIONS="-nt $THREADSPERRANK"

if [ "$SMT" == "2" ]; then
    OMPLACE_OPTIONS=${OMPLACE_OPTIONS}" -ht compact"
fi


if [ "$TUNE_PME" == true ]; then
    LAUNCH_CMD="gmx_mpi tune_pme -np $TOTALRANKS -mdrun 'omplace $OMPLACE_OPTIONS -v gmx_mpi mdrun' -s ${BENCHMARK_NAME}.tpr $MDRUN_CMD"
else
    LAUNCH_CMD="mpirun -np $TOTALRANKS omplace $OMPLACE_OPTIONS -v gmx_mpi mdrun -s $BENCHMARK $MDRUN_CMD"
fi




# Write job script
cat > job.script <<EOF
#!/bin/bash -l
#PBS -N $BENCHMARK_NAME
#PBS -l select=$NODES:mpiprocs=$RANKSPERNODE:ompthreads=$THREADSPERRANK
#PBS -l walltime=$WALLTIME             

# Change to the directory that the job was submitted from
cd $PWD

module list

export PATH=$GMX_PATH:\$PATH

export OMP_NUM_THREADS=$THREADSPERRANK

$LAUNCH_CMD

rm -f *.trr *.cpt core*

EOF

qsub job.script

