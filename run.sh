#! /bin/bash

print_table_header(){
    benchmark_names=""
    table_line=""

    for benchmark in "${BENCHMARKS[@]}"
    do
        bench=$(echo $benchmark | grep -oP "(?<=bench_).*" | sed "s/_/ /g")
        benchmark_names+=" | $bench"
        table_line+=" | -:"
    done

    echo "source$benchmark_names" > $OUT
    echo ":-$table_line" >> $OUT
}


subprocess(){
    board=$1
    source=$2
    benchmark_name="${*:3}"
    set -m
    # Build once first so that timeout doesn't cancel slow builds.
    laze build -C $benchmark_name -b $board -s $source &> /dev/null
    timeout -v 60s laze build -C $benchmark_name -b $board -s $source run 2>&1 &
    echo "$!"
}

run_benchmark() {

    exec 3< <(subprocess "$@")
    read <&3 subprocess_pid;
    while true; 
    do
        read <&3 line;
        echo "$line"

        if ticks=$(echo $line | grep -Po "\d+(?= ticks)"); then
            echo -ne " | $ticks" >> $OUT
            kill -- -$subprocess_pid # Terminate the function
            break
        elif echo $line | grep "none of the selected packages contains these features"; then
            echo -ne " | -" >> $OUT
            break
        elif echo $line | grep "no matching target for task"; then
            echo -ne " | -" >> $OUT
            break
        elif echo $line | grep "is not an ancestor of"; then
            echo -ne " | -" >> $OUT
            break
        elif bench_err=$(echo $line | grep -Po "(?<=benchmark error: )\w+"); then
            echo -ne " | benchmark $bench_err" >> $OUT
            kill -- -$subprocess_pid # Terminate the function
            break
        elif echo $line | grep -Pio "panic:.*"; then
            echo -ne " | panic" >> $OUT
            kill -- -$subprocess_pid # Terminate the function
            break
        elif echo $line | grep -Pio "Error:.*"; then
            echo -ne " | error" >> $OUT
            break
        elif echo $line | grep -Pio "timeout:"; then
            echo -ne " | timeout" >> $OUT
            break
        fi
    done
}


single_core_benchmarks(){
    BENCHMARKS=("benchmarks/bench_thread_flags_preempt")

    print_table_header

    for feature in single-core dual-core
    do
        source="$feature -s ariel"
        echo -n $source >> $OUT

        for benchmark in "${BENCHMARKS[@]}"
        do
            run_benchmark "$BOARD" "$source" "$benchmark"
        done
        echo "" >> $OUT
    done
}

dual_core_benchmarks(){
    BENCHMARKS=("benchmarks/bench_thread_flags -s t4")

    for i in $(seq 10 10 80)
    do
        BENCHMARKS+=("benchmarks/bench_matrix_mult -s n$i")
    done

    print_table_header
    for feature in "single-core -s ariel" "dual-core -s ariel" "dual-core -s ariel-reallocation"
    do
        source="$feature"
        echo -n $source >> $OUT
        for benchmark in "${BENCHMARKS[@]}"
        do
            run_benchmark "$BOARD" "$source" "$benchmark"
        done
        echo "" >> $OUT
    done

}

if [ -z "$BOARD" ]
then
    echo "Please set the BOARD env."
    exit
fi

mkdir data
OUT=data/$BOARD.md

if [ "$BOARD" = "rpi-pico" ] || [ "$BOARD" = "rpi-pico2" ] || [ "$BOARD" = "espressif-esp32-s3-devkitc-1" ]
then
    dual_core_benchmarks
else
    single_core_benchmarks
fi