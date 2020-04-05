# cloudsearch is not available as an aws resource type as of Jan 2019
# this is a workaround that will define providers to execute aws commands to create and destroy the resource

variable "cloudsearch_domain" {
  default = "cloud-native-search"
}

resource "null_resource" "cloudsearch_management" {

  # execute this on terraform apply
  provisioner "local-exec" {
    command = <<EOF
	echo begin apply
	DOMAIN="${var.cloudsearch_domain}"
	echo $DOMAIN

	#check for existence of domain
	domain_exists=`aws cloudsearch list-domain-names | grep \"$DOMAIN\" | wc -l`

	if (( $domain_exists > 0 )) ; then
		echo "The cloudsearch domain $DOMAIN already exists, exiting" 
		
		# refresh the domain description file 
		aws cloudsearch describe-domains --domain-names $DOMAIN > ../files/CS_DOMAIN_"$DOMAIN"_DESCRIPTION.txt

		exit 0
        else

		echo "The cloudsearch domain $DOMAIN does not exist.  Beginning domain creation."

                # create domain
                aws cloudsearch create-domain --domain-name $DOMAIN

echo "
{
\"DomainName\": \"${var.cloudsearch_domain}\",
\"ScalingParameters\":{
\"DesiredInstanceType\":\"search.m3.large\"
}
}" > domain_setup.json

		cat domain_setup.json

		#update the domain to a larger default instance size
		# instance size can be reduced later and, as an AWS managed service, will automatically auto-scale
                aws cloudsearch update-scaling-parameters --cli-input-json file://domain_setup.json

		#define a multi-language analysis scheme
		aws cloudsearch define-analysis-scheme --domain-name $DOMAIN --analysis-scheme "{\"AnalysisSchemeName\":\"analysis_scheme_mul\",\"AnalysisSchemeLanguage\":\"mul\"}"

		# define the index fields
                aws cloudsearch define-index-field --domain-name $DOMAIN --name boost --type double 

                aws cloudsearch define-index-field --domain-name $DOMAIN --name content --type text-array --analysis-scheme analysis_scheme_mul --return-enabled false
                aws cloudsearch define-index-field --domain-name $DOMAIN --name digest --type text-array  --analysis-scheme analysis_scheme_mul
                aws cloudsearch define-index-field --domain-name $DOMAIN --name host --type literal --facet-enabled true 
                aws cloudsearch define-index-field --domain-name $DOMAIN --name id --type text-array  --analysis-scheme analysis_scheme_mul
                aws cloudsearch define-index-field --domain-name $DOMAIN --name segment --type text-array  --analysis-scheme analysis_scheme_mul
                aws cloudsearch define-index-field --domain-name $DOMAIN --name title --type text-array --analysis-scheme analysis_scheme_mul
                aws cloudsearch define-index-field --domain-name $DOMAIN --name tstamp --type date
                aws cloudsearch define-index-field --domain-name $DOMAIN --name url --type text-array  --analysis-scheme analysis_scheme_mul
		aws cloudsearch define-index-field --domain-name $DOMAIN --name title --type text-array --analysis-scheme analysis_scheme_mul
                aws cloudsearch define-index-field --domain-name $DOMAIN --name description --type text-array --analysis-scheme analysis_scheme_mul
                aws cloudsearch define-index-field --domain-name $DOMAIN --name keywords --type text-array --analysis-scheme analysis_scheme_mul

                # Additions for metadata
		# the nutch metatag parser adds a metatag_ prefix to metatags
		aws cloudsearch define-index-field --domain-name $DOMAIN --name metatag_author --type text-array --analysis-scheme analysis_scheme_mul
		aws cloudsearch define-index-field --domain-name $DOMAIN --name metatag_charset --type text-array --analysis-scheme analysis_scheme_mul
		aws cloudsearch define-index-field --domain-name $DOMAIN --name metatag_country --type text-array --analysis-scheme analysis_scheme_mul
		aws cloudsearch define-index-field --domain-name $DOMAIN --name metatag_description --type text-array --analysis-scheme analysis_scheme_mul
		aws cloudsearch define-index-field --domain-name $DOMAIN --name metatag_keywords --type text-array --analysis-scheme analysis_scheme_mul
		aws cloudsearch define-index-field --domain-name $DOMAIN --name metatag_language --type text-array --default-value "en" --analysis-scheme analysis_scheme_mul
		aws cloudsearch define-index-field --domain-name $DOMAIN --name metatag_referrer --type text-array --analysis-scheme analysis_scheme_mul
		aws cloudsearch define-index-field --domain-name $DOMAIN --name metatag_robots --type text-array --analysis-scheme analysis_scheme_mul
		aws cloudsearch define-index-field --domain-name $DOMAIN --name metatag_title --type text-array --analysis-scheme analysis_scheme_mul

		# the creation of the domain happens quickly but the DocService and SearchService endpoint creation takes longer
		# the endpoints are needed before interaction with cloudsearch is possible
		# block the completion of the create operation until the endpoints are populated
		ENDPOINT_COUNT=`aws cloudsearch describe-domains --domain-names $DOMAIN | grep '"Endpoint":' | wc -l`
		while (( $ENDPOINT_COUNT < 2 )); do
			sleep 15
			ENDPOINT_COUNT=`aws cloudsearch describe-domains --domain-names $DOMAIN | grep '"Endpoint":' | wc -l`
		done

		# write the search endpoint to a file for reading in the output
		aws cloudsearch describe-domains --domain-names $DOMAIN | grep -a1 SearchService | grep '"Endpoint"' | sed 's/                "Endpoint": "//' | sed 's/"$//'  > ../files/cloudsearch/cs_search_endpoint.txt

		# write the doc endpoint to a file for reading in the output
		aws cloudsearch describe-domains --domain-names $DOMAIN | grep -a1 DocService | grep '"Endpoint"' | sed 's/                "Endpoint": "//' | sed 's/"$//'  > ../files/cloudsearch/cs_doc_endpoint.txt

		# duplicate the domain across an additional AZ
                # aws cloudsearch update-availability-options --domain-name $DOMAIN --multi-az

		# allow open search endpoint access and restricted doc domain access
		aws cloudsearch update-service-access-policies --domain-name $DOMAIN --access-policies file://../files/cloudsearch/search_open_doc_restricted_policy.json
	fi

	# start indexing
	aws cloudsearch index-documents --domain-name $DOMAIN

	echo end apply
EOF

    interpreter = ["/bin/bash", "-c"]
  }

  # execute this on destroy
  # aws takes time to complete deleting a domain, but it will show "Deleted": true in the cloudsearch domain description after this command runs
  provisioner "local-exec" {
    when = "destroy"

    command = <<EOF
	echo begin destroy
	DOMAIN="${var.cloudsearch_domain}"

	aws cloudsearch delete-domain --domain-name $DOMAIN

	# to handle the lag between flagging a cloudsearch domain as 'deleted' and the aws completion of the delete action this will loop over the describe-domains command and check for the domain until deletion is complete
	KEEP_LOOPING=1

	while (( $KEEP_LOOPING > 0 )); do
		sleep 15;
		KEEP_LOOPING=`aws cloudsearch describe-domains --domain-names $DOMAIN | grep $DOMAIN | wc -l`
	done

	# clean up the previous endpoint output files
	if [ -e "../files/cloudsearch/cs_search_endpoint.txt" ]; then
		rm "../files/cloudsearch/cs_search_endpoint.txt"
	fi
	if [ -e "../files/cloudsearch/cs_doc_endpoint.txt" ]; then
		rm "../files/cloudsearch/cs_doc_endpoint.txt"
	fi

	echo end destroy
EOF

    interpreter = ["/bin/bash", "-c"]
  }
}

output "cloudsearch_domain" {
  value = "${var.cloudsearch_domain}"
}
