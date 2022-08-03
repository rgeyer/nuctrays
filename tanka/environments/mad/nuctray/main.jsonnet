local namefetcher = import 'madnamefetcher/madnamefetcher.libsonnet';
local redis = import 'redis/main.libsonnet';
local secrets = import 'secrets.libsonnet';
local k = import 'ksonnet-util/kausal.libsonnet';

local clusterRole = k.rbac.v1.clusterRole,
      container = k.core.v1.container,
      configMap = k.core.v1.configMap,
      cronJob = k.batch.v1beta1.cronJob,
      policyRule = k.rbac.v1.policyRule,
      clusterRoleBinding = k.rbac.v1.clusterRoleBinding,
      serviceAccount = k.core.v1.serviceAccount;

secrets {
  _images+:: {
    namefetcher: 'registry.ryangeyer.com/namefetcher:upstream',
    redis: 'redis:latest',
    maddog: 'bitnami/kubectl:1.24',
    mysql: 'mysql:5.7',
  },

  _config+:: {
    namespace: 'mad',
    namefetcher+:: {
      dbhost: 'mysql-primary.mysql.svc.cluster.local',
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
  redis: redis + config_mixin,

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
      k.core.v1.envVar.new('SQLHOST', 'mysql-primary.mysql.svc.cluster.local'),
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
