#!/bin/bash
#source ../common.sh

# emu_bin=/home/xugang/hdd/xg/Kunminghu/XiangShan/build/emu
emu_bin=/home/radl/hdd/xg/Nanhu-V3/build/emu
workload_dir=/home/xugang/hdd/xg/workload/emu-bbl/coremarkpro-bbl-rv64gcv
work_dir=/home/xugang/hdd/xg/test-log/kunminghu
core_name=coremark-pro-llvm-rv64gcv
run_dir="$work_dir/$core_name"
# Customize parameters
run_suffix="-default"

dry_run=0

enable_diff=0
spike_debug=0
num_jobs=9

# JSON file
# ckpt_json=$ckpt_json_dir/simpoint_summary.json  # full coverage
# ckpt_json=$ckpt_json_dir/simpoint_coverage0.2_test.json

# CKPT patterns
ckpt_pattern=""
ckpt_anti_pattern=""

#######################################################
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# emu_dir=$script_dir/emu_dir

# if [ $emu_cores -eq 1 ]; then
#     emu_bin="$emu_dir/emu-single-$emu_config"
#     ref_bin="$emu_dir/riscv64-spike-single-diff-so"
#     core_name=sc
# elif [ $emu_cores -eq 2 ]; then
#     emu_bin="$emu_dir/emu-dual-$emu_config"
#     ref_bin="$emu_dir/riscv64-spike-dual-diff-so"
#     core_name=dc
# else
#     echo "Invalid number of cores: $emu_cores"
#     exit 1
# fi



if [ $spike_debug -eq 1 ]; then
    ref_bin=$HOME/riscv-isa-sim/difftest/build/riscv64-spike-so
fi

# parameters
cur_date=$(TZ='Asia/Shanghai' LC_ALL=C date +%b%d | tr '[:upper:]' '[:lower:]')
run_name="$cur_date-$core_name"

# # generate ckpt list
# run_ckpt_file=$(mktemp)
# parse_ckpt_json $ckpt_json $run_ckpt_file $ckpt_dir/
# run_ckpts=$(cat $run_ckpt_file)

run_ckpts=$(find $workload_dir -name '*.bin')

if [ ! x"$ckpt_pattern" = x"" ]; then run_ckpts=$(echo "$run_ckpts" | grep -E $ckpt_pattern); fi
if [ ! x"$ckpt_anti_pattern" = x"" ]; then run_ckpts=$(echo "$run_ckpts" | grep -vE $ckpt_anti_pattern); fi

run_ckpts=$(echo "$run_ckpts" | sort)
ckpt_short=$(echo "$run_ckpts" | sed "s:$workload_dir/::g" | cut -d'.' -f1)

# run
job_dir="$run_dir/$run_name"

# check if job dir exists
if [ -d $job_dir ]; then
    echo "Job dir $job_dir already exists, remove? [y/N] "
    # prompt
    read -p "" -n 1 -r
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf $job_dir
    else
        echo "Abort"
        exit 1
    fi
fi

mkdir -p $job_dir

echo "==== Emu run started at $(date) ===="
echo "Emu bin: $emu_bin"
if [ $enable_diff -eq 1 ]; then
    echo "Ref bin: $ref_bin"
fi
echo
echo "Run name: $run_name"
if [ $dry_run -eq 1 ]; then
    echo "Run ckpts: $run_ckpts"
    echo "Run ckpt short: $ckpt_short"
fi
echo "Job dir: $job_dir"
echo "Total jobs: $(echo "$run_ckpts" | wc -l)"
echo "===================================="

# ask user to start
echo "Start? [y/N]"
read -p "" -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Abort"
    exit 1
fi

echo "$run_ckpts" > $job_dir/ckpts.txt
echo "$ckpt_short" > $job_dir/shortnames.txt

if [ $enable_diff -eq 1 ]; then
    diff_args="--diff $ref_bin"
else
    diff_args="--no-diff"
fi

if [ $dry_run -eq 1 ]; then
    extra_args="--dry-run"
fi

parallel -j $num_jobs --link --joblog $job_dir/parallel.log \
    --files --results $job_dir/{2} --progress $extra_args \
    $emu_bin $diff_args -i {1} \
    :::: $job_dir/ckpts.txt $job_dir/shortnames.txt
