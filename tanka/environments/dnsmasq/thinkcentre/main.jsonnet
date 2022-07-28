local dnsmasq = (import 'dnsmasq/main.libsonnet');

{
  dnsmasq: dnsmasq.new('strm/dnsmasq:latest', 'sharedsvc', '10.43.0.2', '10.43.0.3'),
}
