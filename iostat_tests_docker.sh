#!/bin/bash

iostat -c -d -x -t -m -o JSON 1 > data/docker/iostat_data.txt
