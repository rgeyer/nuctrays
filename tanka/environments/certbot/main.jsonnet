local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local config = import 'config.libsonnet';
local secrets = import 'secrets.libsonnet';
local nfspvc = import 'k8sutils/nfspvc.libsonnet';

local container = k.core.v1.container,
      cronJob = k.batch.v1beta1.cronJob,
      envVar = k.core.v1.envVar,
      envFrom = k.core.v1.envFromSource,
      secret = k.core.v1.secret,
      volumeMount = k.core.v1.volumeMount;

local namespace = 'default';

config + secrets {
  certbot_pvc: nfspvc.new(
    namespace,
    $._config.certbot.pvc.nfsHost,
    $._config.certbot.pvc.nfsPath,
    'certbot'
  ),

  certbot_container::
    container.new('certbot', 'certbot/dns-route53') +
    container.withEnvFrom(envFrom.secretRef.withName('certbot')) +
    container.withArgsMixin([
      'certonly',
      '--dns-route53',
      '-n',
      '--agree-tos',
      '--email',
      'qwikrex@gmail.com',
      '-d',
      'mqtt.ryangeyer.com',
    ]) +
    container.withVolumeMountsMixin(
      volumeMount.new('certbot', '/etc/letsencrypt',)
    ),

  certbot_cronjob:
    cronJob.new('certbot', '0 0 * * *', $.certbot_container) +
    cronJob.mixin.metadata.withNamespace(namespace) +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withRestartPolicy('Never') +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withVolumesMixin([
      k.core.v1.volume.fromPersistentVolumeClaim('certbot', 'certbot-pvc'),
    ]),

  certbot_secret:
    secret.new('certbot', {}) +
    secret.withStringData({
      'AWS_ACCESS_KEY_ID': $._config.certbot.access_key_id,
      'AWS_SECRET_ACCESS_KEY': $._config.certbot.secret_access_key,
    }) +
    secret.mixin.metadata.withNamespace(namespace),
}
