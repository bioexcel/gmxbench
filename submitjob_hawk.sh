#============
# HAWK
#=============

OMPLACE_OPTIONS="-nt $THREADSPERRANK"

if [ "$SMT" == "2" ]; then
    OMPLACE_OPTIONS=${OMPLACE_OPTIONS}" -ht compact"
fi

# Write job script
cat > job.script <<EOF
#!/bin/bash -l
#PBS -N $BENCHMARK_NAME
#PBS -l select=$NODES:mpiprocs=$RANKSPERNODE:ompthreads=$THREADSPERRANK
#PBS -l walltime=$WALLTIME             

# Change to the directory that the job was submitted from
cd \$PBS_O_WORKDIR

module list

export OMP_NUM_THREADS=$THREADSPERRANK

mpirun -np $TOTALRANKS omplace $OMPLACE_OPTIONS -v $EXE mdrun -s $BENCHMARK $MDRUN_CMD

rm -f *.trr *.cpt core*

EOF

qsub job.script

