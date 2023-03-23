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

local redis = import 'redis/main.libsonnet';

local namespace = 'madasync';

config + secrets {
  _images+:: {
    busybox: 'registry.ryangeyer.com/busybox:latest',
    redis: 'redis:latest',
    madbe: 'ghcr.io/map-a-droid/mad:async',
    // madbe: 'ghcr.io/map-a-droid/mad:async_account_switching',
  },

  _config+:: {
    namespace: namespace,

    // TODO: This should probably move to the top level config
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

  filepvc:
    nfspvc.new(namespace, '192.168.1.20', '/mnt/ZeroThru5/k8s/thinkcentre/madbe/files', 'async-madbe-files'),

  // Not sure this is needed if we don't use the stats personal command anymore
  // logpvc:
  //   nfspvc.new(namespace, '192.168.1.20', '/mnt/ZeroThru5/k8s/thinkcentre/madbe/logs', 'madbe-logs'),

  pcpvc:
    nfspvc.new(namespace, '192.168.1.20', '/mnt/ZeroThru5/k8s/thinkcentre/madbe/personal_commands', 'async-madbe-personal-commands'),

  apkpvc:
    nfspvc.new(namespace, '192.168.1.20', '/mnt/ZeroThru5/k8s/thinkcentre/madbe/apks', 'async-madbe-apks'),

  pluginpvc:
    nfspvc.new(namespace, '192.168.1.20', '/mnt/ZeroThru5/k8s/thinkcentre/madbe/plugins', 'async-madbe-plugins'),

  redis: redis + config_mixin,

  maddb_secret:
    secret.new('mysql-secret', {}) +
    secret.withStringData({
      username: $._config.mad.mysql_mad.username,
      password: $._config.mad.mysql_mad.password,
    }) +
    secret.mixin.metadata.withNamespace($._config.namespace),

  madmin_secret:
    secret.new('madmin-secret', {}) +
    secret.withStringData({
      'maddev-api-token': $._config.mad.maddev_api_token,
      madminuser: $._config.mad.madmin.username,
      madminpass: $._config.mad.madmin.password,
    }) +
    secret.mixin.metadata.withNamespace($._config.namespace),

  cm:
    configMap.new('madbecfg') +
    configMap.mixin.metadata.withNamespace($._config.namespace) +
    configMap.withData({
      'config.ini': |||
        db_poolsize: 2

        ### Redis Caching
        # Redis cache host (Default: localhost)
        cache_host: redis.madasync.svc.cluster.local
        mitmmapper_type: redis

        delete_mons_n_hours: 2
        delete_incidents_n_hours:24

        token_dispenser: /usr/src/app/dyncfg/token-dispensers.ini

        rarity_hours: 24

        # If it's file, where is it?
        apk_storage_interface: db

        # Setup name for this instance - if not set: PID of the process will be used
        #status-name:

        ### MappingManager gRPC
        ######################
        ## The following settings enable the communication to the mapping manager using gRPC. This is needed if MAD is split
        ## across multiple processes/hosts (e.g., multiple mitm receivers)
        ######################
        # IP of MappingManager gRPC server to connect to OR - if serving - to listen on. Default: all interfaces (0.0.0.0)
        #mappingmanager_ip: madbe-core
        # Port to listen on for the MappingManager gRPC API (main MAD component) or connect to. Default: 50052
        #mappingmanager_port:
        # In case a secure connection is desired, the server needs to know a private key.
        #mappingmanager_tls_private_key_file:
        # In case a secure connection is desired, clients and server need to have the cert file available.
        #mappingmanager_tls_cert_file:
        # Enable compression of data of the MappingManager gRPC communication. Default: False
        #mappingmanager_compression:

        ## MitmMapper gRPC related settings
        # IP to listen on for the MitmMapper gRPC API or connect to (separate MAD component). Default: [::]
        #mitmmapper_ip:
        # Port to listen on for the MitmMapper gRPC API or connect to (separate MAD component). Default: 50051
        #mitmmapper_port:
        # In case a secure connection is desired, the server needs to know a private key.
        #mitmmapper_tls_private_key_file:
        # In case a secure connection is desired, clients and server need to have the cert file available.
        #mitmmapper_tls_cert_file:
        # Enable compression of data of the MitmMapper gRPC communication. Default: False
        #mitmmapper_compression:

        ### Stats handler gRPC related settings
        ######################
        ## The stats collection is usually run within the core component of MAD. If multiple processes/hosts are running MAD,
        ## the connection information to the core stats handler need to be inserted. Optionally, the stats handler itself can
        ## run as its own process (on another host as well) due to the use of gRPC.
        ######################
        # IP to listen on for the StatsHandler gRPC API or connect to (separate MAD component. Default: [::]
        #statshandler_ip:
        # Port to listen on for the StatsHandler gRPC API or connect to (separate MAD component). Default: 50053
        #statshandler_port:
        # In case a secure connection is desired, the server needs to know a private key.
        #statshandler_tls_private_key_file:
        # In case a secure connection is desired, clients and server need to have the cert file available.
        #statshandler_tls_cert_file:
        # Enable compression of data of the StatsHandler gRPC communication. Default: False
        #statshandler_compression:

        ### Websocket Settings
        ######################
        ## The websocket of MAD is where all devices running RGC connect to. Using this websocket, devices are controlled
        ## using the bidirectional communication.
        ######################
        # IP for websocket to listen on. Default: 0.0.0.0
        #ws_ip:
        # Port of the websocket to listen on. Default: 8080
        #ws_port:
        # The max time to wait for a command to return (in seconds). Default: 30 seconds
        #websocket_command_timeout:


        ### MITM Receiver
        ######################
        ## The MitmReceiver is the component of MAD which receives all data by the MITM client. I.e., this is where all the
        ## data collected is processed.
        ######################
        # IP to listen on for proto data (MITM data). Default: 0.0.0.0
        #mitmreceiver_ip:
        # Port to listen on for proto data (MITM data). Default: 8000
        #mitmreceiver_port:
        # Amount of workers to work off the data that queues up. Default: 2
        #mitmreceiver_data_workers:
        # Ignore MITM data having a timestamp pre MAD's startup time
        #mitm_ignore_pre_boot:
        # Header Authorization password for MITM /status/ page
        #mitm_status_password:
        # Path to unix socket file to use if TCP is not to be used for MITMReceiver. Disabled TCP (ip/port) listening.
        #mitm_unix_socket:
        # Enable X-Fordward-Path allowance for reverse proxy usage for MITMReceiver. Default: False
        #enable_x_forwarded_path_mitm_receiver:


        ### Job Processor
        ######################
        ## MAD allows for the creation of custom jobs used for, e.g., the maintenance of devices using MADmin.
        ######################
        # Send job status to discord (Default: False). Default: False
        #job_dt_wh:
        # Discord Webhook URL for job messages
        #job_dt_wh_url:
        # Kind of Job Messages to send - separated by pipe | (Default: SUCCESS|FAILURE|NOCONNECT|TERMINATED)
        #job_dt_send_type:
        # Restart job if device is not connected (in minutes). Default: 0 (Off)
        #job_restart_notconnect:
        # Amount of threads to work off the device jobs. Default: 1
        #job_thread_count:


        ### Miscellaneous
        ######################
        # Use this instance only for scanning. Default: True
        #only_scan
        # Amount of threads/processes to be used for screenshot-analysis. Default: 2
        #ocr_thread_count:
        # Only calculate routes, then exit the program. No scanning. Default: False
        #only_routes:
        # Run in ConfigMode. Default: False
        #config_mode:
        # Enable scanning of nearby mons - Please make sure you know how this works before turning it on!
        #scan_nearby_mons:
        # Disables nearby_cell scans if scan_nearby_mons is enabled
        #disable_nearby_cell:
        # Enable scanning of lured mons
        #scan_lured_mons:
        # The default despawn time left in minutes for Nearby Mons. Default: 15
        #default_nearby_timeleft:
        # The default despawn time left in minutes for Mons at unknown Spawnpoints. Default: 3
        #default_unknown_timeleft:        
        # Disable event checker task
        #no_event_checker:
        # Option to enable/disable extra handling for the start/stop routine of workers. Default: False
        #enable_worker_specific_extra_start_stop_handling:
        # The maximum distance for a scan of a location to be considered a valid/correct scan of that location in meters. Default: 5m
        #maximum_valid_distance:
        # The storage type used for APKs. Either APKs are stored in the DB (accessible by, e.g., MitmReceivers as well) or
        # entirely file based (fs -> file storage) (only recommended for small setups running within a single process).
        # Possible values: [db, fs].        

        ### Filepath Settings
        ######################
        ## MAD uses temporary files and file storage in general for some operations such as storing screenshots
        ######################
        # Path for generated files while detecting raids (Default: temp/)
        #temp_path:
        # Path for uploaded Files via madmin and for device installation. (Default: upload/)
        #upload_path:
        # Defines directory to save worker stats- and position files and calculated routes (Default: files/)
        #file_path:


        ### Other Settings
        ######################
        # Center Lat of your scan location (Default: 0.0)
        #home_lat:
        # Center Lng of your scan location (Default: 0.0)
        #home_lng:
        # Language for several things like quests or mon names in the IV list (default:en - others: de, fr )
        #language:
        # Do not fetch quest title resources from pokeminers. Will instead use internal parsing: Default: False
        #no_quest_titles:


        ### MADmin
        ######################
        ## MADmin is used to see the overall status of all devices connected, control devices manually, and display statistics.
        ######################
        # SET IT VIA REVERSE PROXY/Apache2(AuthType Basic)/nginx(auth_basic). THIS IS NOT WORKING. check configs/examples/nginx/foo.conf
        #madmin_user:
        # SET IT VIA REVERSE PROXY/Apache2(AuthType Basic)/nginx(auth_basic). THIS IS NOT WORKING. check configs/examples/nginx/foo.conf
        #madmin_password:
        # Disable Madmin on the instance
        #disable_madmin:
        # Base path for madmin
        #madmin_base_path:
        # MADmin listening interface (Default: 0.0.0.0)
        #madmin_ip:
        # Highly recommended to change. MADmin web port (Default: 5000)
        #madmin_port:
        # MADmin clock format (12/24) (Default: 24)
        #madmin_time:
        # MADmin deactivate responsive tables
        #madmin_noresponsive:
        # Enables MADmin /quests_pub, /get_quests, and pushassets endpoints for public quests overview. Default: False
        #quests_public:
        # Define when a spawnpoint is out of date (in days). Default: 3.
        #outdated_spawnpoints:
        # Comma separated list of geofences names to use for Quest/Stop Stats page (Empty: all)
        #quest_stats_fences:
        # Enable X-Fordward-Path allowance for reverse proxy usage for MADmin. Default: False
        #enable_x_forwarded_path_madmin:


        ### Statistics
        ######################
        # Activate system statistics (CPU / Memory usage)
        #statistic:
        # Enable statistics for collected object (garbage collector) - if you really need this info. It may decrese performance
        # significantly.
        #stat_gc:
        # Update interval for the usage generator in seconds (Default: 60)
        #statistic_interval:


        ### Game Stats
        ######################
        # Generate worker stats
        #game_stats:
        # Generate worker raw stats (only with --game_stats)')
        #game_stats_raw:
        # Number of seconds until worker information is saved to database (Default: 300)
        #game_stats_save_time:
        # Delete shiny mon in raw stats older then x days (0 =  Disable (Default))
        #raw_delete_shiny:


        ### ADB
        ######################
        ## If you want to have a fallback connection to control devices, ADB can optionally be used. For this purpose, the
        ## following settings can be used.
        ######################
        # Use ADB for "device control" (Default: False)
        #use_adb:
        # IP address of ADB server (Default: 127.0.0.1)
        #adb_server_ip:
        # Port of ADB server (Default: 5037)
        #adb_server_port:


        ### Webhook
        ######################
        ## The following options allow you to configure where data is sent asap to inform users via, e.g., social media about
        ## certain mon spawns
        ######################
        # Activate support for webhook. Default: False
        #webhook:
        # webhook endpoint (multiple seperated by comma)
        #  use [<type>] in front of the url, if you want to split data between multiple endpoints. Ex: [pokemon]http://foo.com,[raid]http://bar.com
        #  possible types are: raid, gym, weather, pokestop, quest, pokemon
        #  different pokemon types: encounter, wild, nearby_stop, nearby_cell, lure_encounter, lure_wild
        #webhook_url:
        # Send Ex-raids to the webhook if detected
        #webhook_submit_exraids:
        # Comma-separated list of area names to exclude elements from within an area to be sent to a webhook.
        #webhook_excluded_areas:
        # Mode for quest webhooks (default or poracle)
        #quest_webhook_flavor:
        # Debug: Set initial timestamp to fetch changed elements from the DB to send via WH.
        #webhook_start_time:
        # Split up the payload into chunks and send multiple requests. Default: 0 (unlimited)
        #webhook_max_payload_size:
        # Send webhook payload every X seconds (Default: 10)
        #webhook_worker_interval: 10

        ### Dynamic Rarity
        ######################
        # Set the number of hours for the calculation of pokemon rarity (Default: 72)
        #rarity_hours:
        # Update frequency for dynamic rarity in minutes (Default: 60)
        #rarity_update_frequency:


        ### Logging
        ######################
        # Disable file logging (Default: file logging is enabled by default)
        #no_file_logs:
        # Defines directory to save log files to (Default: logs/)
        #log_path:
        # Defines the log filename to be saved. Allows date formatting, and replaces <SN>
        #  with the instance's status name (Default: Default: %Y%m%d_%H%M_<SN>.log)
        #log_filename:
        # This parameter expects a human-readable value like '18:00', 'sunday', 'weekly', 'monday
        #  at 12:00' or a maximum file size like '100 MB' or '0.5 GB'. Set to '0' to disable completely. (Default: 50 MB)
        #log_file_rotation:
        # Forces a certain log level. By default by the -v command to show DEBUG logs.
        # Custom log levels like DEBUG[1-5] can be used too
        #log_level:
        # File logging level. See description for --log_level.
        #log_file_level:
        # amount of days to keep file logs. Set to 0 to keep them forever (Default: 10)
        #log_file_retention:
        # Disable colored logs. Default: False
        #no_log_colors:


        # MADAPKs wizard
        ######################
        # Token used by the wizard to query supported versions. You can find it as 'API token' on first page after logging into MADdev auth backend (not device/account password).
        #maddev_api_token:
        # Path to token dispenser config (MAD-provided)
        #token_dispenser:
        # Path to token dispenser config (User-provided)
        #token_dispenser_user:


        # Auto-Config
        ######################
        # MAD PoGo auth is not required during autoconfiguration
        #autoconfig_no_auth:

        # Report MITMReceiver queue value to Redis
        # This is only useful for split/multi start_mitmreceiver.py approach and if you have anything that going to monitor your queue value.
        # Remember to set a unique key for each start_mitmreceiver you are running. You most likely want to override it in command line rather via config.ini
        ######################
        # Redis key used to store MITMReceiver queue value
        #redis_report_queue_key: MITMReceiver_queue_len_mitm1
        # Interval of reporting value - every 30 seconds by default
        #redis_report_queue_interval: 30
      |||,

      'run.sh': |||
        #!/bin/sh

        cp /usr/src/app/dyncfg/config.ini /usr/src/app/configs/config.ini

        cat << EOF >> /usr/src/app/configs/config.ini        
        dbip: ${SQLHOST}
        dbusername: ${SQLUSER}
        dbpassword: ${SQLPASS}
        dbname: ${SQLDBNAME}

        maddev_api_token: ${MADDEVAPITOKEN}

        mappingmanager_ip: ${MAPPINGMANAGER}
        statshandler_ip: ${STATSHANDLER}
        EOF

        cd /usr/src/app
        python3 ${@}
      |||,

      'token-dispensers.ini': |||
        http://auroraoss.in:8080
        http://auroraoss.com:8080
      |||,
    }),

  init_container::
    container.new('madbeinit', $._images.busybox) +
    container.withCommand(['/bin/sh', '-c']) +
    container.withArgs([|||
      cp /tmp/config/run.sh /runscript/run.sh
      chown root:root /runscript/run.sh
      chmod o+x /runscript/run.sh
    |||]) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('config', '/tmp/config'),
      k.core.v1.volumeMount.new('runscript', '/runscript'),
    ]),

  core_container::
    container.new('core', $._images.madbe) +
    container.withImagePullPolicy('Always') +
    container.withCommand(['/runscript/run.sh']) +
    container.withArgs([
      'start_core.py',
      '--no_log_colors',
    ]) +
    container.withEnv([
      k.core.v1.envVar.new('TZ', 'America/Los_Angeles'),
      k.core.v1.envVar.fromSecretRef('SQLPASS', $._config.madmysql.secretname, $._config.madmysql.secretpasskey),
      k.core.v1.envVar.new('SQLHOST', 'mysql-mad-primary.mad.svc.cluster.local'),
      k.core.v1.envVar.fromSecretRef('SQLUSER', $._config.madmysql.secretname, $._config.madmysql.secretuserkey),
      k.core.v1.envVar.new('SQLDBNAME', 'async_madpoc'),
      k.core.v1.envVar.fromSecretRef('MADDEVAPITOKEN', 'madmin-secret', 'maddev-api-token'),
      k.core.v1.envVar.fromSecretRef('MADMINUSER', 'madmin-secret', 'madminuser'),
      k.core.v1.envVar.fromSecretRef('MADMINPASS', 'madmin-secret', 'madminpass'),
      k.core.v1.envVar.new('MAPPINGMANAGER', '0.0.0.0'),
      k.core.v1.envVar.new('STATSHANDLER', '0.0.0.0'),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('mad-core', 5000),
      k.core.v1.containerPort.new('mitm-receiever', 8000),
      k.core.v1.containerPort.new('rgc', 8080),
      k.core.v1.containerPort.new('mapping-manager', 50052),
      k.core.v1.containerPort.new('mitm-manager', 50051),
      k.core.v1.containerPort.new('stats-handler', 50053),
    ]) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('config', '/usr/src/app/dyncfg'),
      k.core.v1.volumeMount.new('runscript', '/runscript'),
      k.core.v1.volumeMount.new('files', '/usr/src/app/files'),
      // k.core.v1.volumeMount.new('logs', '/usr/src/app/logs'),
      k.core.v1.volumeMount.new('personal-commands', '/usr/src/app/personal_commands'),
      k.core.v1.volumeMount.new('apks', '/usr/src/app/temp/mad_apk'),
      // Maybe at some point we dynamically fetch these from their origins?
      k.core.v1.volumeMount.new('plugins', '/usr/src/app/plugins'),
    ]),
  // When we get to prod
  // container.resources.withRequests({memory: "8G"}) +
  // container.resources.withLimits({memory: "16G"}),

  stats_container::
    container.new('stats', $._images.madbe) +
    container.withImagePullPolicy('Always') +
    container.withCommand(['/runscript/run.sh']) +
    container.withArgs([
      'start_statshandler.py',
      '--no_log_colors',
    ]) +
    container.withEnv([
      k.core.v1.envVar.new('TZ', 'America/Los_Angeles'),
      k.core.v1.envVar.fromSecretRef('SQLPASS', $._config.madmysql.secretname, $._config.madmysql.secretpasskey),
      k.core.v1.envVar.new('SQLHOST', 'mysql-mad-primary.mad.svc.cluster.local'),
      k.core.v1.envVar.fromSecretRef('SQLUSER', $._config.madmysql.secretname, $._config.madmysql.secretuserkey),
      k.core.v1.envVar.new('SQLDBNAME', 'async_madpoc'),
      k.core.v1.envVar.fromSecretRef('MADDEVAPITOKEN', 'madmin-secret', 'maddev-api-token'),
      k.core.v1.envVar.fromSecretRef('MADMINUSER', 'madmin-secret', 'madminuser'),
      k.core.v1.envVar.fromSecretRef('MADMINPASS', 'madmin-secret', 'madminpass'),
      k.core.v1.envVar.new('MAPPINGMANAGER', '0.0.0.0'),
      k.core.v1.envVar.new('STATSHANDLER', '0.0.0.0'),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('mad-core', 5000),
      k.core.v1.containerPort.new('mitm-receiever', 8000),
      k.core.v1.containerPort.new('rgc', 8080),
      k.core.v1.containerPort.new('mapping-manager', 50052),
      k.core.v1.containerPort.new('mitm-manager', 50051),
      k.core.v1.containerPort.new('stats-handler', 50053),
    ]) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('config', '/usr/src/app/dyncfg'),
      k.core.v1.volumeMount.new('runscript', '/runscript'),
      k.core.v1.volumeMount.new('files', '/usr/src/app/files'),
      // k.core.v1.volumeMount.new('logs', '/usr/src/app/logs'),
      k.core.v1.volumeMount.new('personal-commands', '/usr/src/app/personal_commands'),
      k.core.v1.volumeMount.new('apks', '/usr/src/app/temp/mad_apk'),
      // Maybe at some point we dynamically fetch these from their origins?
      k.core.v1.volumeMount.new('plugins', '/usr/src/app/plugins'),
    ]),
  // When we get to prod
  // container.resources.withRequests({memory: "8G"}) +
  // container.resources.withLimits({memory: "16G"}),

  core_deployment:
    deployment.new('madbe-core', 1, [$.core_container, $.stats_container]) +
    deployment.spec.template.metadata.withLabels({
      name: 'madbe-core',
      madcore: 'core',
      madrgc: 'rgc',
    }) +
    deployment.spec.template.spec.withInitContainers($.init_container) +
    deployment.spec.strategy.withType('Recreate') +
    deployment.mixin.metadata.withNamespace($._config.namespace) +
    deployment.mixin.spec.template.spec.withVolumesMixin([
      k.core.v1.volume.fromEmptyDir('runscript'),
      k.core.v1.volume.fromConfigMap('config', 'madbecfg'),
      k.core.v1.volume.fromPersistentVolumeClaim('files', 'async-madbe-files-pvc'),
      // k.core.v1.volume.fromPersistentVolumeClaim('logs', 'async-madbe-logs-pvc'),
      k.core.v1.volume.fromPersistentVolumeClaim('personal-commands', 'async-madbe-personal-commands-pvc'),
      k.core.v1.volume.fromPersistentVolumeClaim('apks', 'async-madbe-apks-pvc'),
      k.core.v1.volume.fromPersistentVolumeClaim('plugins', 'async-madbe-plugins-pvc'),
    ]),
  // Pin it to the HX90
  // deployment.spec.template.spec.withNodeName('mad-hx90'),

  receiver_container::
    container.new('reciever', $._images.madbe) +
    container.withImagePullPolicy('Always') +
    container.withCommand(['/runscript/run.sh']) +
    container.withArgs([
      'start_mitmreceiver.py',
      '--no_log_colors',
    ]) +
    container.withEnv([
      k.core.v1.envVar.new('TZ', 'America/Los_Angeles'),
      k.core.v1.envVar.fromSecretRef('SQLPASS', $._config.madmysql.secretname, $._config.madmysql.secretpasskey),
      k.core.v1.envVar.new('SQLHOST', 'mysql-mad-primary.mad.svc.cluster.local'),
      k.core.v1.envVar.fromSecretRef('SQLUSER', $._config.madmysql.secretname, $._config.madmysql.secretuserkey),
      k.core.v1.envVar.new('SQLDBNAME', 'async_madpoc'),
      k.core.v1.envVar.fromSecretRef('MADDEVAPITOKEN', 'madmin-secret', 'maddev-api-token'),
      k.core.v1.envVar.fromSecretRef('MADMINUSER', 'madmin-secret', 'madminuser'),
      k.core.v1.envVar.fromSecretRef('MADMINPASS', 'madmin-secret', 'madminpass'),
      k.core.v1.envVar.new('MAPPINGMANAGER', 'mad-core'),
      k.core.v1.envVar.new('STATSHANDLER', 'mad-core'),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('mitm-receiever', 8000),
    ]) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('config', '/usr/src/app/dyncfg'),
      k.core.v1.volumeMount.new('runscript', '/runscript'),
      k.core.v1.volumeMount.new('files', '/usr/src/app/files'),
      // k.core.v1.volumeMount.new('logs', '/usr/src/app/logs'),
      k.core.v1.volumeMount.new('personal-commands', '/usr/src/app/personal_commands'),
      k.core.v1.volumeMount.new('apks', '/usr/src/app/temp/mad_apk'),
      // Maybe at some point we dynamically fetch these from their origins?
      k.core.v1.volumeMount.new('plugins', '/usr/src/app/plugins'),
    ]),
  // When we get to prod
  // container.resources.withRequests({memory: "8G"}) +
  // container.resources.withLimits({memory: "16G"}),

  mitm_recv_deployment:
    deployment.new('madbe-mitm-receiver', 1, $.receiver_container) +
    deployment.spec.template.metadata.withLabels({
      name: 'madbe-mitm-receiver',
      madmitmrecv: 'mitmrecv',
    }) +
    deployment.spec.template.spec.withInitContainers($.init_container) +
    deployment.spec.strategy.withType('Recreate') +
    deployment.mixin.metadata.withNamespace($._config.namespace) +
    deployment.mixin.spec.template.spec.withVolumesMixin([
      k.core.v1.volume.fromEmptyDir('runscript'),
      k.core.v1.volume.fromConfigMap('config', 'madbecfg'),
      k.core.v1.volume.fromPersistentVolumeClaim('files', 'async-madbe-files-pvc'),
      // k.core.v1.volume.fromPersistentVolumeClaim('logs', 'async-madbe-logs-pvc'),
      k.core.v1.volume.fromPersistentVolumeClaim('personal-commands', 'async-madbe-personal-commands-pvc'),
      k.core.v1.volume.fromPersistentVolumeClaim('apks', 'async-madbe-apks-pvc'),
      k.core.v1.volume.fromPersistentVolumeClaim('plugins', 'async-madbe-plugins-pvc'),
    ]),
  // Pin it to the HX90
  // deployment.spec.template.spec.withNodeName('mad-hx90'),

  madmin_traefik_basic_auth_secret:
    secret.new('madmin-basic-auth-secret', {}) +
    secret.withType('kubernetes.io/basic-auth') +
    secret.withStringData({
      username: $._config.mad.madmin.username,
      password: $._config.mad.madmin.password,
    }) +
    secret.mixin.metadata.withNamespace($._config.namespace),

  madmin_traefik_basic_auth_middleware:
    {
      apiVersion: 'traefik.containo.us/v1alpha1',
      kind: 'Middleware',
      metadata: {
        name: 'madmin-basic-auth-mw',
        labels: {
          traefikzone: 'public',
        },
      },
      spec: {
        basicAuth: { secret: 'madmin-basic-auth-secret' },
      },
    },

  core_service:
    service.new('mad-core', { madcore: 'core' }, [
      { name: 'mad-core', port: 5000 },
      { name: 'mapping-manager', port: 50052 },
      { name: 'stats-handler', port: 50053 },
    ]) +
    service.spec.withType('ClusterIP') +
    service.metadata.withNamespace($._config.namespace),

  mitmrecv_service:
    service.new('mad-mitmrecv', { madmitmrecv: 'mitmrecv' }, [{ name: 'mitm-receiever', port: 8000 }]) +
    service.spec.withType('ClusterIP') +
    service.metadata.withNamespace($._config.namespace),

  rgc_service:
    service.new('mad-rgc', { madrgc: 'rgc' }, [{ name: 'rgc', port: 8080 }]) +
    service.spec.withType('ClusterIP') +
    service.metadata.withNamespace($._config.namespace),


  // TODO: Add the auth middleware.. Somehow..
  madminingress:
    tIngress.new('mad-core') +
    tIngress.metadata.withNamespace($._config.namespace) +
    tIngress.metadata.withLabelsMixin({
      traefikzone: 'public',
    }) +
    tIngress.spec.withEntryPoints(['web']) +
    tIngress.spec.withRoutes([
      tIngress.spec.routes.withKind('Rule') +
      tIngress.spec.routes.withMatch('Host(`async-madmin.lsmpogo.com`)') +
      tIngress.spec.routes.withMiddlewares(
        tIngress.spec.routes.middlewares.withName('redirect-websecure') +
        tIngress.spec.routes.middlewares.withNamespace('traefik'),
      ) +
      tIngress.spec.routes.withServices(
        tIngress.spec.routes.services.withName('mad-core') +
        tIngress.spec.routes.services.withPort(5000),
      ),
    ]),

  madminingresstls:
    tIngress.new('mad-core-tls') +
    tIngress.metadata.withNamespace($._config.namespace) +
    tIngress.metadata.withLabelsMixin({
      traefikzone: 'public',
    }) +
    tIngress.spec.withEntryPoints(['websecure']) +
    tIngress.spec.withRoutes([
      tIngress.spec.routes.withKind('Rule') +
      tIngress.spec.routes.withMatch('Host(`async-madmin.lsmpogo.com`)') +
      tIngress.spec.routes.withMiddlewares(
        tIngress.spec.routes.middlewares.withName('madmin-basic-auth-mw') +
        tIngress.spec.routes.middlewares.withNamespace($._config.namespace),
      ) +
      tIngress.spec.routes.withServices(
        tIngress.spec.routes.services.withName('mad-core') +
        tIngress.spec.routes.services.withPort(5000),
      ),
    ]) +
    tIngress.spec.tls.withCertResolver('mydnschallenge'),
  // madminingress:
  //   traefikingress.newIngressRoute('mad-core', $._config.namespace, 'async-madmin.lsmpogo.com', 'mad-core', 5000, true),

  mitmrecvingress:
    traefikingress.newIngressRoute('mitmrecv', $._config.namespace, 'async-pd.lsmpogo.com', 'mad-mitmrecv', 8000, true),

  rgcingress:
    traefikingress.newIngressRoute('mad-rgc', $._config.namespace, 'async-rgc.lsmpogo.com', 'mad-rgc', 8080, true),
}
