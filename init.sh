#!/usr/bin/env bash

function awsswitch()
{
    local AWS="${1}"
    if [ -z "$AWS" ] ; then
        echo "invalid aws"
    else
        if [ "${AWS}" = "none" ] ; then
            rm "${HOME}/.awsaccount" &> /dev/null
        else
            if ! grep -e "$AWS" "${HOME}/.aws/credentials" &> /dev/null ; then
                echo "invalid aws"
            else
                "${AWSSWITCH_PATH}/awsswitch.sh" use "$1" "$2" && eval "$("${AWSSWITCH_PATH}/awsswitch.sh" eval)"
            fi
        fi
    fi
}

function awsregion()
{
    local REGION="${1}"
    if ! aws ec2 describe-regions | cut -f 3 | grep "$REGION" &> /dev/null ; then
        echo "invalid region"
    else
        AWS_DEFAULT_REGION="$REGION"
        export AWS_DEFAULT_REGION
    fi
}

function awslist()
{
    "${AWSSWITCH_PATH}/awsswitch.sh" list
}
