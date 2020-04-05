This is a web Crawl and Search tool.  
It is defined by a set of terraform files configured to deploy the required resources into an AWS account. 

Description of structure:
There are a set of common shared files (common.vars.tf, common.output.tf, provider.config.tf) that are symlinked into the resource directories.
There is also a configuration file in each numbered resource directory that is not shared: terraform.config.tf.  
It cannot be shared because it contains the s3 state file configuration which is specific to the resources in that directory only and variable extrapolation is not possible here. 
As an alternative approach, these settings can be configured by using parameters passed in the terraform command line commands (see terraform help for details). 
The resource directories are numbered to clearly show the deployment sequence.
The resource declarations in the resource directories are organized into code blocks that define a resource and all its dependent vars, dependent resources, and outputs together so that any changes to a resource can be made in a single location.
Shared resources (such as the VPC/subnet where the Cluster, Lambda functions, etc are isolated) are defined separately from their dependent resources.   

Top level structure:

	README.md - this document
    
	each of the numbered directories has a symlink to these shared files in the top level directory
    
	    common.vars.tf - defines shared variables
        
	    common.output.tf - defines shared outputs
        
	    provider.config.tf - defines shared provider configuration
        
	files - templates and files for several resources
    
	  api_gateway/apigateway_swagger_template.yaml - rendered to include the lambda integration endpoint
      
	  hadoop - scripts and files for managing the hadoop cluster 
      
		/nutch/conf/ - configuration files that get transferred into the EMR (Hadoop) cluster to configure the nutch web crawl
        
	  cloudsearch/ - the output search and doc urls from the cloudsearch setup
      
	  urls/seed.txt - lists the seed urls that the nutch job will crawl
      
	  tools/ - tools and scripts used during development
      
	    delete_all_documents.sh can be used to clean out the cloudsearch domain document list
        
	1terraform-state-setup - deploys the S3 state storage and DynamoDB state locking resources
    
	    terraform.config.tf - each of the numbered directories also has its individual S3 state file configuration here
        
	2cloudsearch_setup - deploys the cloudsearch domain
    
	3application_support_setup - deploys the application support resources
    
	  including:
      
	    the VPC where the cluster and optional build server will be deployed
        
	    the SSH key used to access the build server and cluster
        
	      currently configured to use the local ~/.ssh/id_rsa.pub file
          
	      '$ terraform apply' in 3application_support_setup/ to update the ssh key to your local file
          
	      or update configuration with your public key if not using the ~/.ssh/id_rsa.pub default path 
          
	    the EC2 'build server' for managing the hadoop cluster remotely
        
	    the s3 objects that the hadoop cluster references
        
	    the lambda function that integrates the cloudsearch endpoint to the API Gateway
        
	    the rendering of template files for programatically defining the configuration of each resource
        
	4applications - deploys the hadoop cluster and configures cron job to trigger autoscaling and crawling
    
