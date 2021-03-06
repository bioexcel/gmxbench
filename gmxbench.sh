#!/bin/bash -l
#
# if using on mac os:
#  "brew install coreutils" to get GNU readlink
#  "brew install gnu-getopt"
#
# Needs gnuplot for plotting
#



usage()
{
    echo -e "\t usage: 
	     <submit | scan | extract | plot >
	     "
    exit 2
}










usage_submit()
{
    echo -e "\t SUBMIT usage: 
	      
	      Required:
	      --bench <path to benchmark tpr>
	      --exe <path to gmx executable>
	      --nodes <number of nodes>
	      --smt <number of hyperthreads>
	      --mpi <procs per node>
	      --omp <threads per proc>
	      --walltime <hh:mm:ss>
	      --machine <hawk | pizdaint>

	      Optional:
	      -nsteps 
	      -resetstep
	      -resethway
	      -npme
	      -pme 
	      -ntomp_pme
	      -nb
	      -bonded
	      -update
	      -pmefft 
	      -dlb <auto|no|yes>
	      -tunepme <on|off>
	      --extra_info	
	      
	      All options can be given in short (-) or long (--) form
	      Options shown in short form correspond verbatim to mdrun options
	      \n"	      
    exit 2
}










function parse_options()
{
    PARSED_ARGUMENTS=$(getopt -o '' -a -l 'bench:,exe:,smt:,mpi:,omp:,nodes:,gpu,walltime:,nsteps:,resetstep:,resethway,npme:,pme:,ntomp:,ntomp_pme:,nb:,bonded:,update:,pmefft:,dlb:,tunepme:,tune_pme,extra_info:,machine:,help:,v,noconfout' -- "$@")
    VALID_ARGUMENTS=$?
    if [ "$VALID_ARGUMENTS" != "0" ] || [ "$#" == "0" ]; then
	usage
    fi
}










function set_options()
{
    # Start of input parsing 
    if [ "$1" == "--help" ]; then
	usage
    fi
    
    eval set -- "$PARSED_ARGUMENTS"
    while :
    do
	case "$1" in
	    --help)
		HELP=true
		shift 2 ;;
	    --bench)
		BENCHMARK=$(readlink -f $2)
		shift 2 ;;
	    --exe)
		EXE="$2"
		shift 2 ;;
	    --gpu)
		GPU=true
		shift   ;;
	    --smt)
		SMT=$2
		shift 2 ;;
	    --mpi)
		RANKSPERNODE=$((10#$2)) # strip leading zeros
		shift 2 ;;
	    --omp)
		THREADSPERRANK=$((10#$2)) # strip leading zeros
		shift 2 ;;
	    --nodes)
		NODES="$2"
		shift 2 ;;
	    --walltime)
		WALLTIME="$2"
		shift 2 ;;
	    --nsteps)
		NSTEPS="$2"
		shift 2 ;;
            --resetstep)
		RESETSTEP="$2"
		shift 2 ;;
	    --resethway)
		RESETHWAY=true
		shift ;;
	    --pme)
		PME="$2"
		shift 2 ;;
	    --npme)
		NPME="$2"
		shift 2 ;;
	    --ntomp) # same as -omp
		THREADSPERRANK=$((10#$2)) # strip any leading zeros
		shift 2 ;;
	    --ntomp_pme)
		NTOMP_PME="$2"
		shift 2 ;;
	    --nb)
		NB="$2"
		shift 2 ;;
	    --bonded)
		BONDED="$2"
		shift 2 ;;
	    --update)
		UPDATE="$2"
		shift 2 ;;
	    --pmefft)
		PMEFFT="$2"
		shift 2 ;;
	    --dlb)
		DLB="$2"
		shift 2 ;;
	    --tunepme)
		TUNEPME="$2"
		shift 2 ;;
	    --tune_pme)
		TUNE_PME=true
		shift  ;;	
	    --extra_info)
		EXTRA_INFO="$2"
		shift 2 ;;
	    --machine)
		MACHINE="$2"
		shift 2 ;;
	    --noconfout)
		shift ;;
	    --v)
		shift ;;
	    --) shift; break ;;
	    *) echo "Unexpected option: $1 - this should not happen."
	       usage ;;
	esac
    done
}










function init_params()
{
    if [ -n "$RANKSPERNODE" ] && [ -n "$NODES" ]; then
	TOTALRANKS=$(($RANKSPERNODE*$NODES))
    fi
    
    # Ensure npme set to 1 if offloading PME to GPU
    if [ "$PME" = 'gpu' ] && [ "$TOTALRANKS" != "1" ]; then
	NPME_CMD='-npme 1 '
#	NPME_STR='_npme001'
    elif test -n "$NPME"; then
	NPME_CMD="-npme $NPME "
	NPME_STR="_npme$(printf "%03d" $NPME)"
    else
	unset NPME_CMD
	unset NPME_STR
    fi
    if test -n "$SMT"; then
	SMT_STR="_$(printf "%01d" $SMT)smt"
    fi
    if test -n "$RANKSPERNODE"; then
	RANKSPERNODE_STR="_$(printf "%03d" $RANKSPERNODE)mpi";
    fi
    if test -n "$THREADSPERRANK"; then
	THREADSPERRANK_CMD="-ntomp $THREADSPERRANK "
	THREADSPERRANK_STR="_$(printf "%03d" $THREADSPERRANK)omp"
    fi
    if test -n "$NODES"; then
	NODES_STR="_$(printf "%02d" $NODES)nodes";
    fi
    
    
    # GPU offload options
    if [ "${GPU}" == true ]; then
	if test -n "${NB}"; then
	    NB_CMD="-nb ${NB} "
	    NB_STR="_nb$(echo ${NB} | tr [a-z] [A-Z])"
	fi
	if test -n "${PME}"; then
	    PME_CMD="-pme ${PME} "
	    PME_STR="_pme$(echo ${PME} | tr [a-z] [A-Z])"
	fi
	if test -n "${BONDED}"; then
	    BONDED_CMD="-bonded ${BONDED} "
	    BONDED_STR="_bonded$(echo ${BONDED} | tr [a-z] [A-Z])"
	fi
	if test -n "${UPDATE}"; then
	    UPDATE_CMD="-update ${UPDATE} "
	    UPDATE_STR="_update$(echo ${UPDATE} | tr [a-z] [A-Z])"
	fi
	if test -n "${PMEFFT}"; then
	    PMEFFT_CMD="-pmefft ${PMEFFT} "
	    PMEFFT_STR="_pmefft$(echo ${PMEFFT} | tr [a-z] [A-Z])"
	fi
	
	GPU_OFFLOAD_CMD=${NB_CMD}${PME_CMD}${BONDED_CMD}${UPDATE_CMD}${NPME_CMD}
	GPU_OFFLOAD_STR=${NB_STR}${PME_STR}${BONDED_STR}${UPDATE_STR}
    fi
    
    
    if test -n "$NSTEPS"; then
	NSTEPS_CMD="-nsteps $NSTEPS "
	NSTEPS_STR="_nsteps$(printf "%06d" $NSTEPS)"
    fi
    if test -n "$RESETSTEP"; then
	RESETSTEP_CMD="-resetstep $RESETSTEP "
	RESETSTEP_STR="_resetstep$(printf "%06d" $RESETSTEP)"
    fi
    if test -n "$RESETHWAY"; then
	RESETHWAY_CMD="-resethway "
	RESETHWAY_STR="_resethway"
    fi
    if test -n "$NTOMP_PME"; then
	NTOMP_PME_CMD="-ntomp_pme $NTOMP_PME "
	NTOMP_PME_STR="_ntomppme$(printf "%03d" $NTOMP_PME)"
    fi
    if test -n "$DLB"; then
	DLB_CMD="-dlb $DLB "
	DLB_STR="_dlb$(echo $DLB | tr [a-z] [A-Z])"
    fi
    if test -n "$TUNEPME"; then
	TUNEPME_CMD="-tunepme $TUNEPME "
	TUNEPME_STR="_tunepme$(echo $TUNEPME | tr [a-z] [A-Z])"
    fi
    
    ALWAYS="-noconfout -v"
    PARALLEL_EXECUTION=${SMT_STR}${RANKSPERNODE_STR}${THREADSPERRANK_STR}${NODES_STR}
    MDRUN_CMD=${THREADSPERRANK_CMD}${GPU_OFFLOAD_CMD}${NTOMP_PME_CMD}${NSTEPS_CMD}${RESETSTEP_CMD}${RESETHWAY_CMD}${DLB_CMD}${TUNEPME_CMD}${ALWAYS}
    MDRUN_STR=${GPU_OFFLOAD_STR}${NTOMP_PME_STR}${NSTEPS_STR}${RESETSTEP_STR}${RESETHWAY_STR}${DLB_STR}${TUNEPME_STR}
    BENCHMARK_NAME=$(basename ${BENCHMARK} .tpr)
    RUN_DESCRIPTOR=${BENCHMARK_NAME}${PARALLEL_EXECUTION}${MDRUN_STR}${EXTRA_INFO}
}










#
# parse descriptor in directory or file name
#
function descriptor_to_options()
{
    local descriptor=$1
    descriptor_remainder=${descriptor#"$BENCHMARK_NAME"}
    local smt_position=$(echo $descriptor_remainder | grep -ob "smt" | cut -d ":" -f 1)
    SMT=$(echo ${descriptor_remainder:$((smt_position-1)):1} | cut -d '_' -f 1)
    local rankspernode_position=$(echo $descriptor_remainder | grep -ob "mpi" | cut -d ":" -f 1)
    RANKSPERNODE=$(echo ${descriptor_remainder:$((rankspernode_position-3)):3} | cut -d '_' -f 1)
    RANKSPERNODE=$((10#$RANKSPERNODE)) # strip leading zeros
    local threadsperrank_position=$(echo $descriptor_remainder | grep -ob "omp" | cut -d ":" -f 1)
    THREADSPERRANK=$(echo ${descriptor_remainder:$((threadsperrank_position-3)):3} | cut -d '_' -f 1)
    THREADSPERRANK=$((10#$THREADSPERRANK)) # strip leading zeros
    local nodes_position=$(echo $descriptor_remainder | grep -ob "nodes" | cut -d ":" -f 1)
    if test -n "$nodes_position"; then
	NODES=$(echo ${descriptor_remainder:$((nodes_position-2)):2} | cut -d '_' -f 1)
	NODES=$((10#$NODES))
    fi
    
    if [ "$GPU" == true ]; then
	local nb_position=$(echo $descriptor_remainder | grep -ob "nb" | cut -d ":" -f 1)
	local nb=$(echo ${descriptor_remainder:$nb_position} | cut -d '_' -f 1)
	NB=$(echo ${nb:2} | tr [A-Z] [a-z]) # CPU or GPU
	local pme_position=$(echo $descriptor_remainder | grep -ob "_pme" | cut -d ":" -f 1)
	local pme=$(echo ${descriptor_remainder:$((pme_position+1))} | cut -d '_' -f 1)
	PME=$(echo ${pme:3} | tr [A-Z] [a-z]) # CPU or GPU
	local bonded_position=$(echo $descriptor_remainder | grep -ob "bonded" | cut -d ":" -f 1)
	local bonded=$(echo ${descriptor_remainder:$bonded_position} | cut -d '_' -f 1)
	BONDED=$(echo ${bonded:6} | tr [A-Z] [a-z]) # CPU or GPU
	local update_position=$(echo $descriptor_remainder | grep -ob "update" | cut -d ":" -f 1)
	local update=$(echo ${descriptor_remainder:$update_position} | cut -d '_' -f 1)
	UPDATE=$(echo ${update:6} | tr [A-Z] [a-z]) # CPU or GPU
    fi
}










# Submit a single GROMACS job
function submit()
{
    if [ "$HELP" == true ] ||  [ "$#" == "1" ]; then
	usage_submit
    fi
    
    DAYTIME=$(date +%j%H%M)
    WORKDIR=${RUN_DESCRIPTOR}-${DAYTIME}
    
    echo -e "\nSubmitting job: "
    echo "Working directory  : $WORKDIR"
    echo "Benchmark          : $BENCHMARK_NAME"
    echo "Parallel execution : $PARALLEL_EXECUTION"
    echo "mdrun command      : $MDRUN_CMD"
    echo "Executable         : $EXE"
    echo "Walltime           : $WALLTIME"

    mkdir $WORKDIR
    if [ "$TUNE_PME" == true ]; then
	cp $BENCHMARK $WORKDIR
    fi
    
    cd $WORKDIR
    GMXBENCH_LOCATION="$(dirname $0)"
    source $GMXBENCH_LOCATION/submitjob_${MACHINE}.sh
    cd ..
}










# Set list of rank counts to iterate over appropriate to the machine
function set_rank_options()
{
    case "$MACHINE" in
	"hawk")
	    LOGICALCORES=$((128*$SMT))
	    RANKS=( 128 64 32 16 8 4 2 );;
	"pizdaint")
	    LOGICALCORES=$((12*$SMT))
	    RANKS=( 12 6 4 3 2 1 );;
    esac
}










# Submit multiple GROMACS jobs to scan a range of hybrid MPI x OpenMP options
function scan()
{
    if test -z "$SMT"; then
	set_smt_options
    else
	SMT_OPTIONS=($SMT)
    fi
	
    for SMT in "${SMT_OPTIONS[@]}"; do

	set_rank_options
	
	for N in "${RANKS[@]}"; do
	    RANKSPERNODE=$(($N*$SMT))
	    THREADSPERRANK=$(($LOGICALCORES/$RANKSPERNODE))
	    
	    if [ "$GPU" == true ]; then
		
		NB="cpu"
		PME="cpu"
		BONDED="cpu"
		UPDATE="cpu"
		init_params
		submit
		
		NB="gpu"
		PME="cpu"
		BONDED="cpu"
		UPDATE="cpu"
		init_params
		submit

		# For PME offloading, check if PP ranks contains too large prime factor
		# and adjust to user fewer ranks per node if that is the case
		# TODO: keep checking (don't step at reducing by 1)
		#local PPRANKSPERNODE=$(($RANKSPERNODE-1))
		#local largestdivisor=$(factor $PPRANKSPERNODE | rev | cut -d ' ' -f1)
		#if [ "$((largestdivisor**3))" -gt "$((PPRANKSPERNODE**2))" ]; then
		#    RANKSPERNODE=$RANKSPERNODE-1
		#fi
		
		NB="gpu"
		PME="gpu"
		BONDED="cpu"
		UPDATE="cpu"
		init_params
		submit
		
		NB="gpu"
		PME="gpu"
		BONDED="gpu"
		UPDATE="cpu"
		init_params
		submit
		
		# -update gpu only works with one rank
		if [ "$TOTALRANKS" == "1" ]; then
		    NB="gpu"
		    PME="gpu"
		    BONDED="gpu"
		    UPDATE="gpu"
		    init_params
		    submit

		    NB="gpu"
		    PME="gpu"
		    BONDED="cpu"
		    UPDATE="gpu"
		    init_params
		    submit
		fi
	    else # no GPU
		init_params
		submit
	    fi
	done
    done
}










function set_smt_options()
{
    case "$MACHINE" in
	"hawk")
	    SMT_OPTIONS=( 1 2 );;
	"pizdaint")
	    SMT_OPTIONS=( 1 2 );;
    esac
}










#
# Extract results from a single md.log file
#
function extract_logfile()
{
    local descriptor=${1}
    rm -f ${descriptor}/*.dat
    local logfile=${descriptor}/md.log

    local line=$(grep "Running on " $logfile)
    local nodes=$(echo $line | tr -s ' ' | cut -d ' ' -f 3)
    
    line=$(grep "Time:  " $logfile)
    local wtime=$(echo $line | tr -s ' ' | cut -d ' ' -f 3)
    
    line=$(grep "Performance:  " $logfile)
    local nsperday=$(echo $line | tr -s ' ' | cut -d ' ' -f 2)
    local hoursperns=$(echo $line | tr -s ' ' | cut -d ' ' -f 3)
    
    line=$(grep "Part of the total run time spent waiting due to load imbalance:" $logfile)
    local dd_load_imbalance=$(echo $line | tr -s ' ' | cut -d ' ' -f 13 | cut -d '%' -f 1)
    #echo -e "$nodes \t $dd_load_imbalance" >>  ${descriptor}/ddli.dat
    
    line=$(grep "Part of the total run time spent waiting due to PP/PME imbalance:" $logfile)
    local pme_load_imbalance=$(echo $line | tr -s ' ' | cut -d ' ' -f 13 | cut -d '%' -f 1)
    #echo -e "$nodes \t $pme_load_imbalance" >> ${descriptor}/pmeli.dat
    
    local total_load_imbalance=0
    
    if test -n "$dd_load_imbalance"; then
	total_load_imbalance=$(echo "scale=2; $total_load_imbalance + $dd_load_imbalance" | bc -l)
    fi
    if test -n "$pme_load_imbalance"; then
	total_load_imbalance=$(echo "scale=2; $total_load_imbalance + $pme_load_imbalance" | bc -l)
    fi
    
    #local wtime_min=0
    local nsperday_max=0
    #local hoursperns_min=0
    
    if [ "$total_load_imbalance" != 0 ]; then
	#local wtime_imbalance=$(echo "scale=2; $wtime*($total_load_imbalance/100.0)" | bc -l)
	#wtime_min=$(echo "scale=2; $wtime - $wtime_imbalance" | bc -l)
	local nsperday_imbalance=$(echo "scale=2; $nsperday*($total_load_imbalance/100.0)" | bc -l)
	nsperday_max=$(echo "scale=2; $nsperday + $nsperday_imbalance" | bc -l)
	#local hoursperns_imbalance=$(echo "scale=2; $hoursperns*($total_load_imbalance/100.0)" | bc -l)
	#hoursperns_min=$(echo "scale=2; $hoursperns - $hoursperns_imbalance" | bc -l)
    else
	#wtime_min=$wtime
	nsperday_max=$nsperday
	#hoursperns_min=$hoursperns
    fi
    
    # wtime_min = hypothetical min walltime if no load imbalance for gnuplot as lower bound 'error bar'
    #echo -e "$nodes \t $wtime \t $wtime_min \t $wtime" >> ${descriptor}/wtime.dat
    
    # nsperday_max = hypothetical max ns/day if no load imbalance for gnuplot as upper bound 'error bar'
    echo -e "$nodes \t $nsperday \t $nsperday \t $nsperday_max" >> ${descriptor}/nsperday.dat
    
    # hoursperns = hypothetical min hours/ns if no load imbalance for gnuplot as lower bound 'error bar'
    #echo -e "$nodes \t $hoursperns \t $hoursperns_min \t $hoursperns" >>  ${descriptor}/hoursperns.dat
}










function average_over_runs()
{
    local run_descriptor=${1}
    local successful_identical_runs=$(grep --no-messages "Finished" ${run_descriptor}*/md.log | wc -l)

    if [ "${successful_identical_runs}" -gt "0" ]; then
	local extracted_datafiles=$(ls ${run_descriptor}*/nsperday.dat | wc -l)
	
	if [ "${extracted_datafiles}" != "$(($successful_identical_runs))" ]; then
 	    echo "incomplete extraction detected for ${run_descriptor}"
	fi
	
	local nsperday=0
	local nsperday_max=0
	local nodes=0
	
	for identical_run in ${run_descriptor}*
	do
	    nodes=$(cut -s -f 1 ${identical_run}/nsperday.dat)
	    nsperday=$(echo "${nsperday} + $(cut -s -f 2 ${identical_run}/nsperday.dat)" | bc -l)
	    nsperday_max=$(echo "${nsperday_max} + $(cut -s -f 4 ${identical_run}/nsperday.dat)" | bc -l)
	done
	
	nsperday=$(echo "${nsperday}/${successful_identical_runs}" | bc -l)
	nsperday_max=$(echo "${nsperday_max}/${successful_identical_runs}" | bc -l)
	descriptor_to_options ${run_descriptor}
	init_params
	local target_datafile=${BENCHMARK_NAME}${SMT_STR}${RANKSPERNODE_STR}${THREADSPERRANK_STR}${MDRUN_STR}${EXTRA_INFO}  # i.e. just leaving number of nodes unspecified
	echo -e "$nodes \t $nsperday \t $nsperday \t $nsperday_max" >> ${target_datafile}-nsperday.dat
    fi
}










# Extract results from subdirectories of working directory
# for benchmark specified with --bench 
#
# For each combination of RANKSPERNODE and THREADSPERRANK,
# generate one file for each of:
#   walltime (seconds) - "wtime"
#   performance (ns/day) - "nsperday"
#   performance (hours/ns) - "hoursperns"
#   dd_load_imbalance (% of total run time spent waiting) - "ddli"
#   pme_load_imbalance (% of total run time spent waiting) - "pmeli"
#
# In each file:
#   first column = node count
#   second column = one of the result quantities listed above
#
# In the walltime and performance files:
#   third column = min or max hypothetical under zero load imbalance (to plot single-sided error bar in gnuplot)
#
function extract()
{
    shopt -s extglob
    
    rm -f ${BENCHMARK_NAME}${SMT_STR}*${MDRUN_STR}${EXTRA_INFO}*.dat
    
    # gather results for all node counts into single .dat file 
    for run in ${BENCHMARK_NAME}${SMT_STR}*"nodes"*${MDRUN_STR}${EXTRA_INFO}* 
    do
	run_descriptor=${run%%"-"+([0-9])}  # strip unique DAYTIME identifier
	
	if [ "${run_descriptor}" == "${already_extracted}" ]; then
	    continue
	else
	    for identical_run in ${run_descriptor}-* 
	    do
		echo "Extracting ${identical_run}"
		if grep -q "Finished" ${identical_run}/md.log; then
		    descriptor_to_options ${identical_run}
		    extract_logfile ${identical_run}
		else
		    echo "SKIPPING: simulation ${identical_run} did not finish"
		    continue
		fi    
	    done
	    
	    average_over_runs ${run_descriptor}
	    already_extracted=${run_descriptor}
	fi
    done
}










function gnuplot_init()
{
    GNUPLOT_LINESTYLE="yerrorlines linewidth 2"
    GNUPLOT_BASENAME=${RUN_DESCRIPTOR//${GPU_OFFLOAD_STR}}
        
    local GNUPLOT_XLABEL="set xlabel 'nodes'; "
    local GNUPLOT_TERMINAL="set terminal svg size 640,480 name '${GNUPLOT_BASENAME}'; "
    if [ "$GPU" == true ]; then
	local GNUPLOT_KEY="set key left top Left; "
    else
	local GNUPLOT_KEY="set key left top maxrows 4; "
    fi
    local GNUPLOT_ERRORBARS="set errorbars 2.0; "
    local GNUPLOT_OFFSET="set auto fix; set offsets graph 0.05, 0.05, 0, 0; "
    local GNUPLOT_XTICS="set xtics 1; "
    local GNUPLOT_GRID="set grid; "
    local GNUPLOT_SET=${GNUPLOT_XLABEL}${GNUPLOT_TERMINAL}${GNUPLOT_KEY}${GNUPLOT_ERRORBARS}${GNUPLOT_OFFSET}${GNUPLOT_XTICS}${GNUPLOT_GRID}
        
    #GNUPLOT_FILE_WTIME=${GNUPLOT_BASENAME}-wtime.gnuplot
    GNUPLOT_FILE_NSPERDAY=${GNUPLOT_BASENAME}-nsperday.gnuplot
    #GNUPLOT_FILE_HOURSPERNS=${GNUPLOT_BASENAME}-hoursperns.gnuplot
    #GNUPLOT_FILE_DDLI=${GNUPLOT_BASENAME}-ddli.gnuplot
    #GNUPLOT_FILE_PMELI=${GNUPLOT_BASENAME}-pmeli.gnuplot
    
    if [ ! -f "${GNUPLOT_FILE_NSPERDAY}" ]; then
	#echo -e $GNUPLOT_SET"\nset ylabel 'Walltime (seconds)'; set output \"${GNUPLOT_BASENAME}-wtime.svg\"\nplot \\" > $GNUPLOT_FILE_WTIME
	echo -e $GNUPLOT_SET"\nset yrange [0:$nsperday_max]; set ylabel 'Performance (ns/day)'; set output \"${GNUPLOT_BASENAME}-nsperday.svg\"\nplot \\" > $GNUPLOT_FILE_NSPERDAY
	#echo -e $GNUPLOT_SET"\nset ylabel 'Performance (hours/ns)'; set output \"${GNUPLOT_BASENAME}-hoursperns.svg\"\nplot \\"  > $GNUPLOT_FILE_HOURSPERNS
	#echo -e $GNUPLOT_SET"\nset ylabel 'DD load imbalance (% runtime spent waiting)'; set output \"${GNUPLOT_BASENAME}-ddli.svg\"\nplot \\"  > $GNUPLOT_FILE_DDLI
	#echo -e $GNUPLOT_SET"\nset ylabel 'PME load imbalance (% runtime spent waiting); set output \"${GNUPLOT_BASENAME}-pmeli.svg\"\nplot \\" > $GNUPLOT_FILE_PMELI
    fi
}










#
# Run extract first 
#
function plot()
{
    # Find largest nsperday to set same y-axis scale on each plot
    #nsperday_max=$(cut -s -f 4 ${BENCHMARK_NAME}${SMT_STR}${RANKSPERNODE_STR}${THREADSPERRANK_STR}*${MDRUN_STR}${EXTRA_INFO}-nsperday.dat | sort -nr | head -n 1)
    nsperday_max=$(cut -s -f 4 ${BENCHMARK_NAME}*${MDRUN_STR//${GPU_OFFLOAD_STR}}${EXTRA_INFO}-nsperday.dat | sort -nr | head -n 1)
        
    echo -n "Plotting "

    rm -f ${BENCHMARK_NAME}${SMT_STR}${RANKSPERNODE_STR}${THREADSPERRANK_STR}*${MDRUN_STR}${EXTRA_INFO}-nsperday.gnuplot
    
    for descriptor in ${BENCHMARK_NAME}${SMT_STR}${RANKSPERNODE_STR}${THREADSPERRANK_STR}*${MDRUN_STR}${EXTRA_INFO}-nsperday.dat
    do
	echo -n "."
	descriptor=$(basename $descriptor "-nsperday.dat")
	descriptor_to_options $descriptor
	init_params
	gnuplot_init
	
	local offload_legend_title=""
	local legend_title=""
	if [ "$GPU" == true ]; then
	    offload_legend_title="CPU only"
	    if [ "${NB}" == "gpu" ]; then offload_legend_title="nonbonded"; fi
	    if [ "${PME}" == "gpu" ]; then offload_legend_title=${offload_legend_title}", PME"; fi
    	    if [ "${BONDED}" == "gpu" ]; then offload_legend_title=${offload_legend_title}", bonded"; fi
	    if [ "${UPDATE}" == "gpu" ]; then offload_legend_title=${offload_legend_title}", update"; fi
	    legend_title=${offload_legend_title}
	else
	    legend_title="${RANKSPERNODE} mpi x ${THREADSPERRANK} omp"
	fi

	#echo "\"${descriptor}-wtime.dat\" with ${GNUPLOT_LINESTYLE} title '${legend_title}',\\" >> ${GNUPLOT_FILE_WTIME}
	echo "\"${descriptor}-nsperday.dat\" with ${GNUPLOT_LINESTYLE} title '${legend_title}',\\" >> ${GNUPLOT_FILE_NSPERDAY}
	#echo "\"${descriptor}-hoursperns.dat\" with ${GNUPLOT_LINESTYLE} title '${legend_title}',\\" >> ${GNUPLOT_FILE_HOURSPERNS}
    	#echo "\"${descriptor}-ddli.dat\" with ${GNUPLOT_LINESTYLE} title '${legend_title}',\\" >> ${GNUPLOT_FILE_DDLI}
    	#echo "\"${descriptor}-pmeli.dat\" with ${GNUPLOT_LINESTYLE} title '${legend_title}',\\" >> ${GNUPLOT_FILE_PMELI}
    done
    
    truncate -s-3 ${BENCHMARK_NAME}${SMT_STR}*.gnuplot
    for file in ${BENCHMARK_NAME}${SMT_STR}*.gnuplot; do echo "" >> $file; done
    gnuplot ${BENCHMARK_NAME}${SMT_STR}*.gnuplot
    echo "done"
}










#==================
#
#      Main
#
#==================
FUNCTIONALITY=$1
parse_options "$@"
set_options
init_params
$FUNCTIONALITY























