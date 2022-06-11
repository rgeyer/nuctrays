local tanka = import 'github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet';
local helm = tanka.helm.new(std.thisFile);

local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local config = import 'config.libsonnet';
local secrets = import 'secrets.libsonnet';

local pv = k.core.v1.persistentVolume,
      pvc = k.core.v1.persistentVolumeClaim,
      secret = k.core.v1.secret;

local ns = 'mysql';

config + secrets + {
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

  mysql: helm.template('mysql', '../../charts/mysql', {
    namespace: ns,
    values: {
      architecture: 'replication',
      auth: {
        existingSecret: 'mysql',
      },
      primary: {
        nodeSelector: {
          'kubernetes.io/hostname': '18mad1',
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
        // This is stupid, because it runs on the same box, but I don't have anything else with fast enough SSD to keep up.          
        nodeSelector: {
          'kubernetes.io/hostname': '18mad1',
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
}
