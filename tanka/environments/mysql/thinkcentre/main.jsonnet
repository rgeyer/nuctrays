local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local config = import 'config.libsonnet';
local secrets = import 'secrets.libsonnet';

local container = k.core.v1.container,
      cronJob = k.batch.v1beta1.cronJob,
      pv = k.core.v1.persistentVolume,
      pvc = k.core.v1.persistentVolumeClaim,
      secret = k.core.v1.secret;

local ns = 'sharedsvc';

config + secrets + {
  _images+:: {
    mysql: 'mysql:5.7',
  },

  namespace: k.core.v1.namespace.new(ns),

  primary_pv:
    pv.new('mysqlprimary-pv') +
    pv.spec.withAccessModes('ReadWriteOnce') +
    pv.spec.withCapacity({ storage: '100Gi' }) +
    pv.spec.withStorageClassName('manual') +
    pv.spec.hostPath.withPath('/opt/kubehostpaths/mysql-primary'),

  secondary_pv:
    pv.new('mysqlsecondary-pv') +
    pv.spec.withAccessModes('ReadWriteOnce') +
    pv.spec.withCapacity({ storage: '101Gi' }) +
    pv.spec.withStorageClassName('manual') +
    pv.spec.hostPath.withPath('/opt/kubehostpaths/mysql-replica') +
    pv.metadata.withLabels({ reservation: 'mysqlsecondary' }),

  primary_pvc:
    pvc.new('mysqlprimary-pvc') +
    pvc.spec.withAccessModes('ReadWriteOnce') +
    pvc.spec.withStorageClassName('manual') +
    pvc.spec.withVolumeName('mysqlprimary-pv') +
    pvc.spec.resources.withRequests({ storage: '100Gi' }) +
    pvc.mixin.metadata.withNamespace(ns),

  mysql_secret:
    secret.new('mysql', {}) +
    secret.withStringData({
      'mysql-root-password': $._config.mysql.root_password,
      'mysql-replication-password': $._config.mysql.replication_password,
      'mysql-password': $._config.mysql.password,
    }) +
    secret.mixin.metadata.withNamespace(ns),

  mysql: helm.template('mysql', '../../../charts/mysql', {
    namespace: ns,
    values: {
      architecture: 'replication',
      auth: {
        existingSecret: 'mysql',
      },
      primary: {
        nodeSelector: {
          'kubernetes.io/hostname': 'thinkcentre1',
        },
        persistence: {
          existingClaim: 'mysqlprimary-pvc',
        },
        extraFlags: '--sql-mode=NO_ENGINE_SUBSTITUTION --binlog-expire-logs-seconds=172800',
        extraEnvVars: [
          { name: 'TZ', value: 'America/Los_Angeles' },
        ],
      },
      secondary: {
        nodeSelector: {
          'kubernetes.io/hostname': 'thinkcentre2',
        },
        persistence: {
          // For some reason, the chart does not support 'existingClaim', but does allow a selector for an existing pv ¯\_(ツ)_/¯
          storageClass: 'manual',
          size: '101Gi',
          selector: {
            matchLabels: { reservation: 'mysqlsecondary' },
          },
        },
        extraFlags: '--binlog-expire-logs-seconds=172800',
        extraEnvVars: [
          { name: 'TZ', value: 'America/Los_Angeles' },
        ],
      },
      metrics: {
        enabled: true,
      },
    },
  }),

  mysqlbak_container::
    container.new('mysqlbak', $._images.mysql) +
    container.withEnv([
      k.core.v1.envVar.fromSecretRef('SQLPASS', 'mysql', 'MYSQL_ROOT_PASSWORD'),
      k.core.v1.envVar.new('SQLHOST', 'mysql-secondary.sharedsvc.svc.cluster.local'),
      k.core.v1.envVar.new('SQLUSER', 'root'),
      k.core.v1.envVar.new('BACKUPROOT', '/backup'),
    ]) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('scripts', '/scripts'),
      k.core.v1.volumeMount.new('backup', '/backup'),
    ]) +
    container.withWorkingDir('/scripts') +
    container.withCommand(['bash', '/scripts/mysqlreplicabak.sh']),

  mysqlbak:
    cronJob.new('mysqlhabkup', '30 1 * * *', $.mysqlbak_container) +
    cronJob.mixin.metadata.withNamespace('default') +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withRestartPolicy('Never') +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withVolumesMixin([
      k.core.v1.volume.fromConfigMap('scripts', 'backup-scripts'),
      k.core.v1.volume.fromPersistentVolumeClaim('backup', 'backups-pvc'),
    ]),
}
