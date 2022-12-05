local postgres = import 'postgres/main.libsonnet';

{
  _config:: {
    namespace: 'sharedsvc',
    postgres: {
      suffix: 'arr',
      hostname: 'thinkcentre1',
      replicaHostname: 'thinkcentre2',
      password: 'password',
      replication_password: 'repl',

    },
  },

  local config_mixin = {
    _config:: $._config,
  },

  postgres: postgres + config_mixin,
}
