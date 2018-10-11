#!/usr/bin/env bash

function problems {
    echo "ERROR $1"
    exit 1
}

function usage {
    >&2 echo "NOPE"
    exit 1
}

AWSSWITCH_CURRENT="${HOME}/.awsaccount"
if [ "$AWS_AUTO_SCALING_HOME" != "" ] ; then
    AWS_AUTOSCALE_CREDENTIAL_FILE=${AWS_AUTO_SCALING_HOME}/creds
fi

function aws_list {
    grep -E "^\[.+\]$" ~/.aws/credentials | sed -e 's!\[!!g' -e 's!\]!!g'
}

function aws_use {
    NAME="$1"
    if [ -z "$TMPDIR" ] ; then
        T="/tmp/awsswitch${RANDOM}"
    else
        T="${TMPDIR}/awsswitch${RANDOM}"
    fi
    REGION=$(grep -A 1 -E "^\[profile ${NAME}\]$" "${HOME}/.aws/config" 2> /dev/null | tail -n 1 | cut -f 2 -d '=')
    # default region if not in config file.
    if [ -z "$REGION" ]; then
        REGION="us-east-1"
    fi
    
    KEY=$(grep -A 2 -E "^\[${NAME}\]$" "${HOME}/.aws/credentials" 2> /dev/null | tail -n 2 | head -n 1 | cut -f 2 -d '=')
    SECRET=$(grep -A 2 -E "^\[${NAME}\]$" "${HOME}/.aws/credentials" 2> /dev/null | tail -n 1 | cut -f 2 -d '=')
    if [ -z "$REGION" ] || \
           [ -z "$KEY" ] || \
           [ -z "$SECRET" ] ; then
        problems "awsaccount not found"
    fi
    cat <<EOF > "$T"
#${NAME}
  - id: "${KEY}"
    secret: "${SECRET}"
    region: "${REGION}"
EOF
    mv "$T" "$AWSSWITCH_CURRENT" ; chmod 0600 "$AWSSWITCH_CURRENT"
}

function aws_eval {
    if [ -e "$AWSSWITCH_CURRENT" ] ; then
        REGION="$(tail -n 1 "$AWSSWITCH_CURRENT" | cut -f 2 -d ':' | sed -e 's! !!g; s!\"!!g')"
        KEY="$(tail -n 3 "$AWSSWITCH_CURRENT" | head -n 1 | cut -f 2 -d ':' | sed -e 's! !!g; s!\"!!g')"
        SECRET="$(tail -n 2 "$AWSSWITCH_CURRENT" | head -n 1 | cut -f 2 -d ':' | sed -e 's! !!g; s!\"!!g')"
        PROFILE="$(head -n 1 "$AWSSWITCH_CURRENT" | cut -c 2-)"
        if [ "$AWS_SECRET_KEY" != "$SECRET" ] || [ -z "$AWS_DEFAULT_REGION" ] ; then
            echo "export AWS_DEFAULT_REGION=$REGION"
        fi
        echo "export AWS_PROFILE=${PROFILE}"
        echo "export AWS_ACCOUNT=$(head -n 1 "$AWSSWITCH_CURRENT" | cut -f 2 -d '#')"
        echo "export AWS_ACCESS_KEY_ID=$KEY"
        echo "export AWS_SECRET_ACCESS_KEY=$SECRET"
        echo "export AWS_ACCESS_KEY=$KEY"
        echo "export AWS_SECRET_KEY=$SECRET"
        echo "export EC2_REGION=$AWS_DEFAULT_REGION"

        if [ ! -z "$AWS_AUTOSCALE_CREDENTIAL_FILE" ] ; then
            echo "AWSAccessKeyId=$KEY" > "$AWS_AUTOSCALE_CREDENTIAL_FILE"
            echo "AWSSecretKey=$SECRET" >> "$AWS_AUTOSCALE_CREDENTIAL_FILE"
            chmod 600 "$AWS_AUTOSCALE_CREDENTIAL_FILE"
        fi
        if [ "$AWSSWITCH_S3CFG" == "true" ] ; then
	        echo "[default]" > "${HOME}/.s3cfg"
	        echo "access_key = ${KEY}" >> "${HOME}/.s3cfg"
	        echo "secret_key = ${SECRET}" >> "${HOME}/.s3cfg"
	        chmod 600 "${HOME}/.s3cfg"
        fi
        if [ "$AWSSWITCH_FOG" == "true" ] ; then
            echo "default:" > "${HOME}/.fog"
            echo "    aws_access_key_id: ${KEY}" >> "${HOME}/.fog"
            echo "    aws_secret_access_key: ${SECRET}" >> "${HOME}/.fog"
            chmod 600 "${HOME}/.fog"
        fi
    else
        echo "export AWS_ACCOUNT=none"
        echo "export AWS_DEFAULT_REGION=\"\""
    fi
}

if [ $# == 2 ] ; then
    if [ "$1" == "use" ] ; then
        aws_use "$2"
    else
        usage
    fi
elif [ $# == 1 ] ; then
    if [ "$1" == "eval" ] ; then
        aws_eval
    elif [ "$1" == "list" ] ; then
        aws_list
    else
        usage
    fi
else
    usage
fi
