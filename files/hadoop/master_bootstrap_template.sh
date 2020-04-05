#!/bin/bash
#set -Eeuxo pipefail
# see https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

# export the cloudsearch globals
export CLOUDSEARCH_SEARCH_ENDPOINT='${cs_search_endpoint}'
export CLOUDSEARCH_DOC_ENDPOINT='${cs_doc_endpoint}'

if [ `grep 'isMaster' /mnt/var/lib/info/instance.json | awk -F ':' '{print $2}' | awk -F ',' '{print $1}'` = 'false' ]; then
	sudo yum update -y --skip-broken
	echo "This is not the master node, exiting."
	exit 0
fi

cd /home/hadoop

echo "begin sudo yum update: `date`"
sudo yum update -y --skip-broken
echo "end sudo yum update: `date`"


echo "begin ant install: `date`"
# Install ant from source (we need ant 1.9 instead of the default 1.8)
wget http://mirror.checkdomain.de/apache//ant/binaries/apache-ant-1.9.13-bin.zip
unzip apache-ant-1.9.13-bin.zip
sudo mv apache-ant-1.9.13 /opt/ant
sudo ln -s /opt/ant/bin/ant /usr/bin/ant
echo '#!/bin/bash
export JAVA_HOME=$(readlink -f $(which java) | sed -e 's/bin\/java$//')
export ANT_HOME=/opt/ant
export PATH=$JAVA_HOME:$ANT_HOME/bin:$PATH
export CLASSPATH=.' > ant.sh

echo '#!/bin/bash
export JAVA_HOME=$(readlink -f $(which java) | sed -e 's/bin\/java$//')
export ANT_HOME=/opt/ant
export PATH=$JAVA_HOME:$ANT_HOME/bin:$PATH
export CLASSPATH=.' >> ~/.bash_profile.sh
sudo mv ant.sh /etc/profile.d/ant.sh
sudo chmod +x /etc/profile.d/ant.sh
source /etc/profile.d/ant.sh
echo "end ant install: `date`"

echo "begin nutch install: `date`"
# Prepare Nutch 1.x
wget -O trunk.zip https://github.com/apache/nutch/archive/trunk.zip
unzip trunk.zip -d nutch
cd nutch
mv nutch-*/* ./
rm -rf nutch-* 
echo "end nutch install: `date`"
sed -i -e 's/if [(]attrName.equals[(]"name"[)]/if (attrName.equals("name")  \|\| attrName.equals("property")/' /home/hadoop/nutch/src/plugin/parse-html/src/java/org/apache/nutch/parse/html/HTMLMetaProcessor.java

cd /home/hadoop/nutch

echo "begin seed setup: `date`"
hadoop fs -mkdir /urls
hadoop fs -copyToLocal -f s3://${application_support_bucket_name}/urls/seed.txt /urls
echo "end seed setup: `date`"

echo "begin conf copy: `date`"
hadoop fs -copyToLocal -f s3://${application_support_bucket_name}/hadoop/nutch/conf/* conf/
echo "end conf copy: `date`"

sleep 10
echo "begin ant clean runtime: `date`"
ant clean runtime
echo "end ant clean runtime: `date`"

echo "ready" > /home/hadoop/nutch/ready.status

exit 0
