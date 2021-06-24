{
  _config+:: {
    namespace: error 'must specify namespace',
    domain: 'cluster.local',
    mysql+: {
      port: 3306,
      server_args: {},
      entrypoint_volume_path: '',
      root_password: error 'must specify root password',
      exporter_password: error 'must specify exporter password',
    },
  },
}
