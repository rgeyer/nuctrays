local k = import 'ksonnet-util/kausal.libsonnet';

local cortex = import 'cortex/main.libsonnet';
local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local secrets = import 'secrets.json';
local config = import 'config.libsonnet';

local namespace = 'cortex';

config + secrets {
  namespace: k.core.v1.namespace.new(namespace),

  cortex: cortex.new(namespace, 'cortex-pvc'),
  cortexpvc: nfspvc.new(
    namespace,
    $._config.cortex.pvc.nfsHost,
    $._config.cortex.pvc.nfsPath,
    'cortex'
  )
}
