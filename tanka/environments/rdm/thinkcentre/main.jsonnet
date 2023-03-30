local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local configMap = k.core.v1.configMap,
      container = k.core.v1.container,
      deployment = k.apps.v1.deployment,
      secret = k.core.v1.secret,
      service = k.core.v1.service;

local config = import 'config.libsonnet';
local secrets = import 'secrets.libsonnet';

local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local traefikingress = import 'traefik/ingress.libsonnet';

local traefik = import 'traefik/2.8.0/main.libsonnet';
local tIngress = traefik.traefik.v1alpha1.ingressRoute;

config + secrets {
  _images+:: {
    rdm: 'ghcr.io/realdevicemap/realdevicemap/realdevicemap:1.48.0',
    rdmtools: 'ghcr.io/picklerickve/realdevicemap-tools:master',
    nginx: 'nginx',
    git: 'alpine/git',
    reactmap: 'ghcr.io/watwowmap/reactmap:main',
    whreceiver: 'python:3',
  },

  _config+:: {
    namespace: 'rdm',
  },

  rdm_secret:
    secret.new('rdm-secret', {}) +
    secret.withStringData({
      mysql_user: $._config.rdm.mysql_user,
      mysql_pass: $._config.rdm.mysql_pass,
    }) +
    secret.metadata.withNamespace($._config.namespace),


  rdm_img_pvc:
    nfspvc.new($._config.namespace, '192.168.1.20', '/mnt/ZeroThru5/k8s/thinkcentre/rdm/img', 'rdm-img'),

  rdm_backup_pvc:
    nfspvc.new($._config.namespace, '192.168.1.20', '/mnt/ZeroThru5/k8s/thinkcentre/rdm/backups', 'rdm-backups'),

  aconf_pvc:
    nfspvc.new($._config.namespace, '192.168.1.20', '/mnt/ZeroThru5/k8s/thinkcentre/aconf1', 'aconf'),
  
  rdm_container::
    container.new('rdm', $._images.rdm) +
    # container.withCommand(["sh", "-c", "tail -f /dev/null"]) + # The initial token is written to stderr, which means it won't be in the log output. You need to run the pod with this to make it wait forever, then shell into it and manually execute ./RealDeviceMapApp to see the initial token.
    container.withEnv([
      k.core.v1.envVar.new('DB_HOST', 'mysql-primary.sharedsvc.svc.cluster.local'),
      k.core.v1.envVar.new('DB_DATABASE', 'rdm_prototype'),
      k.core.v1.envVar.new('TZ', 'America/Los_Angeles'),
      k.core.v1.envVar.new('LOG_LEVEL', 'debug'),
      k.core.v1.envVar.fromSecretRef('DB_USERNAME', 'rdm-secret', 'mysql_user'),
      k.core.v1.envVar.fromSecretRef('DB_PASSWORD', 'rdm-secret', 'mysql_pass'),
      k.core.v1.envVar.fromSecretRef('DB_ROOT_USERNAME', 'rdm-secret', 'mysql_user'),
      k.core.v1.envVar.fromSecretRef('DB_ROOT_PASSWORD', 'rdm-secret', 'mysql_pass'),

      k.core.v1.envVar.new('WEB_SERVER_ADDRESS', '0.0.0.0'),
      k.core.v1.envVar.new('WEB_SERVER_PORT', '9000'),
      k.core.v1.envVar.new('WEBHOOK_SERVER_ADDRESS', '0.0.0.0'),
      k.core.v1.envVar.new('WEBHOOK_SERVER_PORT', '9001'),
      k.core.v1.envVar.new('WEBHOOK_ENDPOINT_TIMEOUT', '30'),
      k.core.v1.envVar.new('WEBHOOK_ENDPOINT_CONNECT_TIMEOUT', '30'),
      k.core.v1.envVar.new('MEMORY_CACHE_CLEAR_INTERVAL', '900'),
      k.core.v1.envVar.new('MEMORY_CACHE_KEEP_TIME', '3600'),
      k.core.v1.envVar.new('RAW_THREAD_LIMIT', '100'),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('rdm', 9000),
      k.core.v1.containerPort.new('webhook', 9001),
    ]) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('img', '/app/resources/webroot/static/img'),
      k.core.v1.volumeMount.new('backups', '/app/backups'),
    ]),

  rdm_deployment:
    deployment.new('rdm', 1, $.rdm_container) +
    deployment.mixin.metadata.withNamespace($._config.namespace) +
    deployment.mixin.spec.template.spec.withVolumesMixin([
      k.core.v1.volume.fromPersistentVolumeClaim('img', 'rdm-img-pvc'),
      k.core.v1.volume.fromPersistentVolumeClaim('backups', 'rdm-backups-pvc'),
    ]) +
    deployment.spec.strategy.withType('Recreate'),

  rdm_service:    
    k.util.serviceFor($.rdm_deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),

  rdmingress:
    traefikingress.newIngressRoute('rdm', $._config.namespace, 'rdm.lsmpogo.com', 'rdm', 9000, true),

  rdmwebhookingress:
    traefikingress.newIngressRoute('rdmwebhook', $._config.namespace, 'rdm-webhook.lsmpogo.com', 'rdm', 9001, true),

  // aconf
  aconf_traefik_basic_auth_secret:
    secret.new('aconf-basic-auth-secret', {}) +
    secret.withType('kubernetes.io/basic-auth') +
    secret.withStringData({
      username: $._config.aconf.username,
      password: $._config.aconf.password,
    }) +
    secret.mixin.metadata.withNamespace($._config.namespace),

  aconf_traefik_basic_auth_middleware:
    {
      apiVersion: 'traefik.containo.us/v1alpha1',
      kind: 'Middleware',
      metadata: {
        name: 'aconf-basic-auth-mw',
        labels: {
          traefikzone: 'public',
        },
      },
      spec: {
        basicAuth: { secret: 'aconf-basic-auth-secret' },
      },
    },

  aconf_container::
    container.new('aconf', $._images.nginx) +
    container.withPorts([
      k.core.v1.containerPort.new('http', 80)
    ]) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('html', '/usr/share/nginx/html'),
    ]),

  aconf_deployment:
    deployment.new('aconf', 1, $.aconf_container) +
    deployment.mixin.metadata.withNamespace($._config.namespace) +
    deployment.mixin.spec.template.spec.withVolumesMixin([
      k.core.v1.volume.fromPersistentVolumeClaim('html', 'aconf-pvc'),
    ]),

  aconf_service:    
    k.util.serviceFor($.aconf_deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),

  aconfingress:
    tIngress.new('aconf') +
    tIngress.metadata.withNamespace($._config.namespace) +
    tIngress.metadata.withLabelsMixin({
      traefikzone: 'public',
    }) +
    tIngress.spec.withEntryPoints(['web']) +
    tIngress.spec.withRoutes([
      tIngress.spec.routes.withKind('Rule') +
      tIngress.spec.routes.withMatch('Host(`aconf.lsmpogo.com`)') +
      tIngress.spec.routes.withMiddlewares(
        tIngress.spec.routes.middlewares.withName('redirect-websecure') +
        tIngress.spec.routes.middlewares.withNamespace('traefik'),
      ) +
      tIngress.spec.routes.withServices(
        tIngress.spec.routes.services.withName('aconf') +
        tIngress.spec.routes.services.withPort(80),
      ),
    ]),

  aconfingresstls:
    tIngress.new('aconf-tls') +
    tIngress.metadata.withNamespace($._config.namespace) +
    tIngress.metadata.withLabelsMixin({
      traefikzone: 'public',
    }) +
    tIngress.spec.withEntryPoints(['websecure']) +
    tIngress.spec.withRoutes([
      tIngress.spec.routes.withKind('Rule') +
      tIngress.spec.routes.withMatch('Host(`aconf.lsmpogo.com`)') +
      tIngress.spec.routes.withMiddlewares(
        tIngress.spec.routes.middlewares.withName('aconf-basic-auth-mw') +
        tIngress.spec.routes.middlewares.withNamespace($._config.namespace),
      ) +
      tIngress.spec.routes.withServices(
        tIngress.spec.routes.services.withName('aconf') +
        tIngress.spec.routes.services.withPort(80),
      ),
    ]) +
    tIngress.spec.tls.withCertResolver('mydnschallenge'),

  // RDM Tools
  rdmtools_secret:
    secret.new('rdmtools-secret', {}) +
    secret.withStringData({
      mysql_user: $._config.rdmtools.mysql_user,
      mysql_pass: $._config.rdmtools.mysql_pass,
    }) +
    secret.metadata.withNamespace($._config.namespace),

  rdmtools_container::
    container.new('rdmtools', $._images.rdmtools) +
    container.withEnv([
      k.core.v1.envVar.new('DB_HOST', 'mysql-primary.sharedsvc.svc.cluster.local'),
      k.core.v1.envVar.new('DB_PORT', '3306'),
      k.core.v1.envVar.new('DB_NAME', 'rdm_prototype'),
      k.core.v1.envVar.fromSecretRef('DB_USER', 'rdmtools-secret', 'mysql_user'),
      k.core.v1.envVar.fromSecretRef('DB_PSWD', 'rdmtools-secret', 'mysql_pass'),      
      k.core.v1.envVar.new('TZ', 'America/Los_Angeles'),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('http', 80)
    ]),

  rdmtools_deployment:
    deployment.new('rdmtools', 1, $.rdmtools_container) +
    deployment.mixin.metadata.withNamespace($._config.namespace),

  rdmtools_service:    
    k.util.serviceFor($.rdmtools_deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),

  rdmtoolsingress:
    traefikingress.newIngressRoute('rdmtools', $._config.namespace, 'rdmtools.lsmpogo.com', 'rdmtools', 80, true),

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
                    "device",
                    "gym",
                    "pokemon",
                    "pokestop",
                    "scanCell",
                    "spawnpoint",
                    "weather"
                  ]
                },
                {
                  "note": "React Map Database, where the migrations are ran through this app",
                  "host": "${REACT_MAP_DB_HOST}",
                  "port": ${REACT_MAP_DB_PORT},
                  "username": "${REACT_MAP_DB_USERNAME}",
                  "password": "${REACT_MAP_DB_PASSWORD}",
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

  rmap_container::
    container.new('reactmap', $._images.reactmap) +
    container.withCommand(['/bin/sh', '-c']) +
    container.withArgs([|||
      #!/usr/bin/env sh
      cat << EOF > /home/node/server/src/configs/local.json
      %s
      EOF
      
      cat << EOF > /home/node/server/src/configs/geofence.json.blah
      %s
      EOF
      cd /home/node
      # yarn create-area
      yarn start
    ||| % [rm_local_json, (importstr '../../../lib/poracle/geofence.json')]]) +
    container.withEnv([
      k.core.v1.envVar.new('SCANNER_DB_HOST', 'mysql-primary.sharedsvc.svc.cluster.local'),
      k.core.v1.envVar.new('SCANNER_DB_PORT', '3306'),
      k.core.v1.envVar.new('SCANNER_DB_NAME', 'rdm_prototype'),
      k.core.v1.envVar.fromSecretRef('SCANNER_DB_USERNAME', 'rdm-secret', 'mysql_user'),
      k.core.v1.envVar.fromSecretRef('SCANNER_DB_PASSWORD', 'rdm-secret', 'mysql_pass'),
      
      k.core.v1.envVar.new('REACT_MAP_DB_HOST', 'mysql-primary.sharedsvc.svc.cluster.local'),
      k.core.v1.envVar.new('REACT_MAP_DB_PORT', '3306'),
      k.core.v1.envVar.new('REACT_MAP_DB_NAME', 'reactmap'),
      k.core.v1.envVar.fromSecretRef('REACT_MAP_DB_USERNAME', 'rdm-secret', 'mysql_user'),
      k.core.v1.envVar.fromSecretRef('REACT_MAP_DB_PASSWORD', 'rdm-secret', 'mysql_pass'),

      k.core.v1.envVar.new('MAP_GENERAL_START_LAT', '34.639076'),
      k.core.v1.envVar.new('MAP_GENERAL_START_LON', '-120.457771'),
      k.core.v1.envVar.new('TZ', 'America/Los_Angeles'),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('http', 8080)
    ]),

  rmap_deployment:
    deployment.new('reactmap', 1, $.rmap_container) +
    deployment.mixin.metadata.withNamespace($._config.namespace),

  rmap_service:    
    k.util.serviceFor($.rmap_deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),

  rmapingress:
    traefikingress.newIngressRoute('rmap', $._config.namespace, 'rmap.lsmpogo.com', 'reactmap', 8080, true),

  // ATV Details WH Receiver  
  whreceiver_secret:
    secret.new('whreceiver', {}) +
    secret.withStringData({
      mysql_user: $._config.atvdetailswh.mysql_user,
      mysql_pass: $._config.atvdetailswh.mysql_pass,
    }) +
    secret.metadata.withNamespace($._config.namespace),

  whreceiver_traefik_basic_auth_secret:
    secret.new('whreceiver-basic-auth-secret', {}) +
    secret.withType('kubernetes.io/basic-auth') +
    secret.withStringData({
      username: $._config.atvdetailswh.ingress_user,
      password: $._config.atvdetailswh.ingress_pass,
    }) +
    secret.mixin.metadata.withNamespace($._config.namespace),

  whreceiver_traefik_basic_auth_middleware:
    {
      apiVersion: 'traefik.containo.us/v1alpha1',
      kind: 'Middleware',
      metadata: {
        name: 'whreceiver-basic-auth-mw',
        labels: {
          traefikzone: 'public',
        },
      },
      spec: {
        basicAuth: { secret: 'whreceiver-basic-auth-secret' },
      },
    },

  whreceiver_container::
    container.new('whreceiver', $._images.whreceiver) +
    container.withCommand(['/bin/sh', '-c']) +
    container.withArgs([|||
      #!/usr/bin/env sh
      mkdir -p /opt/whreceiver
      curl -o /opt/whreceiver/requirements.txt https://raw.githubusercontent.com/dkmur/aconf/rom/wh_receiver/requirements.txt
      curl -o /opt/whreceiver/start_whreceiver.py https://raw.githubusercontent.com/dkmur/aconf/rom/wh_receiver/start_whreceiver.py
      cat << EOF > /opt/whreceiver/config.ini
      [socketserver]
      host = 0.0.0.0
      port = 80

      [mysql]
      mysqlhost = ${DB_HOST}
      mysqlport = ${DB_PORT}
      mysqldb = ${DB_NAME}
      mysqluser = ${DB_USER}
      mysqlpass = ${DB_PASS}
      EOF
      
      cd /opt/whreceiver
      pip3 install -r requirements.txt
      python start_whreceiver.py
    |||]) +
    container.withEnv([
      k.core.v1.envVar.new('DB_HOST', 'mysql-primary.sharedsvc.svc.cluster.local'),
      k.core.v1.envVar.new('DB_PORT', '3306'),
      k.core.v1.envVar.new('DB_NAME', 'atvdetails'),
      k.core.v1.envVar.fromSecretRef('DB_USER', 'whreceiver', 'mysql_user'),
      k.core.v1.envVar.fromSecretRef('DB_PASS', 'whreceiver', 'mysql_pass'),
      
      k.core.v1.envVar.new('TZ', 'America/Los_Angeles'),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('http', 80)
    ]),    

  whreceiver_deployment:
    deployment.new('whreceiver', 1, $.whreceiver_container) +
    deployment.mixin.metadata.withNamespace($._config.namespace),

  whreceiver_service:    
    k.util.serviceFor($.whreceiver_deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),
    
  whreceiveringress:
    tIngress.new('whreceiver') +
    tIngress.metadata.withNamespace($._config.namespace) +
    tIngress.metadata.withLabelsMixin({
      traefikzone: 'public',
    }) +
    tIngress.spec.withEntryPoints(['web']) +
    tIngress.spec.withRoutes([
      tIngress.spec.routes.withKind('Rule') +
      tIngress.spec.routes.withMatch('Host(`atvdetails.lsmpogo.com`)') +
      tIngress.spec.routes.withMiddlewares(
        tIngress.spec.routes.middlewares.withName('redirect-websecure') +
        tIngress.spec.routes.middlewares.withNamespace('traefik'),
      ) +
      tIngress.spec.routes.withServices(
        tIngress.spec.routes.services.withName('whreceiver') +
        tIngress.spec.routes.services.withPort(80),
      ),
    ]),

  whreceiveringresstls:
    tIngress.new('whreceiver-tls') +
    tIngress.metadata.withNamespace($._config.namespace) +
    tIngress.metadata.withLabelsMixin({
      traefikzone: 'public',
    }) +
    tIngress.spec.withEntryPoints(['websecure']) +
    tIngress.spec.withRoutes([
      tIngress.spec.routes.withKind('Rule') +
      tIngress.spec.routes.withMatch('Host(`atvdetails.lsmpogo.com`)') +
      tIngress.spec.routes.withMiddlewares(
        tIngress.spec.routes.middlewares.withName('whreceiver-basic-auth-mw') +
        tIngress.spec.routes.middlewares.withNamespace($._config.namespace),
      ) +
      tIngress.spec.routes.withServices(
        tIngress.spec.routes.services.withName('whreceiver') +
        tIngress.spec.routes.services.withPort(80),
      ),
    ]) +
    tIngress.spec.tls.withCertResolver('mydnschallenge'),
}
