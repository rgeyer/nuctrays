{
  _config+:: {
    cortex+:: {
      pvc: {
        nfsHost: '192.168.42.100',
        nfsPath: '/mnt/brick/nfs/cortex',
      }
    },

    backups+:: {
      pvc: {
        nfsHost: '192.168.42.10',
        nfsPath: '/Backups/nuctray/eighteen',
      }
    },

    jenkins+:: {
      pvc: {
        nfsHost: '192.168.42.100',
        nfsPath: '/mnt/brick/nfs/jenkins',
      }
    }
  }
}
