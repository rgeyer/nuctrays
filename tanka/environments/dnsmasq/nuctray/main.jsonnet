local dnsmasq = (import 'dnsmasq/main.libsonnet');

{
  dnsmasq: dnsmasq.new('strm/dnsmasq:latest', 'pihole', '10.42.0.2', '10.42.0.3'),
}
