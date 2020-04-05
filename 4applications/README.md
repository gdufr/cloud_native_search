4applications defines the EMR (Hadoop) cluster and it's configuration

After successful deployment the cluster should be configured to perform the following every night:
	scale up the cluster
	retrieve the configuration files from S3
	compile the nutch application with the current configuration
	trigger the crawl and document push to CloudSearch
	upload the completed application logs to S3
	scale down the cluster 


If a crawl takes longer than 24 hours then either the cron job frequency should be reduced or the cluster should be scaled up to a larger size
