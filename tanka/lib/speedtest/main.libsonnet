local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local container = k.core.v1.container,
      containerPort = k.core.v1.containerPort;

{
  newContainer(image='jraviles/prometheus_speedtest:latest'):: {
    container::
      container.new('speedtest', image) +
      container.withPorts([
        containerPort.new('http', 9516),
      ]),
  },
}