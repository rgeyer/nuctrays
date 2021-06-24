local namefetcher = import 'madnamefetcher/madnamefetcher.libsonnet';
local secrets = import 'secrets.json';

secrets {
  _images+:: {
    namefetcher: 'registry.ryangeyer.com/namefetcher:latest',
  },

  _config+:: {
    namespace: 'mad',
    namefetcher+:: {
      dbhost: 'mysql.dbs.svc.cluster.local',
      dbname: 'madpoc',
    },

    madmysql+:: {
      secretname: 'mysql-secret',
      secretuserkey: 'username',
      secretpasskey: 'password',
    },
  },

  local config_mixin = {
    _images+:: $._images,
    _config+:: $._config,
  },

  namefetcher: namefetcher + config_mixin,
}
