local mysql = import 'mysql/mysql.libsonnet';
local secrets = import 'secrets.libsonnet';

secrets {
  _images+:: {
    mysql: 'mysql:5.7',
  },

  _config+:: {
    namespace: 'dbs',
  },

  local config_mixin = {
    _images+:: $._images,
    _config+:: $._config,
  },

  mysql: mysql + config_mixin,
}
