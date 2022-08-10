local config = import 'config.libsonnet';
local secrets = import 'secrets.libsonnet';
local k = import 'ksonnet-util/kausal.libsonnet';

local clusterRole = k.rbac.v1.clusterRole,
      clusterRoleBinding = k.rbac.v1.clusterRoleBinding,
      container = k.core.v1.container,
      configMap = k.core.v1.configMap,
      cronJob = k.batch.v1beta1.cronJob,
      policyRule = k.rbac.v1.policyRule,
      secret = k.core.v1.secret,
      serviceAccount = k.core.v1.serviceAccount;

local namefetcher = import 'madnamefetcher/madnamefetcher.libsonnet';
local redis = import 'redis/main.libsonnet';
local postgis = import 'postgis/main.libsonnet';
local nominatim = import 'nominatim/main.libsonnet';
local poracle = import 'poracle/main.libsonnet';
local rocketmad = import 'rocketmad/main.libsonnet';
local madbe = import 'madbe/main.libsonnet';
local madsql = import 'mysql/hahostpath.libsonnet';

config + secrets {
  _images+:: {
    namefetcher: 'registry.ryangeyer.com/namefetcher:upstream',
    redis: 'redis:latest',
    maddog: 'bitnami/kubectl:1.24',
    mysql: 'mysql:5.7',
    postgis: 'postgis/postgis:12-3.0',
    nominatim: 'registry.ryangeyer.com/nominatim:3.5', // TODO: No idea where this image came from. Probably need to find, and store the dockerfile
    poracle: 'ghcr.io/kartuludus/poraclejs:master',
    rocketmap: 'ghcr.io/cecpk/rocketmad:master',
    git: 'alpine/git',
    madbe: 'ghcr.io/map-a-droid/mad:master',
    busybox: 'registry.ryangeyer.com/busybox:latest',
  },

  _config+:: {
    local this = self,
    namespace: 'mad',
    namefetcher+:: {
      dbhost: 'mysql-mad-primary.mad.svc.cluster.local',
      dbname: 'madpoc',
    },

    // TODO: This should probably move to the top level config
    madmysql+:: {
      secretname: 'mysql-secret',
      secretuserkey: 'username',
      secretpasskey: 'password',
    },

    rocketmap+:: {
      dbhost: 'mysql-mad-primary.mad.svc.cluster.local',
      dbname: 'madpoc',
    },

    hahostpath+:: {
      suffix: '-mad',
      backup_instance_name: 'mad',
      root_password: this.mysql.root_password,
      replication_password: this.mysql.replication_password,
      password: this.mysql.password,
      primaryHost: 'mad-hx90',
      replicaHost: 'thinkcentre1',
    },
  },

  local config_mixin = {
    _images+:: $._images,
    _config+:: $._config,
  },

  namefetcher: namefetcher + config_mixin,
  redis: redis + config_mixin,
  postgis: postgis + config_mixin,
  nominatim: nominatim + config_mixin,
  poracle: poracle + config_mixin,
  rocketmad: rocketmad + config_mixin,
  madbe: madbe + config_mixin,
  madsql: madsql + config_mixin,

  maddb_secret:
    secret.new('mysql-secret', {}) +
    secret.withStringData({
      username: $._config.mad.mysql_mad.username,
      password: $._config.mad.mysql_mad.password,
    }) +
    secret.mixin.metadata.withNamespace($._config.namespace),

  poracledb_secret:
    secret.new('poracle-secret', {}) +
    secret.withStringData({
      username: $._config.mad.mysql_poracle.username,
      password: $._config.mad.mysql_poracle.password,
      token: $._config.mad.discord_poracle.token,
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

  # Janky stuff to restart MADBE nightly, probably just before, or after quest scanning. This is to stem the tide of MAD memory leaks.
  maddog_service_account:
    serviceAccount.new('maddog') +
    serviceAccount.metadata.withNamespace($._config.namespace),

  maddog_clusterrole:
    clusterRole.new('maddog-clusterrole') +
    clusterRole.withRulesMixin([
      policyRule.withApiGroups(['apps', 'extensions'],) +
      policyRule.withResources([
        'deployments',
      ]) +
      policyRule.withVerbs([
        'get',
        'patch',
      ]),
    ]),

  maddog_clusterrole_binding:
    clusterRoleBinding.new('maddog-clusterrole-binding') +
    clusterRoleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
    clusterRoleBinding.mixin.roleRef.withKind('ClusterRole') +
    clusterRoleBinding.mixin.roleRef.withName($.maddog_clusterrole.metadata.name) +
    clusterRoleBinding.metadata.withNamespace($._config.namespace) +
    clusterRoleBinding.withSubjectsMixin({
      kind: 'ServiceAccount',
      name: $.maddog_service_account.metadata.name,
      namespace: $._config.namespace,
    }),

  maddog_container::
    container.new('maddog', $._images.maddog) +
    container.withArgsMixin([
      'rollout',
      'restart',
      'deployment',
      'madbe',
      '-n',
      'mad',
    ]),

  # Every day at 6:55am UTC, or 11:55pm PST, ten minutes before quest scanning.
  maddog_cron:
    cronJob.new('maddog', '55 6 * * *', $.maddog_container) +
    cronJob.mixin.metadata.withNamespace($._config.namespace) +
    cronJob.spec.jobTemplate.spec.template.metadata.withLabels({name: 'maddog'}) +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withRestartPolicy('Never') +
    cronJob.spec.jobTemplate.spec.template.spec.withServiceAccountName($.maddog_service_account.metadata.name),

  dbmaintcm:
    configMap.new('dbmaintscripts') +
    configMap.mixin.metadata.withNamespace($._config.namespace) +
    configMap.withData({
      'truncate.sql': |||
        TRUNCATE TABLE pokemon;
        TRUNCATE TABLE trs_stats_detect_seen_type;
        TRUNCATE TABLE trs_stats_detect_mon_raw;
      |||,
    }),

  dbmaint_container::
    container.new('dbmaint', $._images.mysql) +
    container.withEnv([
      k.core.v1.envVar.fromSecretRef('SQLPASS', $._config.madmysql.secretname, $._config.madmysql.secretpasskey),
      k.core.v1.envVar.new('SQLHOST', 'mysql-mad-primary.mad.svc.cluster.local'),
      k.core.v1.envVar.fromSecretRef('SQLUSER', $._config.madmysql.secretname, $._config.madmysql.secretuserkey),
      k.core.v1.envVar.new('SQLDBNAME', 'madpoc'),
    ]) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('scripts', '/scripts'),
    ]) +
    container.withWorkingDir('/scripts') +
    container.withCommand(['bash', '-c']) +
    container.withArgs([|||
      #!/usr/bin/env bash

      cat << EOF > /etc/my.cnf
      [client]
      password=${SQLPASS}
      EOF

      mysql "-u${SQLUSER}" "-h${SQLHOST}" "${SQLDBNAME}" < /scripts/truncate.sql;
    |||]),

  # Every day at 10:05 UTC, or 3:05 PST, five minutes after quest scanning
  dbmaint_cron:
    cronJob.new('dbmaint', '05 10 * * *', $.dbmaint_container) +
    cronJob.mixin.metadata.withNamespace($._config.namespace) +
    cronJob.spec.jobTemplate.spec.template.metadata.withLabels({name: 'dbmaint'}) +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withRestartPolicy('Never') +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withVolumesMixin([
      k.core.v1.volume.fromConfigMap('scripts', 'dbmaintscripts'),
    ]),
}
