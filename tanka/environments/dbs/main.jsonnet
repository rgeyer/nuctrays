local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local mysql = import 'mysql/mysql.libsonnet';
local secrets = import 'secrets.libsonnet';

local container = k.core.v1.container,
      configMap = k.core.v1.configMap,
      cronJob = k.batch.v1beta1.cronJob,
      secret = k.core.v1.secret;

secrets {
  _images+:: {
    mysql: 'mysql:5.7',
  },

  _config+:: {
    namespace: 'dbs',
  },

  local config_mixin = {
    _images+:: $._images,
    _config+:: $._config,
  },

  mysql: mysql + config_mixin,

  // The backup stuff goes here, rather than in the backups environment because the secrets and image are defined here.
  // This cronjob still goes in the default namespace, and uses the pvc created by the backups environment.
  // One day this should be cleaned up and combined.
  mysql_secret:
    secret.new('mysql', {}) +
    secret.withStringData({
      'MYSQL_ROOT_PASSWORD': $._config.mysql.root_password,
    }) +
    secret.mixin.metadata.withNamespace('default'),

  mysqlbak_container::
    container.new('mysqlbak', $._images.mysql) +
    container.withEnv([
      k.core.v1.envVar.fromSecretRef('SQLPASS', 'mysql', 'MYSQL_ROOT_PASSWORD'),
      k.core.v1.envVar.new('SQLHOST', 'mysql.dbs.svc.cluster.local'),
      k.core.v1.envVar.new('SQLUSER', 'root'),
      k.core.v1.envVar.new('BACKUPROOT', '/backup'),
    ]) +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('scripts', '/scripts'),
      k.core.v1.volumeMount.new('backup', '/backup'),
    ]) +
    container.withWorkingDir('/scripts') +
    container.withCommand(['bash', '/scripts/mysqlbak.sh']),

  mysqlbak:
    cronJob.new('mysqlbkup', '30 1 * * *', $.mysqlbak_container) +
    cronJob.mixin.metadata.withNamespace('default') +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withRestartPolicy('Never') +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withVolumesMixin([
      k.core.v1.volume.fromConfigMap('scripts', 'backup-scripts'),
      k.core.v1.volume.fromPersistentVolumeClaim('backup', 'backups-pvc'),
    ]),
}
