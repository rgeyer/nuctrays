local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local cortex = import 'cortex/main.libsonnet';
local minio = import 'minio/minio.libsonnet';
local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local secrets = import 'secrets.libsonnet';
local config = import 'config.libsonnet';

local namespace = 'cortex';

config + secrets {
  _s3_rules_host:: 'http://%(key)s:%(secret)s@minio:9000' % $._config.minio,

  namespace: k.core.v1.namespace.new(namespace),

  cortex: cortex.new(namespace, 'cortex-pvc', self._s3_rules_host, 'cortex'),
  cortexpvc: nfspvc.new(
    namespace,
    $._config.cortex.pvc.nfsHost,
    $._config.cortex.pvc.nfsPath,
    'cortex'
  ),

  minio: minio.new(namespace, $._config.minio.key, $._config.minio.secret, 'minio-pvc'),
  miniopvc: nfspvc.new(
    namespace,
    $._config.minio.pvc.nfsHost,
    $._config.minio.pvc.nfsPath,
    'minio'
  ),
}
