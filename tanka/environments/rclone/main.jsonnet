local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local config = import 'config.libsonnet';
local nfspvc = import 'k8sutils/nfspvc.libsonnet';
local secrets = import 'secrets.libsonnet';

local container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      volume = k.core.v1.volume,
      volumeMount = k.core.v1.volumeMount,
      statefulSet = k.apps.v1.statefulSet,
      service = k.core.v1.service,
      cronJob = k.batch.v1beta1.cronJob;

local traefikingress = import 'traefik/ingress.libsonnet';

local namespace = 'rclone';

config + secrets {
  bkup_job(name, src, dest, schedule):: {
    container::
      container.new('rclone', $._config.rclone.image) +
      container.withArgsMixin([
        'sync',
        '--rc',
        '--rc-enable-metrics',
        '--rc-no-auth',
        '--rc-addr',
        ':5572',
        src,
        dest,
      ]) +
      container.withPorts([
        containerPort.new('http-metrics', 5572),
      ]) +
      container.withVolumeMountsMixin([
        volumeMount.new('rcloneconf', '/config/rclone'),
        volumeMount.new('rclone-bignasty', '/data'),
      ]),

    cron:
      cronJob.new(name, schedule, self.container) +
      cronJob.mixin.metadata.withNamespace(namespace) +
      cronJob.spec.jobTemplate.spec.template.metadata.withLabels({ name: name }) +
      cronJob.mixin.spec.jobTemplate.spec.template.spec.withRestartPolicy('Never') +
      cronJob.mixin.spec.jobTemplate.spec.template.spec.withVolumesMixin([
        volume.fromPersistentVolumeClaim('rcloneconf', 'rcloneconf-pvc'),
        volume.fromPersistentVolumeClaim('rclone-bignasty', 'rclone-bignasty-pvc'),
      ]),
  },

  _config+:: {
    rclone+:: {
      image: 'rclone/rclone:1.57',
      pvc: {
        nfsHost: '192.168.42.101',
        nfsPath: '/mnt/brick/nfs/rcloneconf',
      },
    },
  },
  namespace: k.core.v1.namespace.new(namespace),

  container::
    container.new('rclone', $._config.rclone.image) +
    container.withArgsMixin([
      'rcd',
      '--rc-enable-metrics',
      '--rc-no-auth',
      '--rc-addr',
      ':5572',
    ]) +
    container.withPorts([
      containerPort.new('http-metrics', 5572),
    ]) +
    container.withVolumeMountsMixin([
      volumeMount.new('rcloneconf', '/config/rclone'),
      volumeMount.new('rclone-bignasty', '/data'),
    ]),

  statefulset:
    statefulSet.new('rclone', 1, $.container, podLabels={ name: 'rclone' }) +
    statefulSet.spec.withServiceName('rclone') +
    statefulSet.mixin.metadata.withNamespace(namespace) +
    statefulSet.mixin.spec.template.spec.withVolumesMixin([
      volume.fromPersistentVolumeClaim('rcloneconf', 'rcloneconf-pvc'),
      volume.fromPersistentVolumeClaim('rclone-bignasty', 'rclone-bignasty-pvc'),
    ]),

  rcloneconfpvc: nfspvc.new(
    namespace,
    $._config.rclone.pvc.nfsHost,
    $._config.rclone.pvc.nfsPath,
    'rcloneconf'
  ),

  datapvc: nfspvc.new(
    namespace,
    '192.168.42.10',
    '/',
    'rclone-bignasty',
  ),

  service:
    k.util.serviceFor($.statefulset) +
    service.mixin.metadata.withNamespace(namespace),

  # Note: This covers only the nuctray backups directory, which is the only one which changes regularly.
  # May want to add a monthly or weekly that checks the whole backups dir.
  bkupbkup: $.bkup_job('bignasty-backups-nuctray', 'Backups/nuctray', 'gsuite-drive:/BigNASty/Backups/nuctray', $._config.cronjobs.rclone['bignasty-backups-nuctray']),
  codebkup: $.bkup_job('bignasty-code', 'Code', 'gsuite-drive:/BigNASty/Code', $._config.cronjobs.rclone['bignasty-code']),
  downloadbkup: $.bkup_job('bignasty-download', 'Download', 'gsuite-drive:/BigNASty/Code', $._config.cronjobs.rclone['bignasty-download']),
  homesbkup: $.bkup_job('bignasty-homes', 'homes', 'gsuite-drive:/BigNASty/homes', $._config.cronjobs.rclone['bignasty-homes']),
  // kubestorebkup: $.bkup_job('bignasty-kubestore', 'kubestore', 'gsuite-drive:/BigNASty/kubestore', $._config.cronjobs.rclone['bignasty-kubestore']),
  multimediabkup: $.bkup_job('bignasty-multimedia', 'Multimedia', 'gsuite-drive:/BigNASty/Multimedia', $._config.cronjobs.rclone['bignasty-multimedia']),
  publicbkup: $.bkup_job('bignasty-public', 'Public', 'gsuite-drive:/BigNASty/Public', $._config.cronjobs.rclone['bignasty-public']),

  ingress: traefikingress.newIngressRoute(
    'rclone', 
    namespace, 
    'rclone.ryangeyer.com', 
    'rclone', 
    '5572', 
    false, 
    true),
}
