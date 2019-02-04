#!/usr/bin/env bash

function awsswitch()
{
    local AWS="${1}"
    if [ -z "$AWS" ] ; then
        rm "${HOME}/.awsaccount" &> /dev/null        
    else
        if [ "${AWS}" = "none" ] ; then
            rm "${HOME}/.awsaccount" &> /dev/null
        else
            "${AWSSWITCH_PATH}/awsswitch.sh" use "$1" && eval "$("${AWSSWITCH_PATH}/awsswitch.sh" eval)"
        fi
    fi
}

function awsregion()
{
    local REGION="${1}"
    if [ -z "$REGION" ] ; then
        echo "$AWS_DEFAULT_REGION"
    else
        if ! aws ec2 describe-regions | cut -f 3 | grep "$REGION" &> /dev/null ; then
            echo "invalid region"
        else
            AWS_DEFAULT_REGION="$REGION"
            export AWS_DEFAULT_REGION
        fi
    fi
}

function awslist()
{
    "${AWSSWITCH_PATH}/awsswitch.sh" list
}
