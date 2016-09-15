#!/bin/sh
#IP=$(hostname -I | cut -f2 -d' ')
HOSTNAME=$(hostname -f)

echo "Wait a until elasticsearch is up on $HOSTNAME"

while ! nc -z $HOSTNAME 9200; do   
  sleep 0.1 # wait for 1/10 of the second before check again
done

echo "Elasticsearch on $HOSTNAME is up!"

if [ "$HOSTNAME" = "sgssl-2.example.com" ];
then
  echo "Wait for other nodes"
  sleep 5
  cd $ES_PLUGIN_DIR/search-guard-2/tools
  chmod +x sgadmin.sh
  ./sgadmin.sh -h $HOSTNAME -cn sgtest_docker -cd "$ES_CONF_DIR/dyn" -ks "$ES_CONF_DIR/CN=kirk,OU=client,O=client,L=Test,C=DE-keystore.jks" -ts "$ES_CONF_DIR/truststore.jks"
else
  sleep 10
fi

if [ "$HOSTNAME" = "sgssl-0.example.com" ];
then
while :
do
    #openssl s_client -servername sgssl-0.example.com -tls1_2 -connect sgssl-0.example.com:9200  -CAfile "$ES_CONF_DIR/chain-ca.pem"  -verify_return_error -cert "$ES_CONF_DIR/CN=picard,OU=client,O=client,L=Test,C=DE.all.pem" &
	#openssl s_client -servername sgssl-0.example.com -tls1_2 -connect sgssl-0.example.com:9200  -CAfile "$ES_CONF_DIR/chain-ca.pem"  -verify_return_error -cert "$ES_CONF_DIR/CN=picard,OU=client,O=client,L=Test,C=DE.crtfull.pem" -key "$ES_CONF_DIR/CN=picard,OU=client,O=client,L=Test,C=DE.key.pem" &

	echo "--------------------- WGET Combined ------------"
	wget -O- --ca-cert="$ES_CONF_DIR/chain-ca.pem" --certificate="$ES_CONF_DIR/CN=kirk,OU=client,O=client,L=Test,C=DE.all.pem" https://sgssl-0.example.com:9200/_searchguard/sslinfo 	
	echo ""
	echo "--------------------- WGET Single ------------"
	wget -O- --user=admin --password=admin --ca-cert="$ES_CONF_DIR/chain-ca.pem" --certificate="$ES_CONF_DIR/CN=picard,OU=client,O=client,L=Test,C=DE.crtfull.pem" --private-key="$ES_CONF_DIR/CN=picard,OU=client,O=client,L=Test,C=DE.key.pem" https://sgssl-0.example.com:9200/_cluster/health
    echo ""
    echo "--------------------- CURL Combined ------------"
	curl -Ss https://sgssl-0.example.com:9200/_searchguard/sslinfo -E "$ES_CONF_DIR/CN=kirk,OU=client,O=client,L=Test,C=DE.all.pem" --cacert "$ES_CONF_DIR/chain-ca.pem"
	echo ""
	echo "--------------------- CURL Single ------------"
	curl -Ss -u admin:admin https://sgssl-0.example.com:9200/_cluster/health -E "$ES_CONF_DIR/CN=picard,OU=client,O=client,L=Test,C=DE.crtfull.pem" --key "$ES_CONF_DIR/CN=picard,OU=client,O=client,L=Test,C=DE.key.pem" --cacert "$ES_CONF_DIR/chain-ca.pem"
	echo ""
	python3 /esclient.py
	echo ""
	#curator --host sgssl-0.example.com --port 9200 --use_ssl --client-cert "$ES_CONF_DIR/CN=picard,OU=client,O=client,L=Test,C=DE.crtfull.pem" --client-key "$ES_CONF_DIR/CN=picard,OU=client,O=client,L=Test,C=DE.key.pem" --certificate "$ES_CONF_DIR/chain-ca.pem" show indices --all-indices
	#curator --host sgssl-0.example.com --port 9200 --use_ssl --client-cert "$ES_CONF_DIR/CN=picard,OU=client,O=client,L=Test,C=DE.all.pem" --certificate "$ES_CONF_DIR/chain-ca.pem" show indices --all-indices
	sleep 10
done
else
while :
do
sleep 1000
done
fi