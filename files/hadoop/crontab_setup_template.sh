#!/bin/bash

#create cron job for triggering nutch crawl
#write out current crontab
crontab -l > mycron
#echo new cron into cron file
echo '# scale up the cluster before running crawl'  >> mycron
echo '45 21 * * * source /etc/profile && cd ~ && aws configure set default.region eu-central-1 && aws emr modify-instance-groups --cli-input-json file://./scale_up_rendered.json ' >> mycron
echo "" >> mycron
echo '# run the crawl and then scale the cluster back down'  >> mycron
echo '05 22 * * * source /etc/profile && sh ~/run_crawler.sh &> /var/log/search_application_log_`/bin/date +\%Y\%m\%d_\%H\%M`.tmp ; cd ~ && aws configure set default.region eu-central-1 && aws emr modify-instance-groups --cli-input-json file://./scale_down_rendered.json ; for i in $(ls /var/log/search_application_log*); do aws s3 cp $i s3://${bucket}/logs/ && rm $i  ; done  ' >> mycron
#install new cron file
crontab mycron
rm mycron
