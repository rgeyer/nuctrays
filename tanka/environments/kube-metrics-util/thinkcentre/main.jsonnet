local k = import 'ksonnet-util/kausal.libsonnet';

local nfspvc = import 'k8sutils/nfspvc.libsonnet',      
      container = k.core.v1.container,
      cronJob = k.batch.v1beta1.cronJob;

{
  pvc: nfspvc.new(
    'grafana-agent',
    '192.168.42.10',
    '/kubestore/scratchpad',
    'scratchpad',
  ),

  container::
    container.new('scrape', 'alpine/curl') +
    container.withVolumeMountsMixin([
      k.core.v1.volumeMount.new('scratchpad', '/scratchpad'),
    ]) +
    container.withWorkingDir('/scratchpad') +
    container.withCommand(['sh', '-c', |||
      curl -k -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" https://192.168.42.200:10250/metrics > /scratchpad/scrape
      curl -k -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" https://192.168.42.200:10250/metrics/cadvisor >> /scratchpad/scrape
      curl -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" http://kube-state-metrics.kube-system.svc.cluster.local:8080/metrics >> /scratchpad/scrape
    |||],),

  cronjob:
    cronJob.new('k8s-scrape', '0 0 1 1 *', $.container) +
    cronJob.mixin.metadata.withNamespace('grafana-agent') +
    cronJob.spec.jobTemplate.spec.template.metadata.withLabels({name: 'k8s-scrape'}) +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withRestartPolicy('Never') +
    cronJob.spec.jobTemplate.spec.template.spec.withServiceAccountName('grao-agent') +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withVolumesMixin([
      k.core.v1.volume.fromPersistentVolumeClaim('scratchpad', 'scratchpad-pvc'),
    ]),
}
