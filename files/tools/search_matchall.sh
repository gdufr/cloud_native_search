#!/bin/bash

# USE WITH EXTREME CAUTION

# Note: depends on the AWS CLI SDK being installed, as well as jq
# For jq, see: https://stedolan.github.io/jq/ and https://jqplay.org/

if [[ ! $# -eq 2 || $1 != "--doc-domain" || ! $2 =~ ^https://.*$ ]]; then
   echo "Must define --doc-domain argument (e.g. --doc-domain https://somedomain.aws.com)";
   exit 1;
fi

CS_DOMAIN=$2
TMP_DELETE_FILE=/tmp/delete-all-cloudsearch-documents.json
TMP_RESULTS_FILE=/tmp/delete-all-cloudsearch-documents-tmp-results.json

while [ 1 -eq 1 ]; do
   aws cloudsearchdomain search \
      --endpoint-url=$CS_DOMAIN \
      --size=10000 \
      --query-parser=structured \
      --search-query="matchall" 

    exit 0
done
