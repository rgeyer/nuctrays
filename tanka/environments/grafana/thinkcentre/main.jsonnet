local grafana = import 'grafana/grafana.libsonnet';
local ds = import 'grafana/datasources.libsonnet';
local secrets = import 'secrets.libsonnet';

secrets {
  // DS
  // {"name":"InfluxDB-1","type":"influxdb","typeName":"InfluxDB","url":"http://influxdb.sharedsvc.svc.cluster.local:8086","jsonData":{"defaultBucket":"o11y","httpMode":"POST","organization":"primary","version":"Flux"},"readOnly":false}

  grafana: grafana
           + grafana.withAnonymous()
           + grafana.addDatasource(
            'influx',
            ds.new('influx','http://influxdb.sharedsvc.svc.cluster.local:8086','influxdb') +
            ds.withJsonData({defaultBucket: 'o11y', organization: 'primary', version: 'Flux'}) +
            ds.withSecureJsonData({token: $._config.influx.write_user_token})),
}
