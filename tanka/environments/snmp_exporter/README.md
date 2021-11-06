Clone https://github.com/prometheus/snmp_exporter.git

Go to ./generator & follow instructions there

Fetch some additional mibs
`curl -o mibs/QNAP-MIB.txt http://192.168.1.10:8080/cgi-bin/download/mib/NAS.mib\?sid\=fa20f1u7z`
`curl -o mibs/RFC1213-MIB.txt https://bestmonitoringtools.com/mibdb/mibs/RFC1213-MIB.mib`

Then ./generator /path/to/generator.yml

Take the generated snmp.yml and copy it to the data directory.