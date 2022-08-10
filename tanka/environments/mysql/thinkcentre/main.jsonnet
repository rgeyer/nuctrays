local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local config = import 'config.libsonnet';
local secrets = import 'secrets.libsonnet';

local mysql = import 'mysql/hahostpath.libsonnet';

config + secrets + {
  _images+:: {
    mysql: 'mysql:5.7',
  },

  _config+:: {
    local this = self,
    namespace: 'sharedsvc',
    hahostpath+:: {
      backup_instance_name: 'sharedsvc',
      suffix: '',
      root_password: this.mysql.root_password,
      replication_password: this.mysql.replication_password,
      password: this.mysql.password,
      primaryHost: 'thinkcentre1',
      replicaHost: 'thinkcentre2',
    },
  },

  local config_mixin = {
    _images+:: $._images,
    _config+:: $._config,
  },

  mysql: mysql + config_mixin,
}
