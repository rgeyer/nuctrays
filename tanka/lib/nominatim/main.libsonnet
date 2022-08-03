local k = import 'ksonnet-util/kausal.libsonnet';

local container = k.core.v1.container,
      containerPort = k.core.v1.containerPort,
      deployment = k.apps.v1.deployment,
      secret = k.core.v1.secret,
      service = k.core.v1.service;

local traefikingress = import 'traefik/ingress.libsonnet';

{
  secret:
    secret.new('nominatim-psql', {}) +
    secret.withStringData({
      username: $._config.mad.psql_nominatim.username,
      password: $._config.mad.psql_nominatim.password,
    })+
    secret.mixin.metadata.withNamespace($._config.namespace),

  container::
    container.new('nominatim', $._images.nominatim) +
    container.withEnv([
      k.core.v1.envVar.fromSecretRef('PSQLUSER', 'nominatim-psql', 'username'),
      k.core.v1.envVar.fromSecretRef('PSQLPASS', 'nominatim-psql', 'password'),
    ]) +
    container.withPorts([
      containerPort.new('nominatim', 8080),
    ]) +
    container.withCommand(['bash', '-c']) +
    container.withArgs([|||
      #!/usr/bin/env bash

      mkdir -p /data

      cat << EOF > /data/local.php
      <?php
        // Paths
        @define('CONST_Postgresql_Version', '12');
        @define('CONST_Postgis_Version', '3');
        // Website settings
        @define('CONST_Website_BaseURL', '/');
        @define('CONST_Replication_Url', 'http://download.geofabrik.de/north-america/us/california-updates');
        @define('CONST_Replication_MaxInterval', '86400');     // Process each update separately, osmosis cannot merge multiple updates
        @define('CONST_Replication_Update_Interval', '86400');  // How often upstream publishes diffs
        @define('CONST_Replication_Recheck_Interval', '900');   // How long to sleep if no update found yet
        @define('CONST_Pyosmium_Binary', '/usr/local/bin/pyosmium-get-changes');
        @define('CONST_Database_DSN', 'pgsql:host=postgis;port=5432;user=${PSQLUSER};password=${PSQLPASS};dbname=nominatim'); //<driver>:host=<host>;port=<port>;user=<username>;password=<password>;dbname=<database>
      EOF

      sh /app/startapache.sh;
    |||]),
  
  deployment:
    deployment.new('nominatim', 1, $.container) +
    deployment.mixin.metadata.withNamespace($._config.namespace),

  service:
    k.util.serviceFor($.deployment) +
    service.mixin.metadata.withNamespace($._config.namespace),

  ingress: traefikingress.newIngressRoute('nominatim', $._config.namespace, 'nominatim.ryangeyer.com', 'nominatim', 8080),
}