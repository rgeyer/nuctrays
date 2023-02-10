# MySQL Replication is Broken.

1. Kill the replica `kubectl scale statefulset --replicas 0`
2. Follow the directions to lock db, mysqldump primary data, and fetch binlog coords from [here](https://www.digitalocean.com/community/tutorials/how-to-set-up-replication-in-mysql)
   1. Use `mysqldump --all-databases --source-data -h<host or ip> -u root -p > primary-data.sql` to dump data
3. Create a file in `/opt/kubehostpaths/<replicadir>` containing `ALTER USER 'root'@'localhost' IDENTIFIED BY 'MyNewPass';`
4. Add ` --init-file=/bitnami/mysql/rootpwd.sql` to the CLI options of the replica in `tanka/libs/mysql/hahostpath.libsonnet`
5. Copy `primary-data.sql` to `/opt/kubehostpaths/<replicadir>`
6. TK apply, scale the statefulest back up, and import the `primary-data.sql` to the replica
7. Scale down replica statefulset
8. Revert changes to `tanka/libs/mysql/hahostpath.libsonnet` and tk apply
9. Restart replication per step 6 [here](https://www.digitalocean.com/community/tutorials/how-to-set-up-replication-in-mysql)

https://www.digitalocean.com/community/tutorials/how-to-set-up-replication-in-mysql