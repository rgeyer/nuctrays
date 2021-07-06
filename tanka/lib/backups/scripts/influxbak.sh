#!/usr/bin/env bash
source ./common.sh

influx_path=$backup_path/influxdb
mkdir -p $influx_path

influxd backup -portable -host $INFLUXHOST $influx_path
