#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
#echo "Hostname: $(hostname -f)"
#cat /etc/hosts*

#sudo apt-get update -qqy > /dev/null 2>&1
#sudo apt-get install -qqy python-software-properties > /dev/null 2>&1
#sudo add-apt-repository -y ppa:git-core/ppa > /dev/null 2>&1
sudo apt-get update -qqy > /dev/null 2>&1
#dpkg --get-selections | grep hold

#http://openstack.prov12n.com/quiet-or-unattended-installing-openldap-on-ubuntu-14-04/
echo "Install OpenLDAP, password is: password"
sudo debconf-set-selections <<< "slapd slapd/root_password password password"
sudo debconf-set-selections <<< "slapd slapd/root_password_again password password"
sudo debconf-set-selections <<< "slapd slapd/internal/adminpw password password"
sudo debconf-set-selections <<< "slapd slapd/internal/generated_adminpw password password"
sudo debconf-set-selections <<< "slapd slapd/password2 password password"
sudo debconf-set-selections <<< "slapd slapd/password1 password password"
sudo debconf-set-selections <<< "slapd slapd/allow_ldap_v2 boolean false"
sudo debconf-set-selections <<< "slapd slapd/no_configuration boolean false"
sudo debconf-set-selections <<< "slapd slapd/domain string example.com"
sudo debconf-set-selections <<< "slapd shared/organization string example.com"

sudo apt-get install -qqy slapd ldap-utils > /dev/null 2>&1

cat > /tmp/base.ldif << "EOF"
dn: ou=people,dc=example,dc=com
objectClass: organizationalUnit
ou: people

dn: ou=groups,dc=example,dc=com
objectClass: organizationalUnit
ou: groups
EOF


cat > /tmp/users.ldif << "EOF"
dn: cn=Michael Jackson,ou=people,dc=example,dc=com
objectclass: inetOrgPerson
cn: Michael Jackson
sn: jackson
uid: jacksonm
userpassword: jacksonm
mail: jacksonm@example.com
description: cn=dummyempty,ou=groups,dc=example,dc=com

dn: cn=Deanna Troi,ou=people,dc=example,dc=com
objectclass: inetOrgPerson
cn: Deanna Troi
sn: Troi
uid: troid
userpassword: troid
mail: troid@example.com

dn: cn=William Riker,ou=people,dc=example,dc=com
objectclass: inetOrgPerson
cn: William Riker
sn: Riker
uid: rikerw
userpassword: rikerw
mail: rikerw@example.com

dn: cn=ldaprole,ou=groups,dc=example,dc=com
objectClass: groupOfUniqueNames
cn: ldaprole
uniqueMember: cn=Michael Jackson,ou=people,dc=example,dc=com
uniqueMember: cn=Deanna Troi,ou=people,dc=example,dc=com
uniqueMember: cn=William Riker,ou=people,dc=example,dc=com
EOF

set -e
ldapadd -x -D "cn=admin,dc=example,dc=com" -w "password" -f /tmp/base.ldif > /dev/null 2>&1
ldapadd -x -D cn="admin,dc=example,dc=com" -w "password" -f /tmp/users.ldif > /dev/null 2>&1
set +e

#sudo slapcat

echo "Install OpenSSL and tools"
sudo apt-get -qqy install ntp ntpdate haveged libapr1 openssl autoconf libtool libssl-dev > /dev/null 2>&1
#entropy generator
haveged -w 1024 > /dev/null 2>&1
echo "Install MIT Kerberos"
#https://github.com/sukharevd/hadoop-install/blob/master/bin/install-kerberos.sh
sudo debconf-set-selections <<< 'krb5-admin-server krb5-admin-server/kadmind boolean true'
sudo debconf-set-selections <<< 'krb5-admin-server krb5-admin-server/newrealm note'

mkdir -p /var/log/kerberos > /dev/null 2>&1
touch /var/log/kerberos/krb5libs.log > /dev/null 2>&1
touch /var/log/kerberos/krb5kdc.log > /dev/null 2>&1
touch /var/log/kerberos/kadmind.log > /dev/null 2>&1

DNS_ZONE="example.com"
REALM=$(echo "$DNS_ZONE" | tr '[:lower:]' '[:upper:]')
#KERBEROS_FQDN="krbldap.example.com"

cat > /etc/krb5.conf << "EOF"
[realms]
${REALM} = {
kdc = localhost:88
kdc = 127.0.0.1:88
#admin_server = ${KERBEROS_FQDN}:8749
default_domain = ${DNS_ZONE}
}

[domain_realm]
.${DNS_ZONE} = ${REALM}
${DNS_ZONE} = ${REALM}

[libdefaults]
default_realm = ${REALM}
dns_lookup_realm = false
dns_lookup_kdc = false
forwardable=true
dns_canonicalize_hostname = false
rdns = false
ignore_acceptor_hostname = true
# allow weak crypto, dont do this in production
# also do not use rc4
allow_weak_crypto = true
default_tkt_enctypes = aes128-cts-hmac-sha1-96 rc4-hmac
default_tgs_enctypes = aes128-cts-hmac-sha1-96  rc4-hmac
permitted_enctypes = aes128-cts-hmac-sha1-96 rc4-hmac

#[kdc]
#    profile = /etc/krb5kdc/kdc.conf

#[logging]
#    default = FILE:/var/log/kerberos/krb5libs.log
#    kdc = FILE:/var/log/kerberos/krb5kdc.log
#    admin_server = FILE:/var/log/kerberos/kadmind.log
EOF
sed -i -e 's/${KERBEROS_FQDN}/'$KERBEROS_FQDN'/g' /etc/krb5.conf
sed -i -e 's/${DNS_ZONE}/'$DNS_ZONE'/g' /etc/krb5.conf
sed -i -e 's/${REALM}/'$REALM'/g' /etc/krb5.conf

#cat /etc/krb5.conf

mkdir -p /etc/krb5kdc
mkdir -p /var/lib/krb5kdc

cat > /etc/krb5kdc/kdc.conf << "EOF"
[libdefaults]
debug = true

[logging]
kdc = FILE:/var/log/krb5kdc.log

[kdcdefaults]
kdc_ports = 749,88
kdc_tcp_ports = 88

[realms]
${REALM} = {
database_name = /var/lib/krb5kdc/principal
admin_keytab = FILE:/etc/krb5kdc/kadm5.keytab
acl_file = /etc/krb5kdc/kadm5.acl
key_stash_file = /etc/krb5kdc/stash

kdc_ports = 749,88
max_life = 10h 0m 0s
max_renewable_life = 7d 0h 0m 0s
master_key_type = des3-hmac-sha1
#supported_enctypes = aes256-cts:normal arcfour-hmac:normal des3-hmac-sha1:normal des-cbc-crc:normal des:normal des:v4 des:norealm des:onlyrealm des:afs3
default_principal_flags = +preauth
}
EOF
sed -i -e 's/${REALM}/'$REALM'/g' /etc/krb5kdc/kdc.conf

#cat /etc/krb5kdc/kdc.conf

sudo apt-get -qqy install krb5-{user,admin-server,kdc} > /dev/null 2>&1

sudo kdb5_util create -s -P aaaBBBccc123

set -e
sudo /etc/init.d/krb5-kdc restart > /dev/null 2>&1
sudo /etc/init.d/krb5-admin-server restart > /dev/null 2>&1
sudo /etc/init.d/slapd restart > /dev/null 2>&1

sudo /usr/sbin/kadmin.local -q 'addprinc -randkey HTTP/localhost' > /dev/null 2>&1
sudo /usr/sbin/kadmin.local -q "ktadd -k /tmp/http_srv.keytab  HTTP/localhost" > /dev/null 2>&1

sudo /usr/sbin/kadmin.local -q 'addprinc -randkey testuser1' > /dev/null 2>&1
sudo /usr/sbin/kadmin.local -q "ktadd -k /tmp/testuser1.keytab testuser1" > /dev/null 2>&1

sudo /usr/sbin/kadmin.local -q 'addprinc -randkey adm' > /dev/null 2>&1
sudo /usr/sbin/kadmin.local -q "ktadd -k /tmp/adm.keytab adm" > /dev/null 2>&1

sudo /usr/sbin/kadmin.local -q 'addprinc -randkey rikerw' > /dev/null 2>&1
sudo /usr/sbin/kadmin.local -q "ktadd -k /tmp/rikerw.keytab rikerw" > /dev/null 2>&1

sudo chmod 777 /tmp/* > /dev/null 2>&1

sudo kinit -V -kt /tmp/testuser1.keytab testuser1
set +e

#echo "krb5-multidev"
#sudo apt-get -qqy install krb5-multidev

#git --version
#echo "git"
#sudo apt-get -qqy install git > /dev/null
#git --version

#sudo apt-get -y --force-yes remove --auto-remove curl
#sudo apt-get -qqy --force-yes purge curl lib
cd ~
mkdir curlk
CURLDIR="$(pwd)/curlk"
mkdir -p $CURLDIR
echo "Build curl into $CURLDIR"
wget -nv https://github.com/curl/curl/archive/curl-7_49_1.tar.gz > /dev/null 2>&1
tar -xzf curl-7_49_1.tar.gz > /dev/null 2>&1
#git clone https://github.com/curl/curl.git
cd curl-curl-7_49_1
#git checkout cf93a7b364a70b56150cf6ea77492b799ec02a45
./buildconf  > /dev/null 2>&1
./configure --with-gssapi --with-ssl --prefix="$CURLDIR"  > /dev/null 2>&1
make  > /dev/null 2>&1
sudo make install  > /dev/null 2>&1
sudo chmod +x /home/ubuntu/curlk/bin/curl
# curl 7.43.0 (x86_64-apple-darwin14.0) libcurl/7.43.0 SecureTransport zlib/1.2.5
# Protocols: dict file ftp ftps gopher http https imap imaps ldap ldaps pop3 pop3s rtsp smb smbs smtp smtps telnet tftp
# Features: AsynchDNS IPv6 Largefile GSS-API Kerberos SPNEGO NTLM NTLM_WB SSL libz UnixSockets
set -e
/home/ubuntu/curlk/bin/curl -V
set +e
#find / -iname curl
cd ..