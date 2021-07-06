#! /usr/bin/env bash
ETCDCTL_API=3 etcdctl snapshot restore kube-etcd --endpoints=https://192.168.1.234:2379 --initial-advertise-peer-urls https://192.168.1.234:2380 --initial-cluster=ryan-b450m-ds3h=https://192.168.1.234:2380 --cert=file=/etc/kubernetes/pki/etcd/server.crt --name=ryan-b450m-ds3h
