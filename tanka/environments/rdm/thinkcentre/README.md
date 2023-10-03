# Useful commands:

## Update all ATVs on a given subnet with proxy configuration
mysql -h <mysqlhost> -u root -p -e "select ip from ATVsummary where ip like '192%';" atvdetails | while read ip; do adb -s $ip shell -n settings put global http_proxy <proxyhost>:<proxyport>; done