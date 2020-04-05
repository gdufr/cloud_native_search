#!/bin/sh

# pull the conf files down and ant clean runtime 
cd /home/hadoop/nutch

echo "begin conf copy: `date`"
hadoop fs -copyToLocal -f s3://${application_support_bucket_name}/hadoop/nutch/conf/* conf/
echo "end conf copy: `date`"

echo "begin ant clean runtime: `date`"
ant clean runtime
echo "end ant clean runtime: `date`"


/home/hadoop/nutch/runtime/deploy/bin/crawl -i s3://${application_support_bucket_name}/urls/seed.txt /crawl -1

