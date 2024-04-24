local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local configMap = k.core.v1.configMap,
      container = k.core.v1.container,
      deployment = k.apps.v1.deployment,
      secret = k.core.v1.secret,
      service = k.core.v1.service;

local config = import 'config.libsonnet';
local secrets = import 'secrets.libsonnet';

local traefikingress = import 'traefik/ingress.libsonnet';

config + secrets {
  _images+:: {
    koji: 'ghcr.io/turtiesocks/koji:main',
    dragonite: 'ghcr.io/unownhash/dragonite-public:latest',
    dragoniteadmin: 'ghcr.io/unownhash/dragonite-public-admin:latest',
    golbat: 'ghcr.io/unownhash/golbat:main',
    rotom: 'ghcr.io/unownhash/rotom:main',
    xilriws: 'ghcr.io/unownhash/xilriws-public:main',
    reactmap: 'ghcr.io/watwowmap/reactmap:main',
  },

  _config+:: {
    namespace: 'unownhash',

    dragonite_config: |||
      [general]
      login_delay = 0
      # seconds to sleep in-between PTC authing on one proxy

      # Whether raw worker stats are written
      stats = false

      # Host and Port used for the Dragonite API
      api_host = "0.0.0.0"
      api_port = 7272

      # Uses login proxy as you wish, e.g. Swirlix or Xilriws
      remote_auth_url = "http://xilriws.unownhash.svc.cluster.local:5090/api/v1/login-code"
      # remote_auth_url = "http://mail.ryangeyer.com:5090/api/v1/login-code"

      [koji]
      url = "http://koji.unownhash.svc.cluster.local:8080"
      bearer_token = "%(koji_secret)s"

      [prometheus]
      enabled = true

      [tuning]
      #recycle_gmo_limit = 4900
      #recycle_encounter_limit = 9900
      #recycle_on_jail=false
      #minimum_account_reuse_hours = 169
      #location_delay = 0
      #fort_location_delay = 0
      #scout_age_limit = 30
      #token_refresh_only=true

      #[accounts]
      #required_level = 30 # used for everything except leveling (quest can force level 31 at specific events)
      #leveling_level = 31 # used to stop leveling at certain level

      [rotom]
      endpoint = "ws://rotom.unownhash.svc.cluster.local:7071"
      secret = "%(rotom_controller_secret)s"

      [logging]
      save = true
      #debug = false
      #max_size = 500 # MB
      #max_age = 30 # days

      [processors]
      # Golbat Endpoint is singular - and will configure an endpoint for raw sending and API
      golbat_endpoint = "http://golbat.unownhash.svc.cluster.local:9001"
      golbat_raw_bearer = "%(golbat_rawbearer)s"
      golbat_api_secret = "%(golbat_apisecret)s"
      # if this is present then dragonite will not send raws to the httpendpoint - not used for API, be careful if you use grpc you still need 'golbat_endpoint' for API calls to Golbat
      golbat_grpc_endpoint = "golbat.unownhash.svc.cluster.local:50001"

      [db.dragonite]
      host = "%(dbhost)s"
      port = 3306
      user = "%(dragonite_dbusername)s"
      password = "%(dragonite_dbpassword)s"
      name = "dragonite"
      pool_size = 1
    ||| % {
      koji_secret: $._config.koji.secret,
      dbhost: $._config.hostmysql.hostname,
      dragonite_dbusername: $._config.dragonite.dbusername,
      dragonite_dbpassword: $._config.dragonite.dbpassword,
      rotom_controller_secret: $._config.rotom.controllersecret,
      golbat_apisecret: $._config.golbat.apisecret,
      golbat_rawbearer: $._config.golbat.rawbearer,
    },

    golbat_config: |||
      port = 9001             # Listening port for golbat
      grpc_port = 50001       # Listening port for grpc
      raw_bearer = "%(golbat_rawbearer)s"         # Raw bearer (password) required
      api_secret = "%(golbat_apisecret)s"   # Golbat secret required on api calls (blank for none)

      pokemon_memory_only = false  # Use in-memory storage for pokemon only

      [koji]
      url = "http://koji.unownhash.svc.cluster.local/api/v1/geofence/feature-collection/{golbat_project}"
      bearer_token = "%(koji_secret)s"

      [cleanup]
      pokemon = true          # Keep pokemon table is kept nice and short
      incidents = true        # Remove incidents after expiry
      quests = true           # Remove quests after expiry
      stats = true            # Enable/Disable stats history
      stats_days = 7          # Remove entries from "pokemon_stats", "pokemon_shiny_stats", "pokemon_iv_stats", "pokemon_hundo_stats", "pokemon_nundo_stats", "invasion_stats", "quest_stats", "raid_stats" after x days
      device_hours = 24       # Remove devices from in memory after not seen for x hours

      [logging]
      debug = false
      save_logs = true
      max_size = 50           # Size in MB
      max_backups = 10        # Amount of files to keep
      max_age = 30            # Day(s) to keep files
      compress = true         # Compress to gz archive

      [database]
      user = "%(golbat_dbusername)s"
      password = "%(golbat_dbpassword)s"
      address = "%(dbhost)s:3306"
      db = "golbat"

      [pvp]
      enabled = true
      include_hundos_under_cap = false

      # you can enable prometheus by uncommenting this section
      [prometheus]
      enabled = true

      # You can specify more than one webhook destination by including the [[webhooks]] section
      # multiple times.  The hook types can optionally be filtered by using the types array

      [[webhooks]]
      url = "http://poracle.mad.svc.cluster.local:3030"
      # types if specified can be...
      # types = ["pokemon", "pokemon_iv", "pokemon_no_iv", "gym", "invasion", "quest", "pokestop", "raid", "weather", "fort_update"]
      # "pokemon" includes both with ivs and without. "pokemon_iv" will only be encountered pokemon. "pokemon_no_iv" may be nearby pokemon that have not been encountered (yet).

      #[[webhooks]]
      #url = "http://localhost:4202"
      #types = ["raid"]
      #headers = ["X-Poracle-Secret:abc", "Other-Header:def"]

      #[[webhooks]]
      #url = "http://localhost:4202"
      #types = ["raid"]
      #areas = ["London/*", "*/Harrow", "Harrow"]

      [tuning]
      max_pokemon_distance = 100  # Maximum distance in kilometers for searching pokemon
      max_pokemon_results = 3000  # Maximum number of pokemon to return
      extended_timeout = false  
    ||| % {
      koji_secret: $._config.koji.secret,
      dbhost: $._config.hostmysql.hostname,
      golbat_dbusername: $._config.golbat.dbusername,
      golbat_dbpassword: $._config.golbat.dbpassword,
      golbat_apisecret: $._config.golbat.apisecret,
      golbat_rawbearer: $._config.golbat.rawbearer,
    },

    rotom_config: |||
      {
        "deviceListener": {
          "port": 7070,
          "secret": "%(rotom_device_secret)s"
        },
        "controllerListener":{
          "port": 7071,
          "secret": "%(rotom_controller_secret)s"
        },
        "client": {
          "port": 7072,
          "host": "0.0.0.0"
        },
        "monitor":{
          "enabled": true,
          // when enabled reboot instead restart
          "reboot": false,
          // min required memory
          "minMemory": 30000,
          // restart/reboot over minMemory * maxMemStartMultiple value
          "maxMemStartMultiple": 2,
          // if origin name starts with key, use value to overwrite maxMemStartMultiple
          "maxMemStartMultipleOverwrite": { "atv": 15, "iphone": 7 },
          "deviceCooldown": 25
        }
      }
    ||| % {
      rotom_device_secret: $._config.rotom.devicesecret,
      rotom_controller_secret: $._config.rotom.controllersecret,
    },
  },

  koji_secret:
    secret.new('koji-secret', {}) +
    secret.withStringData({
      golbatdburl: 'mysql://%s:%s@%s:3306/golbat' % [$._config.golbat.dbusername, $._config.golbat.dbpassword, $._config.hostmysql.hostname],
      dragonitedburl: 'mysql://%s:%s@%s:3306/dragonite' % [$._config.dragonite.dbusername, $._config.dragonite.dbpassword, $._config.hostmysql.hostname],
      kojidburl: 'mysql://%s:%s@%s:3306/koji' % [$._config.koji.dbusername, $._config.koji.dbpassword, $._config.hostmysql.hostname],
      kojisecret: $._config.koji.secret,
    }) +
    secret.metadata.withNamespace($._config.namespace),

  koji_container::
    container.new('koji', $._images.koji) +
    container.withEnv([
      k.core.v1.envVar.fromSecretRef('SCANNER_DB_URL', 'koji-secret', 'golbatdburl'),
      k.core.v1.envVar.fromSecretRef('CONTROLLER_DB_URL', 'koji-secret', 'dragonitedburl'),
      k.core.v1.envVar.fromSecretRef('KOJI_DB_URL', 'koji-secret', 'kojidburl'),
      k.core.v1.envVar.fromSecretRef('KOJI_SECRET', 'koji-secret', 'kojisecret'),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('koji', 8080),
    ]),

  koji_deployment:
    deployment.new('koji', 1, $.koji_container) +
    deployment.mixin.metadata.withNamespace($._config.namespace) +
    deployment.spec.strategy.withType('Recreate'),

  koji_service:
    k.util.serviceFor($.koji_deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),

  koji_ingress:
    traefikingress.newIngressRoute('koji', $._config.namespace, 'koji.lsmpogo.com', 'koji', 8080, true),

  dragonite_secret:
    secret.new('dragonite-secret', {}) +
    secret.withStringData({
      admin_username: $._config.dragonite.adminusername,
      admin_password: $._config.dragonite.adminpassword,
      api_secret: $._config.dragonite.apisecret,
    }) +
    secret.metadata.withNamespace($._config.namespace),

  dragonite_config:
    configMap.new('dragonite-config') +
    configMap.withData({
      'config.toml': $._config.dragonite_config,
    }),

  dragonite_container::
    container.new('dragonite', $._images.dragonite) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('config', '/dragonite/config.toml') + k.core.v1.volumeMount.withSubPath('config.toml'),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('dragonite', 7272),
    ]),

  dragonite_deployment:
    deployment.new('dragonite', 1, $.dragonite_container) +
    deployment.mixin.metadata.withNamespace($._config.namespace) +
    deployment.spec.strategy.withType('Recreate') +
    deployment.mixin.spec.template.spec.withVolumesMixin([
      k.core.v1.volume.fromConfigMap('config',
                                     'dragonite-config',
                                     [{ key: 'config.toml', path: 'config.toml' }]),
    ]),

  dragonite_service:
    k.util.serviceFor($.dragonite_deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),

  dragonite_admin_container::
    container.new('dragonite-admin', $._images.dragoniteadmin) +
    container.withEnv([
      k.core.v1.envVar.new('ADMIN_GENERAL_HOST', '0.0.0.0'),
      k.core.v1.envVar.new('ADMIN_GENERAL_PORT', '7273'),
      k.core.v1.envVar.new('ADMIN_DRAGONITE_API_ENDPOINT', 'http://dragonite.unownhash.svc.cluster.local:7272'),
      k.core.v1.envVar.new('ADMIN_GOLBAT_API_ENDPOINT', 'http://golbat.unownhash.svc.cluster.local:9001'),
      k.core.v1.envVar.fromSecretRef('ADMIN_GENERAL_USERNAME', 'dragonite-secret', 'admin_username'),
      k.core.v1.envVar.fromSecretRef('ADMIN_GENERAL_PASSWORD', 'dragonite-secret', 'admin_password'),
      k.core.v1.envVar.fromSecretRef('ADMIN_DRAGONITE_API_SECRET', 'dragonite-secret', 'api_secret'),
      k.core.v1.envVar.fromSecretRef('ADMIN_GOLBAT_API_SECRET', 'golbat-secret', 'api_secret'),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('dragonite-admin', 7273),
    ]),

  dragonite_admin_deployment:
    deployment.new('dragonite-admin', 1, $.dragonite_admin_container) +
    deployment.mixin.metadata.withNamespace($._config.namespace) +
    deployment.spec.strategy.withType('Recreate'),

  dragonite_admin_service:
    k.util.serviceFor($.dragonite_admin_deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),

  dragoniteingress:
    traefikingress.newIngressRoute('dragonite', $._config.namespace, 'dragonite.lsmpogo.com', 'dragonite-admin', 7273, true),

  golbat_secret:
    secret.new('golbat-secret', {}) +
    secret.withStringData({
      api_secret: $._config.golbat.apisecret,
    }) +
    secret.metadata.withNamespace($._config.namespace),

  golbat_config:
    configMap.new('golbat-config') +
    configMap.withData({
      'config.toml': $._config.golbat_config,
    }),

  golbat_container::
    container.new('golbat', $._images.golbat) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('config', '/golbat/config.toml') + k.core.v1.volumeMount.withSubPath('config.toml'),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('golbat', 9001),
      k.core.v1.containerPort.new('golbat-rpc', 50001),
    ]),

  golbat_deployment:
    deployment.new('golbat', 1, $.golbat_container) +
    deployment.mixin.metadata.withNamespace($._config.namespace) +
    deployment.spec.strategy.withType('Recreate') +
    deployment.mixin.spec.template.spec.withVolumesMixin([
      k.core.v1.volume.fromConfigMap('config',
                                     'golbat-config',
                                     [{ key: 'config.toml', path: 'config.toml' }]),
    ]),

  golbat_service:
    k.util.serviceFor($.golbat_deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),

  rotom_config:
    configMap.new('rotom-config') +
    configMap.withData({
      'local.json': $._config.rotom_config,
    }),

  rotom_container::
    container.new('rotom', $._images.rotom) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('config', '/rotom/config/local.json') + k.core.v1.volumeMount.withSubPath('local.json'),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('device', 7070),
      k.core.v1.containerPort.new('controller', 7071),
      k.core.v1.containerPort.new('client', 7072),
    ]),

  rotom_deployment:
    deployment.new('rotom', 1, $.rotom_container) +
    deployment.mixin.metadata.withNamespace($._config.namespace) +
    deployment.spec.strategy.withType('Recreate') +
    deployment.mixin.spec.template.spec.withVolumesMixin([
      k.core.v1.volume.fromConfigMap('config',
                                     'rotom-config',
                                     [{ key: 'local.json', path: 'local.json' }]),
    ]),

  rotom_service:
    k.util.serviceFor($.rotom_deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),

  rotom_device_ingress:
    traefikingress.newIngressRoute('rotom', $._config.namespace, 'rotom.lsmpogo.com', 'rotom', 7070, true, false),

  xilriws_container::
    container.new('xilriws', $._images.xilriws) +
    container.withPorts([
      k.core.v1.containerPort.new('xilriws', 5090),
    ]),

  xilriws_deployment:
    deployment.new('xilriws', 1, $.xilriws_container) +
    deployment.mixin.metadata.withNamespace($._config.namespace) +
    deployment.spec.strategy.withType('Recreate'),

  xilriws_service:
    k.util.serviceFor($.xilriws_deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),

  // ReactMap
  local rm_local_json = |||
    {
      "database": {
        "schemas": [
          {
            "note": "Scanner Database",
            "host": "${SCANNER_DB_HOST}",
            "port": ${SCANNER_DB_PORT},
            "username": "${SCANNER_DB_USERNAME}",
            "password": "${SCANNER_DB_PASSWORD}",
            "database": "${SCANNER_DB_NAME}",
            "useFor": [
              "scanCell",
              "spawnpoint",
              "gym",
              "pokestop",
              "weather",
              "pokemon"
            ]
          },
          {
            "type": "golbat",
            "endpoint": "${GOLBAT_URI}",
            "secret": "${GOLBAT_API_SECRET}",
            "useFor": [
              "device"
            ]            
          },          
          {
            "note": "React Map Database, where the migrations are ran through this app",
            "host": "${SCANNER_DB_HOST}",
            "port": ${SCANNER_DB_PORT},
            "username": "${SCANNER_DB_USERNAME}",
            "password": "${SCANNER_DB_PASSWORD}",
            "database": "${REACT_MAP_DB_NAME}",
            "useFor": [
              "session",
              "user"
            ]
          }
        ]
      },
      "icons": {
        "customizable": [
          "pokemon",
          "pokestop",
          "gym",
          "invasion",
          "reward"
        ],
        "styles": [
          {
            "name": "Default",
            "path": "https://raw.githubusercontent.com/WatWowMap/wwm-uicons/main/",
            "modifiers": {
              "gym": {
                "0": 1,
                "1": 1,
                "2": 1,
                "3": 3,
                "4": 4,
                "5": 4,
                "6": 18,
                "sizeMultiplier": 1.2
              }
            }
          },
          {
            "name": "PMSF",
            "path": "https://raw.githubusercontent.com/whitewillem/PogoAssets/main/uicons-outline/"
          },
          {
            "name": "Home",
            "path": "https://raw.githubusercontent.com/nileplumb/PkmnHomeIcons/master/UICONS/"
          },
          {
            "name": "Shuffle",
            "path": "https://raw.githubusercontent.com/nileplumb/PkmnShuffleMap/master/UICONS/"
          },
          {
            "name": "Half Shiny",
            "path": "https://raw.githubusercontent.com/jms412/PkmnShuffleMap/master/UICONS_Half_Shiny_Sparkles_256/"
          }
        ]
      }
    }
  |||,

  rmap_secret:
    secret.new('reactmap-secret', {}) +
    secret.withStringData({
      dbusername: $._config.reactmap.dbusername,
      dbpassword: $._config.reactmap.dbpassword,
    }) +
    secret.metadata.withNamespace($._config.namespace),

  rmap_container::
    container.new('reactmap', $._images.reactmap) +
    container.withCommand(['/bin/sh', '-c']) +
    container.withArgs([|||
      #!/usr/bin/env sh
      cat << EOF > /home/node/server/src/configs/local.json
      %s
      EOF

      cd /home/node
      # yarn create-area
      yarn start
    ||| % rm_local_json]) +
    container.withEnv([
      k.core.v1.envVar.new('SCANNER_DB_HOST', $._config.hostmysql.hostname),
      k.core.v1.envVar.new('SCANNER_DB_PORT', '3306'),
      k.core.v1.envVar.new('SCANNER_DB_NAME', 'golbat'),
      k.core.v1.envVar.fromSecretRef('SCANNER_DB_USERNAME', 'reactmap-secret', 'dbusername'),
      k.core.v1.envVar.fromSecretRef('SCANNER_DB_PASSWORD', 'reactmap-secret', 'dbpassword'),
      
      k.core.v1.envVar.new('GOLBAT_URI', 'http://golbat.unownhash.svc.cluster.local:9001'),
      k.core.v1.envVar.fromSecretRef('GOLBAT_API_SECRET', 'golbat-secret', 'api_secret'),

      k.core.v1.envVar.new('REACT_MAP_DB_NAME', 'reactmap'),

      k.core.v1.envVar.new('MAP_GENERAL_START_LAT', '34.639076'),
      k.core.v1.envVar.new('MAP_GENERAL_START_LON', '-120.457771'),
      k.core.v1.envVar.new('TZ', 'America/Los_Angeles'),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('http', 8080),
    ]),

  rmap_deployment:
    deployment.new('reactmap', 1, $.rmap_container) +
    deployment.mixin.metadata.withNamespace($._config.namespace),

  rmap_service:
    k.util.serviceFor($.rmap_deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),

  rmapingress:
    traefikingress.newIngressRoute('rmap', $._config.namespace, 'rmap.lsmpogo.com', 'reactmap', 8080, true),
}
