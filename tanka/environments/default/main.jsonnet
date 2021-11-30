local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local registry = import 'registry/main.libsonnet';

local nfspvc = import 'k8sutils/nfspvc.libsonnet';

local container = k.core.v1.container,
      deployment = k.apps.v1.deployment;

{  
  registry_pvc: nfspvc.new(
    'default',
    '192.168.42.101',
    '/mnt/brick/nfs/registry',
    'registry',
  ),

  registry: registry.new('default', 'registry-pvc'),
}
