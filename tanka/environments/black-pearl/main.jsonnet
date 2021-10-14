local blackpearl = import 'blackpearl/blackpearl.libsonnet';
local secrets = import 'secrets.libsonnet';

secrets {
  blackpearl: blackpearl.new('plex', $._config.blackpearl.ovpn_uname, $._config.blackpearl.ovpn_pass)
}
