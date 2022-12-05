This was previously a set of cronjobs which mounted lots of NFS and shuffled bits off of my NAS to Google drive.

I've since realized that I can run rclone directly on the NAS, and then make API requests to it in order to make backups. So this is what I shall do.

4073  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/homes/admin", "dstFs": "localdisk:/share/external/DEV3304_2/BigNASty Sync/homes/admin"}'
 4075  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/homes", "dstFs": "localdisk:/share/external/DEV3304_2/BigNASty Sync/homes"}'
 4080  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/kubestore", "dstFs": "localdisk:/share/external/DEV3304_2/BigNASty Sync/kubestore"}'
 4082  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/Backups", "dstFs": "localdisk:/share/external/DEV3304_2/BigNASty Sync/Backups"}'
 4109  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/Code", "dstFs": "localdisk:/share/external/DEV3304_2/BigNASty Sync/Code"}'
 4110  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/Download", "dstFs": "localdisk:/share/external/DEV3304_2/BigNASty Sync/Download"}'
 4111  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/IronMountain", "dstFs": "localdisk:/share/external/DEV3304_2/BigNASty Sync/IronMountain"}'
 4112  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/multimedia", "dstFs": "localdisk:/share/external/DEV3304_2/BigNASty Sync/multimedia"}'
 4113  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/Multimedia", "dstFs": "localdisk:/share/external/DEV3304_2/BigNASty Sync/Multimedia"}'
 4114  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/Public", "dstFs": "localdisk:/share/external/DEV3304_2/BigNASty Sync/Public"}'
 4115  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/Web", "dstFs": "localdisk:/share/external/DEV3304_2/BigNASty Sync/Web"}'
 4222  history | grep "rclone rc sync"
 4244  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/", "dstFs": "localdisk:/share/external/DEV3304_1/BigNASty Sync/"}'
 4321  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/Backup", "dstFs": "localdisk:/share/external/DEV3304_1/BigNASty Sync/Backup"}'
 4323  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/Backups", "dstFs": "localdisk:/share/external/DEV3304_1/BigNASty Sync/Backups"}'
 4993  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/kubestore", "dstFs": "gsuite-drive:/BigNASty/kubestore"}'
 5031  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/kubestore", "dstFs": "gsuite-drive:/BigNASty/kubestore"}'
 5547  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/", "dstFs": "localdisk:/share/external/DEV3304_2/BigNASty Sync/"}'
 5549  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/", "dstFs": "gsuite-drive:/BigNASty/"}'
 5582  rclone rc sync/sync --rc-addr 192.168.1.10:5572 --rc-user '' --rc-pass '' --json '{"_async": true, "srcFs": "localdisk:/share/CACHEDEV1_DATA/", "dstFs": "gsuite-drive:/BigNASty/"}'