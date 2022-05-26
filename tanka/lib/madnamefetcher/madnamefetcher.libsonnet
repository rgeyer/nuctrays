local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local config = import 'config.libsonnet';

local container = k.core.v1.container,
      cronJob = k.batch.v1beta1.cronJob,
      envVar = k.core.v1.envVar,
      envFrom = k.core.v1.envFromSource,
      secret = k.core.v1.secret;

config {
  namefetcher_container::
    container.new('namefetcher', $._images.namefetcher) +
    container.withEnvFrom(envFrom.secretRef.withName('namefetcher')) +
    container.withEnv([
      envVar.new('NF_DB_HOST', $._config.namefetcher.dbhost),
      envVar.new('NF_DB_DATABASE', $._config.namefetcher.dbname),
      envVar.fromSecretRef('NF_DB_USER', $._config.madmysql.secretname, $._config.madmysql.secretuserkey),
      envVar.fromSecretRef('NF_DB_PASSWORD', $._config.madmysql.secretname, $._config.madmysql.secretpasskey),
    ]),

  namefetcher_cronjob:
    cronJob.new('namefetcher', '0 0 * * FRI', $.namefetcher_container) +
    cronJob.mixin.metadata.withNamespace($._config.namespace) +
    cronJob.mixin.spec.jobTemplate.spec.template.spec.withRestartPolicy('Never'),

  namefetcher_secret:
    secret.new('namefetcher', {}) +
    secret.withStringData({
      'NF_TOKEN': $._config.namefetcher.api_token,
      'NF_URL': $._config.namefetcher.uri,
    }) +
    secret.mixin.metadata.withNamespace($._config.namespace),
}
