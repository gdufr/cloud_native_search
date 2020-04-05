'use strict';
var AWS = require('aws-sdk');
var S3 = new AWS.S3();
var readline = require('readline');

exports.handler = function(event, context) {
    //Get S3 file bucket and name
    var bucket = event.Records[0].s3.bucket.name;
    var key = event.Records[0].s3.object.key;

    //Create read stream from S3
    var s3ReadStream = S3.getObject({ Bucket: bucket, Key: key }).createReadStream();

    //Pass the S3 read stream into the readline interface to break into lines
    var readlineStream = readline.createInterface({ input: s3ReadStream, terminal: false });

    let errorTemplate = {
        "name": "Search Service",
        "module": "",
        "hostname": "",
        "pid": 0,
        "level": "ERROR",
        "err": {
            "message": "",
            "name": "Error",
            "stack": ""
        },
        "msg": "",
        "time": "",
        "v": 0
    };
    let allErrors = [];
    readlineStream.on('line', function(line) {

        // capture fatal lines
        if (line.startsWith("Fatal: ")) {
            let thisError = errorTemplate;
            thisError.msg = line;
            thisError.level = "FATAL";
            thisError.err.message = line;
            thisError.err.name = "FATAL";

            // pull the segment timestamp from the path in the line
            let segmentTimeStamp = line;
            segmentTimeStamp = segmentTimeStamp.replace(new RegExp("^.+?(crawl\/segments)\/"), "");
            segmentTimeStamp = segmentTimeStamp.replace(new RegExp("(/).+$"), "");

            // send the line to elasticSearch
            thisError.time = segmentTimeStamp;
            allErrors.push(thisError);
        }

        // capture error lines
        if (line.startsWith("Error: ")) {
            let thisError = errorTemplate;
            thisError.msg = line;
            thisError.err.message = line;

            // pull the segment timestamp from the path in the line
            let segmentTimeStamp = line;
            segmentTimeStamp = segmentTimeStamp.replace(new RegExp("^.+?(crawl\/segments)\/"), "");
            segmentTimeStamp = segmentTimeStamp.replace(new RegExp("(/).+$"), "");

            // send the line to elasticSearch
            thisError.time = segmentTimeStamp;
            allErrors.push(thisError);
        }
    });

    readlineStream.on('close', function() {
        let keypart = key.replace(new RegExp(/logs\//), '');
        key = 'logs/elasticSearch_log_for_' + keypart;
        S3.putObject({ Bucket: bucket, Key: key, Body: JSON.stringify(allErrors) }, function(err, data) {
            if (err) console.log(err, err.stack); // an error occurred
            else console.log(data); // successful response)
            context.succeed(data);
        });
    });
};

