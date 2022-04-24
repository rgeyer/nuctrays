#!/usr/bin/env bash
source ./common.sh
mysql_path=$backup_path/mysql
log_file=$backup_path/audit.log

mkdir -p $mysql_path

# Clear out the old pokemon records from MAD
mysql -h$SQLHOST -u$SQLUSER "-p$SQLPASS" madpoc -e 'delete from pokemon where last_modified < DATE_SUB(NOW(), INTERVAL 24 HOUR);'

# For consideration when there is a replica set, and we're doing backps from the replica.
# https://dev.mysql.com/doc/mysql-backup-excerpt/5.7/en/replication-solutions-backups-mysqldump.html

mysql -h$SQLHOST -u$SQLUSER "-p$SQLPASS" -N -e 'show databases;' | while read dbname; do if [[ "$dbname" != "madstats" ]]; then mysqldump -h$SQLHOST -u$SQLUSER "-p$SQLPASS" --complete-insert --routines --triggers --single-transaction "$dbname" > $mysql_path/"$dbname".sql; fi; done;

# mysql -h$SQLHOST -u$SQLUSER "-p$SQLPASS" -N -e 'show databases;' | while read dbname; do echo "$dbname"; done;

ls -1trd $BACKUPROOT/* | head -n -7 | xargs -d '\n' rm -rf --
