#!/usr/bin/env bash
source ./common.sh

etcd_path=$backup_path/etcd
mkdir -p $etcd_path

echo "Hostname is ${HOSTNAME}"
ETCDCTL_API=3 etcdctl --endpoints=https://${HOSTIP}:2379 --cacert=/etcdtls/ca.pem "--cert=/etcdtls/node-${HOSTNAME}.pem" "--key=/etcdtls/node-${HOSTNAME}-key.pem" snapshot save $etcd_path/kube-etcd
