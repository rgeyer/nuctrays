local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local config = import 'config.libsonnet';
local backups = import 'backups/main.libsonnet';

config {
  _images+:: {
    etcdbkup: 'bitnami/etcd:3',
  },

  _config+:: {
    namespace: 'default',
  },

  namespace: k.core.v1.namespace.new($._config.namespace),

  local config_mixin = {
    _images+:: $._images,
    _config+:: $._config,
  },

  backups: backups + config_mixin,
}
