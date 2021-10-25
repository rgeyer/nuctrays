local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local loki = import 'loki/main.libsonnet';
local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local config = import 'config.libsonnet';

local namespace = 'loki';

config {

  namespace: k.core.v1.namespace.new(namespace),

  loki: loki.new(namespace, 'loki-pvc'),
  lokipvc: nfspvc.new(
    namespace,
    $._config.loki.pvc.nfsHost,
    $._config.loki.pvc.nfsPath,
    'loki'
  ),
}
