local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local configMap = k.core.v1.configMap,
      container = k.core.v1.container,
      deployment = k.apps.v1.deployment,
      service = k.core.v1.service;

local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local traefikingress = import 'traefik/ingress.libsonnet';

{
  // The PVs for these should ultimately be host paths on the HX90 that is dedicated to lompoc MAD use. These are examples of how to do that.
  // primary_pv:
  //   pv.new('mysqlprimary-pv') +
  //   pv.spec.withAccessModes('ReadWriteOnce') +
  //   pv.spec.withCapacity({ storage: '100Gi' }) +
  //   pv.spec.withStorageClassName('manual') +
  //   pv.spec.hostPath.withPath('/opt/kubehostpaths/mysql-primary'),

  // primary_pvc:
  //   pvc.new('mysqlprimary-pvc') +
  //   pvc.spec.withAccessModes('ReadWriteOnce') +
  //   pvc.spec.withStorageClassName('manual') +
  //   pvc.spec.withVolumeName('mysqlprimary-pv') +
  //   pvc.spec.resources.withRequests({ storage: '100Gi' }) +
  //   pvc.mixin.metadata.withNamespace(ns),
  
  filepvc:
    nfspvc.new($._config.namespace, '192.168.42.10', '/kubestore/madbe/files', 'madbe-files'),

  logpvc:
    nfspvc.new($._config.namespace, '192.168.42.10', '/kubestore/madbe/logs', 'madbe-logs'),

  personalcommandpvc:
    nfspvc.new($._config.namespace, '192.168.42.10', '/kubestore/madbe/personal_commands', 'madbe-personal-commands'),

  apkpvc:
    nfspvc.new($._config.namespace, '192.168.42.10', '/kubestore/madbe/apks', 'madbe-apks'),
  
  pluginpvc:
    nfspvc.new($._config.namespace, '192.168.42.10', '/kubestore/madbe/plugins', 'madbe-plugins'),

  cm:
    configMap.new('madbecfg') +
    configMap.mixin.metadata.withNamespace($._config.namespace) +
    configMap.withData({
      'config.ini': |||
        db_poolsize: 2
        mitmreceiver_data_workers: 20        
        job_thread_count: 10
        weather

        # Game Stats
        ######################
        game_stats
        game_stats_raw

        # webhook
        ######################
        webhook
        webhook_url: http://poracle:3030
        webhook_submit_exraids
        quest_webhook_flavor: poracle

        # Dynamic Rarity
        ######################
        rarity_hours: 24

        # MADAPKs
        ######################
        token_dispenser: /usr/src/app/dyncfg/token-dispensers.ini

        # Redis caching
        ######################
        enable_cache
        cache_host: redis
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

        madmin_user: ${MADMINUSER}
        madmin_password: ${MADMINPASS}
        EOF

        # This is to allow access to the update_log outside of the pod/container in order for ATVDetails to read it.
        # This will get deprecated whenever I get around to implementing webhooks from the devices.
        ln -sf /usr/src/app/logs/update_log.json /usr/src/app/update_log.json
        cd /usr/src/app
        ls -alh /usr/src/app
        # We don't do this anymore because the requirements have diverged from the MAD requirements, and because ShinyWatcher is no longer supported.
        # pip3 install -r /usr/src/app/plugins/ShinyWatcher/requirements.txt
        python3 start.py ${@}
      |||,

      'token-dispensers.ini': |||
        http://auroraoss.in:8080
        http://auroraoss.com:8080
      |||,
    }),

  container::
    container.new('madbe', $._images.madbe) +
    container.withImagePullPolicy('Always') +
    container.withCommand(['/runscript/run.sh']) +
    container.withArgs([
      '--no_log_colors',
    ]) +
    container.withEnv([
      k.core.v1.envVar.new('TZ', 'America/Los_Angeles'),
      k.core.v1.envVar.fromSecretRef('SQLPASS', $._config.madmysql.secretname, $._config.madmysql.secretpasskey),
      k.core.v1.envVar.new('SQLHOST', 'mysql-mad-primary.mad.svc.cluster.local'),
      k.core.v1.envVar.fromSecretRef('SQLUSER', $._config.madmysql.secretname, $._config.madmysql.secretuserkey),
      k.core.v1.envVar.new('SQLDBNAME', 'madpoc'),
      k.core.v1.envVar.fromSecretRef('MADDEVAPITOKEN', 'madmin-secret', 'maddev-api-token'),
      k.core.v1.envVar.fromSecretRef('MADMINUSER', 'madmin-secret', 'madminuser'),
      k.core.v1.envVar.fromSecretRef('MADMINPASS', 'madmin-secret', 'madminpass'),
    ]) +
    container.withPorts([
      k.core.v1.containerPort.new('madmin', 5000),
      k.core.v1.containerPort.new('pd', 8000),
      k.core.v1.containerPort.new('rgc', 8080),
    ]) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('config', '/usr/src/app/dyncfg'),
      k.core.v1.volumeMount.new('runscript', '/runscript'),
      k.core.v1.volumeMount.new('files', '/usr/src/app/files'),
      k.core.v1.volumeMount.new('logs', '/usr/src/app/logs'),
      k.core.v1.volumeMount.new('personal-commands', '/usr/src/app/personal_commands'),
      k.core.v1.volumeMount.new('apks', '/usr/src/app/temp/mad_apk'),
      // Maybe at some point we dynamically fetch these from their origins?
      k.core.v1.volumeMount.new('plugins', '/usr/src/app/plugins'),
    ]) +
    container.resources.withRequests({memory: "8G"}) +
    container.resources.withLimits({memory: "16G"}),

  initContainer::
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

  deployment:
    deployment.new('madbe', 1, $.container) +
    deployment.spec.template.spec.withInitContainers($.initContainer) +
    deployment.spec.strategy.withType('Recreate') +
    deployment.mixin.metadata.withNamespace($._config.namespace) +
    deployment.mixin.spec.template.spec.withVolumesMixin([
      k.core.v1.volume.fromEmptyDir('runscript'),
      k.core.v1.volume.fromConfigMap('config', 'madbecfg'),
      k.core.v1.volume.fromPersistentVolumeClaim('files', 'madbe-files-pvc'),
      k.core.v1.volume.fromPersistentVolumeClaim('logs', 'madbe-logs-pvc'),
      k.core.v1.volume.fromPersistentVolumeClaim('personal-commands', 'madbe-personal-commands-pvc'),
      k.core.v1.volume.fromPersistentVolumeClaim('apks', 'madbe-apks-pvc'),
      k.core.v1.volume.fromPersistentVolumeClaim('plugins', 'madbe-plugins-pvc'),
    ]) +
    // Pin it to the HX90
    deployment.spec.template.spec.withNodeName('mad-hx90'),

  service:
    k.util.serviceFor($.deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),

  madminingress:
    traefikingress.newIngressRoute('madmin', $._config.namespace, 'madmin.lsmpogo.com','madbe', 5000, true),

  pdingress:
    traefikingress.newIngressRoute('pd', $._config.namespace, 'pd.lsmpogo.com', 'madbe', 8000, true),

  rgcingress:
    traefikingress.newIngressRoute('rgc', $._config.namespace, 'rgc.lsmpogo.com', 'madbe', 8080, true),
}