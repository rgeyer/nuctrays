
local tanka = import "github.com/grafana/jsonnet-libs/tanka-util/main.libsonnet";
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
    pv.spec.withCapacity({'storage': '100Gi'}) +
    pv.spec.withStorageClassName('manual') +
    pv.spec.hostPath.withPath('/opt/kubehostpaths/mysql-primary'),

  secondary_pv:
    pv.new('mysqlsecondary-pv') +
    pv.spec.withAccessModes('ReadWriteOnce') +
    pv.spec.withCapacity({'storage': '1Gi'}) +
    pv.spec.withStorageClassName('nfs-storage') +
    pv.spec.withMountOptions([
      'hard',
      'nfsvers=4.1',
    ]) +
    pv.spec.nfs.withPath($._config.mysql.secondary.pvc.nfsPath) +
    pv.spec.nfs.withServer($._config.mysql.secondary.pvc.nfsHost) +
    pv.metadata.withLabels({ reservation: 'mysqlsecondary' }),

  primary_pvc:
    pvc.new('mysqlprimary-pvc') +
    pvc.spec.withAccessModes('ReadWriteOnce') +
    pvc.spec.withStorageClassName('manual') +
    pvc.spec.withVolumeName('mysqlprimary-pv') +
    pvc.spec.resources.withRequests({'storage': '100Gi'}) +
    pvc.mixin.metadata.withNamespace(ns),

  mysql_secret:
    secret.new('mysql', {}) +
    secret.withStringData({
      'mysql-root-password': $._config.mysql.root_password,
      'mysql-replication-password': $._config.mysql.replication_password,
      'mysql-password': $._config.mysql.password,
    }) +
    secret.mixin.metadata.withNamespace(ns),

  // MAD requires sql_mode="NO_ENGINE_SUBSTITUTION" in the mysql.cnf. I don't see an easy way to add decorations to the configmap, so I added this manually.
  // Need to eventually "properly" automate that.
  // Looks like it can be set as a CLI arg, which is exposed as [primary|secondary].extraFlags - https://dev.mysql.com/doc/refman/8.0/en/sql-mode.html,
  mysql: helm.template("mysql", "../../charts/mysql", {
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
      },
      secondary: {
        persistence: {
          // For some reason, the chart does not support 'existingClaim', but does allow a selector for an existing pv ¯\_(ツ)_/¯
          storageClass: 'nfs-storage',
          size: '1Gi',
          selector: {
            matchLabels: { reservation: 'mysqlsecondary' },
          },
        },        
      },
    }
  })
}

