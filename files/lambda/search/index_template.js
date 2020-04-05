const AWS = require('aws-sdk');
const s3 = new AWS.S3();
const cloudsearchdomain = new AWS.CloudSearchDomain({ endpoint: "${cs_search_endpoint}" });

exports.handler = (event, context) => {
    const util = require('util');

    if (event.params.querystring.hasOwnProperty('debug')) {
        console.log("CloudSearch_proxy lambda function received request: ");
        console.log(util.inspect(event, { showHidden: false, depth: null }));
    }

    // if a debug parameter is passed then additional logging will be printed to CloudWatch
    // if debug is not passed then only the request, cloudsearch query, and response will be logged
    if (event.params.debug === 1) { console.log("before if event.hasOwnProperty('params')") }

    // The gateway requires the q param.querystring, all requests should have it
    if (event.hasOwnProperty('params')) {
        if (event.params.hasOwnProperty('querystring')) {

            // If this is having cold start latency problems then a script can hit the endpoint every couple minutes with 
	    //   a set of concurrent requests and pass this 'keepwarm' parameter to keep the function container instances active
            if (event.params.querystring.hasOwnProperty('keepwarm')) {
                console.log("keepwarm selected.  short-circuiting function.");
                context.succeed({});
            }

            // this will allow the application management team to update the site_hosts 
            //   map in S3 without having to make code changes
            // this lambda will pull the current site host map from S3 on every execution
            const src_bkt = "${bucket}";
            const src_key = "${site_host_map_key}";
            if (event.params.querystring.hasOwnProperty('debug')) { console.log("before s3 request") }
            s3.getObject({ Bucket: src_bkt, Key: src_key }).promise()
                .then(data => {

                    if (event.params.querystring.hasOwnProperty('debug')) { console.log("after s3 request bucket: " + src_bkt + " and path: " + src_key) }

                    // for suggestions just return success
                    if (event.hasOwnProperty('context') && event.context.hasOwnProperty('stage') && event.context.stage == 'suggest') {
                        context.succeed({ "stage": "suggest" }); // successful response
                    }

                    // check if json is valid
                    var isValidJSON = true;
                    try { JSON.parse(data.Body.toString('ascii')); }
}
                    catch (err) { isValidJSON = false; }

                    // parse the sitemap json
                    var site_host_map = {};
                    if (isValidJSON) {
                        site_host_map = JSON.parse(data.Body.toString('ascii'));
                        
                    }
                    else {
                        // the site map isn't valid json, return error
                        let err = "Invalid JSON retrived from s3://" + src_bkt + "/" + src_key + ": " + data.Body.toString('ascii');
                        console.log(err);
                        context.fail(err);
                    }
                    // use the site id to set the host for the cloudsearch query string
                    var host = '';
                    if (site_host_map.hasOwnProperty(event.params.querystring['site'])) {
                        host = site_host_map[event.params.querystring['site']];
                    }
                    else {
                        // the site id isn't in the site host map, return error
                        let err = "The site id " + event.params.querystring['site'] + " was not found in the site_host_map.  Please update s3://" + src_bkt + "/" + src_key;
                        console.log(err);
                        context.fail(err);
                    }

                    // set the cloudsearch query parameters
                    // size is usually passed in by the client.  If not passed in, default to 100 results
                    const size = event.params.querystring.hasOwnProperty('num') ? event.params.querystring['num'] : 100;

                    // q is required by the API GW so it should always be present here
                    let q = event.params.querystring['q'];

                    // treat it like an array of strings to handle both single and multiple work searches
                    let qArray = q.trim().split(/\s+/);

                    // start the query string with search term AND
                    let qString = "(and ";

                    // loop over all the search terms and put them in the AND part
                    for (var i = 0, qArrayLen = qArray.length; i < qArrayLen; i++) {
                        qString += " '" + qArray[i] + "'";
                    }

                    let gotInOrSection = false;
                    // add an OR section inside the AND section for the hosts
                    qString += " (or ";
                    // one of the hosts must also match, loop over those and add them to the OR section
                    for (var i = 0, hostlen = host.length; i < hostlen; i++) {
                        if (host[i].hasOwnProperty('match_field') && host[i].hasOwnProperty('value')) {
                            qString += " (term field="+host[i]['match_field']+" '" + host[i]['value'] + "')";
                            gotInOrSection = true;
                        }
                    }
                    if (!gotInOrSection){
                        console.log('The matching host from site_host_map wasn\'t formatted correctly: ', host);
                        context.fail('The matching host from site_host_map wasn\'t formatted correctly: ', host);
                    }
                    // close out the OR and AND parenthesis
                    qString += "))";
                    console.log("cloudsearch query string: ", qString);
                    //  the relevant node sdk: https://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/CloudSearchDomain.html#search-property
                    let params = {
                        query: qString,
                        queryParser: 'structured',
                        size: size
                    };
                    if (event.params.querystring.hasOwnProperty('debug')) { console.log("before cloudsearch request") }

                    return cloudsearchdomain.search(params).promise();
                })
                .then(data => {

                    // queryTime in response should be in seconds
                    data.status['time_s'] = data.status.timems / 1000;

                    // loop over all the search results and make required changes
                    if (data.hasOwnProperty('hits') && data.hits.hasOwnProperty('hit')) {
                        const he = require('he');

                        // queryParams.q_ve in the response replaces whitespace with '+' and html encodes
                        let q_ve = event.params.querystring['q'];
                        if (typeof event.params.querystring['q'] == 'string' || event.params.querystring['q'] instanceof String) {
                            q_ve = event.params.querystring['q'].replace(/[\ ]/g, "\+");
                            q_ve = he.encode(q_ve);
                        }
                        data["q_ve"] = q_ve;

                        for (var i = 0, len = data.hits.hit.length; i < len; i++) {
                            if (data.hits.hit[i] && data.hits.hit[i].hasOwnProperty('fields')) {
                                let thisHit = data.hits.hit[i]['fields'];

                                let properties = Object.getOwnPropertyNames(thisHit);
                                for (var q = 0, proplen = properties.length; q < proplen; q++) {

                                    //html escape strings
                                    if (typeof thisHit[properties[q]][0] == 'string' || thisHit[properties[q]][0] instanceof String) {

                                        data.hits.hit[i]['fields'][properties[q]][0] = he.escape(thisHit[properties[q]][0]);
                                        let re2 = new RegExp("\\\\", "g");
                                        data.hits.hit[i]['fields'][properties[q]][0] = data.hits.hit[i]['fields'][properties[q]][0].replace(re2, '');
                                        if (event.params.querystring.hasOwnProperty('debug') && thisHit[properties[q]][0] != data.hits.hit[i]['fields'][properties[q]][0]) { console.log("updating property: '" + properties[q] + "' from value: " + thisHit[properties[q]][0] + " to value: " + data.hits.hit[i]['fields'][properties[q]][0]); }
                                    }
                                }
                            }
                        }
                    }
                    else {
                        // no results, just return the cloudsearch data
                        console.log("CloudSearch_proxy lambda function returning: ");
                        console.log(util.inspect(data, { showHidden: false, depth: null }));

                        context.succeed(data);
                    }

                    console.log("CloudSearch_proxy lambda function returning: ");
                    console.log(util.inspect(data, { showHidden: false, depth: null }));

                    // results are processed, return them
                    context.succeed(data); // successful response
                })
                .catch(err => {
                    console.log(err, err.stack);
                    context.fail(err); // an error occurred
                });
        }
        else {
            context.fail("No event.params.querystring passed");
        }
    }
    else {
        context.fail("No event.params passed");
    }
};


