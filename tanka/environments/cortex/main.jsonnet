local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local cortex = import 'cortex/main.libsonnet';
local minio = import 'minio/minio.libsonnet';
local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local secrets = import 'secrets.libsonnet';
local config = import 'config.libsonnet';

local traefikingress = import 'traefik/ingress.libsonnet';

local namespace = 'cortex';

config + secrets {

  namespace: k.core.v1.namespace.new(namespace),

  cortex_config:: (import './cortex-config.libsonnet') + {
    s3_rules_host:: 'http://%(key)s:%(secret)s@minio:9000' % $._config.minio,
    s3_rules_bucket:: 'cortex',
    s3_blocks_endpoint:: 'minio:9000',
    s3_blocks_access_key_id:: $._config.minio.key,
    s3_blocks_secret_access_key:: $._config.minio.secret,
    s3_blocks_bucket:: 'cortexblocks',
  },

  cortex: cortex.new(namespace, 'cortex-pvc', $.cortex_config),
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
  ingress: traefikingress.newIngressRoute(
    'minio', 
    namespace, 
    'minio.ryangeyer.com', 
    'minio', 
    9001, 
    false, 
    true),
}
