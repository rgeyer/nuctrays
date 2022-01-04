{
  auth_enabled: false,

  server: {
    http_listen_port: 80,
    grpc_listen_port: 9095,

    // Configure the server to allow messages up to 100MB.
    grpc_server_max_recv_msg_size: 104857600,
    grpc_server_max_send_msg_size: 104857600,
    grpc_server_max_concurrent_streams: 1000,
  },

  distributor: {
    remote_timeout: '20s',
    shard_by_all_labels: true,
    pool: {
      health_check_ingesters: true,
    },
  },

  ingester_client: {
    grpc_client_config: {
      max_recv_msg_size: 104857600,
      max_send_msg_size: 104857600,
      grpc_compression: 'gzip',
    },
  },

  ingester: {
    lifecycler: {
      join_after: 0,
      min_ready_duration: '0s',
      final_sleep: '0s',
      num_tokens: 512,

      ring: {
        kvstore: {
          store: 'inmemory',
        },
        replication_factor: 1,
      },
    },
  },

  storage: {
    engine: 'blocks',
  },

  blocks_storage: {
    tsdb: {
      dir: '/tmp/cortex/tsdb',
    },
    bucket_store: {
      sync_dir: '/tmp/cortex/tsdb-sync',
    },

    backend: 's3',
    s3: {
      endpoint: $.s3_blocks_endpoint,
      access_key_id: $.s3_blocks_access_key_id,
      secret_access_key: $.s3_blocks_secret_access_key,
      insecure: true,
      bucket_name: $.s3_blocks_bucket,
    },
  },

  compactor: {
    data_dir: '/tmp/cortex/compactor',
    sharding_ring: {
      kvstore: {
        store: 'inmemory',
      },
    },
  },

  frontend_worker: {
    match_max_concurrent: true,
  },

  ruler: {
    rule_path: '/tmp/cortex/rules-tmp',
    enable_api: true,
    enable_sharding: false,
    storage: {
      type: 's3',
      s3: {
        s3: $.s3_rules_host,
        bucketnames: $.s3_rules_bucket,
        s3forcepathstyle: true,
        endpoint: 'minio:9000',
        insecure: true,
      },
    },
  },

  limits: {
    ingestion_rate: 250000,
    ingestion_burst_size: 500000,
  },
}
