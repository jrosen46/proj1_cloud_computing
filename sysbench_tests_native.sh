#!/bin/bash

# login as root user before this script is run on native: sudo -i

[ -z "$1" ] && echo "No argument supplied: options are cpu, fileio, or both." && exit 1
[ -z "$2" ] && echo "No argument supplied: number of iterations." && exit 1

IOSTAT_DATA=data/native
if [ ! -d $IOSTAT_DATA ]
then
    mkdir -p $IOSTAT_DATA
fi

iostat -c -d -x -t -m 1 > "${IOSTAT_DATA}/iostat_data.txt" &
TARGET_PID=$!

if [ $1 == 'cpu' ] || [ $1 == 'both' ]; then
    #### CPU TESTS ####
    CPU_TESTS=data/native/cpu
    if [ ! -d $CPU_TESTS ]
    then
        mkdir -p $CPU_TESTS
    fi

    iter=1
    while [ $iter -le 3 ]; do
        if [ ! -d "${CPU_TESTS}/iter${iter}" ]
        then
            mkdir "${CPU_TESTS}/iter${iter}"
        fi
        for max_prime in 2000 20000; do
            for threads in 1 2 4 8; do
                OUT_FILE="${CPU_TESTS}/iter${iter}/maxprime-${max_prime}_threads-${threads}"
                date > $OUT_FILE
                sysbench --num-threads=$threads --test=cpu --cpu-max-prime=$max_prime \
                    run >> $OUT_FILE 2>&1 
                date >> $OUT_FILE
            done
        done
        ((iter++))
    done
fi


if [ $1 == 'fileio' ] || [ $1 == 'both' ]; then
    #### FILEIO TESTS ####
    FILEIO_TESTS=data/native/fileio
    if [ ! -d $FILEIO_TESTS ]
    then
        mkdir -p $FILEIO_TESTS
    fi

    sysbench --test=fileio --file-total-size=8G --file-num=128 prepare

    # for sequential tests, use a 2M block size ... this
    # will mean less trips to disk to service page request
    iter=1
    while [ $iter -le $2 ]; do
        if [ ! -d "${FILEIO_TESTS}/iter${iter}" ]
        then
            mkdir "${FILEIO_TESTS}/iter${iter}"
        fi
        for threads in 1 2 4 8; do
            for mode in seqrd seqwr seqrewr; do
                if [ $mode == 'seqwr' ]; then
                    # also do fsync for writes
                    OUT_FILE="${FILEIO_TESTS}/iter${iter}/mode-${mode}_bs-2M_fsync-100_threads-${threads}"
                    date > $OUT_FILE
                    sysbench --num-threads=$threads --max-time=120 --max-requests=0 --test=fileio \
                        --file-total-size=8G --file-test-mode=$mode --file-fsync-freq=100 \
                        --file-block-size=2M --file-num=128 run >> $OUT_FILE 2>&1
                    date >> $OUT_FILE
                    # since sequential rd/wr and 2x size of RAM, don't need to clear cache
                fi
                OUT_FILE="${FILEIO_TESTS}/iter${iter}/mode-${mode}_bs-2M_fsync-0_threads-${threads}"
                date > $OUT_FILE
                sysbench --num-threads=$threads --max-time=120 --max-requests=0 --test=fileio \
                    --file-total-size=8G --file-test-mode=$mode --file-fsync-freq=0 \
                    --file-block-size=2M --file-num=128 run >> $OUT_FILE 2>&1
                date >> $OUT_FILE
                # since sequential rd/wr and 2x size of RAM, don't need to clear cache
            done
        done
        ((iter++))
    done

    # for random tests, use a 4K block size ... if not, it is going to
    # take a really long time ...
    iter=1
    while [ $iter -le $2 ]; do
        if [ ! -d "${FILEIO_TESTS}/iter${iter}" ]
        then
            mkdir "${FILEIO_TESTS}/iter${iter}"
        fi
        for threads in 1 2 4 8; do
            for mode in rndrd rndwr rndrw; do
                if [ $mode == 'rndwr' ]; then
                    # also do fsync for writes
                    OUT_FILE="${FILEIO_TESTS}/iter${iter}/mode-${mode}_bs-4K_fsync-100_threads-${threads}"
                    date > $OUT_FILE
                    sysbench --num-threads=$threads --max-time=120 --max-requests=0 --test=fileio \
                        --file-total-size=8G --file-test-mode=$mode --file-fsync-freq=100 \
                        --file-block-size=4K --file-num=128 run >> $OUT_FILE 2>&1
                    date >> $OUT_FILE
                    # clear cache
                    echo 3 | sudo tee /proc/sys/vm/drop_caches
                    echo 'CLEARED CACHE!'
                    sleep 2
                fi
                OUT_FILE="${FILEIO_TESTS}/iter${iter}/mode-${mode}_bs-4K_fsync-0_threads-${threads}"
                date > $OUT_FILE
                sysbench --num-threads=$threads --max-time=120 --max-requests=0 --test=fileio \
                    --file-total-size=8G --file-test-mode=$mode --file-fsync-freq=0 \
                    --file-block-size=4K --file-num=128 run >> $OUT_FILE 2>&1
                date >> $OUT_FILE
                # clear cache
                echo 3 | sudo tee /proc/sys/vm/drop_caches
                echo 'CLEARED CACHE!'
                sleep 2
            done
        done
        ((iter++))
    done

    sysbench --test=fileio --file-total-size=8G --file-num=128 cleanup
fi

kill $TARGET_PID

chmod -R 755 $IOSTAT_DATA
chmod -R 755 $CPU_TESTS
chmod -R 755 $FILEIO_TESTS
