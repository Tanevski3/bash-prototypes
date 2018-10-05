#!/usr/bin/env bash

# Helps to define whether application deployment was successful by checking
# connection to HTTP resource. If the page is loaded and the response is 200
# or 201, then the script finishes successfully. In case connection refused
# is or Gateway Timeout (503) the script is trying to connect again within
# timeout period. Otherwise script finishes with fail.
# Needs required parameter url to application and optional parameters timeout
# (by default equals to 180) and artifact version. If artifact version
# parameter is given and the response is 200 or 201, then script also checks
# that # deployed version (gets from $url/version) equals to the passed
# version. If not, the script finishes with fail. Example of usage in bash 
# script:
# sh post_deployment_test.sh http://blah.com/version 100 1.0.102-20160404.101644-5
# result=$?
#
# If $result value equals to 0, then connection is successfully established,
# otherwise, it is not established.

url=$1
timeout=$2
version=$3

if [ -z "$timeout" ]; then
    timeout=180
fi

counter=0
delay=3
while [ $counter -le $timeout ]; do
    command="curl -L -s -o /dev/null -w %{http_code} $url"
    echo "Executing: $command"
    status_code=$($command)
    curl_code=$?

    # Curl error code CURLE_COULDNT_CONNECT (7) means fail to connect to host or proxy.
    # It occurs, in particular, in case when connection refused.
    if [ $curl_code -ne 0 ] && [ $curl_code -ne 7 ]; then
        echo "Connection is not established"
        exit 1
    fi

    if [ $curl_code = 7 ] || [ $status_code = 503 ]; then
        echo "Connection has not been established yet, because connection refused or service unavailable. Trying to connect again"
        sleep $delay
        let counter=$counter+$delay
        continue
    elif [ $status_code = 200 ] || [ $status_code = 201 ]; then
        if [ -z "$version" ]; then
            echo "Connection is successfully established"
            exit 0
        else
            grep_result=`curl -L -s $url | grep $version`
            if [ -z "$grep_result" ]; then
                echo `curl -L -s $url`
                echo "Deployed version doesn't equal to expected"
                exit 1
            else
                echo "Connection is successfully established"
                exit 0
            fi
        fi
    else
        echo "Connection is not established"
        exit 1
    fi
done

echo "Connection is not established"
exit 1