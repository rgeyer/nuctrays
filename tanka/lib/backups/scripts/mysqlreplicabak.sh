#!/usr/bin/env bash
source ./common.sh
mysql_repl_path=$backup_path/mysqlha/$SQLINSTANCENAME
log_file=$backup_path/audit.log

mkdir -p $mysql_repl_path

mysql -h$SQLHOST -u$SQLUSER "-p${SQLPASS}" -e 'STOP REPLICA SQL_THREAD;'

mysql -h$SQLHOST -u$SQLUSER "-p${SQLPASS}" -N -e 'show databases;' | while read dbname; do if [[ "$dbname" != "madstats" ]]; then mysqldump -h$SQLHOST -u$SQLUSER "-p$SQLPASS" --complete-insert --routines --triggers --single-transaction "$dbname" > $mysql_repl_path/"$dbname".sql; fi; done;

mysql -h$SQLHOST -u$SQLUSER "-p${SQLPASS}" -e 'START REPLICA SQL_THREAD;'