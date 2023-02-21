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

local prom = import '0.57/main.libsonnet';
local sm = prom.monitoring.v1.serviceMonitor;

{
  primary_pv:
    pv.new('mysqlprimary-pv%s' % $._config.hahostpath.suffix) +
    pv.spec.withAccessModes('ReadWriteOnce') +
    pv.spec.withCapacity({ storage: '100Gi' }) +
    pv.spec.withStorageClassName('manual') +
    pv.spec.hostPath.withPath('/opt/kubehostpaths/mysql-primary%s' % $._config.hahostpath.suffix),

  secondary_pv:
    pv.new('mysqlsecondary-pv%s' % $._config.hahostpath.suffix) +
    pv.spec.withAccessModes('ReadWriteOnce') +
    pv.spec.withCapacity({ storage: '101Gi' }) +
    pv.spec.withStorageClassName('manual') +
    pv.spec.hostPath.withPath('/opt/kubehostpaths/mysql-replica%s' % $._config.hahostpath.suffix) +
    pv.metadata.withLabels({ reservation: 'mysqlsecondary%s' % $._config.hahostpath.suffix }),

  primary_pvc:
    pvc.new('mysqlprimary-pvc%s' % $._config.hahostpath.suffix) +
    pvc.spec.withAccessModes('ReadWriteOnce') +
    pvc.spec.withStorageClassName('manual') +
    pvc.spec.withVolumeName('mysqlprimary-pv%s' % $._config.hahostpath.suffix) +
    pvc.spec.resources.withRequests({ storage: '100Gi' }) +
    pvc.mixin.metadata.withNamespace($._config.namespace),

  mysql_secret:
    secret.new('mysql%s' % $._config.hahostpath.suffix, {}) +
    secret.withStringData({
      'mysql-root-password': $._config.hahostpath.root_password,
      'mysql-replication-password': $._config.hahostpath.replication_password,
      'mysql-password': $._config.hahostpath.password,
    }) +
    secret.mixin.metadata.withNamespace($._config.namespace),

  mysql_bkup_secret: $.mysql_secret + secret.mixin.metadata.withNamespace('default'),

  mysql: helm.template('mysql%s' % $._config.hahostpath.suffix, '../../charts/mysql', {
    namespace: $._config.namespace,
    values: {
      architecture: 'replication',
      auth: {
        existingSecret: 'mysql%s' % $._config.hahostpath.suffix,
      },
      primary: {
        nodeSelector: {
          'kubernetes.io/hostname': $._config.hahostpath.primaryHost,
        },
        persistence: {
          existingClaim: 'mysqlprimary-pvc%s' % $._config.hahostpath.suffix,
        },
        extraFlags: '--sql-mode=NO_ENGINE_SUBSTITUTION --binlog-expire-logs-seconds=172800 --max-connections=300',
        extraEnvVars: [
          { name: 'TZ', value: 'America/Los_Angeles' },
        ],
      },
      secondary: {
        nodeSelector: {
          'kubernetes.io/hostname': $._config.hahostpath.replicaHost,
        },
        persistence: {
          // For some reason, the chart does not support 'existingClaim', but does allow a selector for an existing pv ¯\_(ツ)_/¯
          storageClass: 'manual',
          size: '101Gi',
          selector: {
            matchLabels: { reservation: 'mysqlsecondary%s' % $._config.hahostpath.suffix },
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
      k.core.v1.envVar.new('SQLINSTANCENAME', $._config.hahostpath.backup_instance_name),
      k.core.v1.envVar.fromSecretRef('SQLPASS', 'mysql', 'mysql-root-password'),
      k.core.v1.envVar.new('SQLHOST', 'mysql%s-secondary.%s.svc.cluster.local' % [$._config.hahostpath.suffix, $._config.namespace]),
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
    cronJob.new('mysqlhabkup%s' % $._config.hahostpath.suffix, '30 1 * * *', $.mysqlbak_container) +
    cronJob.mixin.metadata.withNamespace('default') +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withRestartPolicy('Never') +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withVolumesMixin([
      k.core.v1.volume.fromConfigMap('scripts', 'backup-scripts'),
      k.core.v1.volume.fromPersistentVolumeClaim('backup', 'backups-pvc'),
    ]),

  serviceMonitor:
    sm.new('mysql%s' % $._config.hahostpath.suffix) +
    sm.metadata.withLabels({instance: 'primary-me'}) +
    sm.spec.selector.withMatchLabels({
      'app.kubernetes.io/component': 'metrics',
      'app.kubernetes.io/instance': 'mysql%s' % $._config.hahostpath.suffix,      
      'app.kubernetes.io/name': 'mysql',
    }) +
    sm.spec.namespaceSelector.withMatchNames([$._config.namespace]) +
    sm.spec.withEndpoints([
      sm.spec.endpoints.withHonorLabels(true) +
      sm.spec.endpoints.withPort('metrics'),
    ]),
}
