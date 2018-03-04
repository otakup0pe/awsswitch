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
    MFA_TOKEN_CODE="$2"
    DURATION=129600
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
    if [ -z "$MFA_TOKEN_CODE" ] ; then
        KEY=$(grep -A 2 -E "^\[${NAME}\]$" "${HOME}/.aws/credentials" 2> /dev/null | tail -n 2 | head -n 1 | cut -f 2 -d '=')
        SECRET=$(grep -A 2 -E "^\[${NAME}\]$" "${HOME}/.aws/credentials" 2> /dev/null | tail -n 1 | cut -f 2 -d '=')
    else
        ARN_OF_MFA=$(aws --profile ${NAME} iam --output text list-mfa-devices|awk '{ print $3 }')
        CREDENTIALS="$( aws --profile ${NAME} sts get-session-token \
        --duration $DURATION  \
        --serial-number $ARN_OF_MFA \
        --token-code $MFA_TOKEN_CODE \
        --output text  | awk '{ print $2, $4, $5 }')"
        read KEY SECRET TOKEN <<< "$CREDENTIALS"
    fi
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
    token: "${TOKEN}"
EOF
    mv "$T" "$AWSSWITCH_CURRENT" ; chmod 0600 "$AWSSWITCH_CURRENT"
}

function aws_eval {
    if [ -e "$AWSSWITCH_CURRENT" ] ; then
        REGION="$(sed -n 4p "$AWSSWITCH_CURRENT" | cut -f 2 -d ':' | tr -d '[:space:]')"
        KEY="$(sed -n 2p "$AWSSWITCH_CURRENT" | cut -f 2 -d ':' | tr -d '[:space:]')"
        SECRET="$(sed -n 3p "$AWSSWITCH_CURRENT" | cut -f 2 -d ':' | tr -d '[:space:]')"
        TOKEN=$(sed -n 5p "$AWSSWITCH_CURRENT" | cut -f 2 -d ':' | tr -d '[:space:]')
        if [ "$AWS_SECRET_KEY" != "$SECRET" ] || [ -z "$AWS_DEFAULT_REGION" ] ; then
            echo "export AWS_DEFAULT_REGION=$REGION"
        fi
        echo "export AWS_ACCOUNT=$(head -n 1 "$AWSSWITCH_CURRENT" | cut -f 2 -d '#')"
        echo "export AWS_ACCESS_KEY_ID=$KEY"
        echo "export AWS_SECRET_ACCESS_KEY=$SECRET"
        echo "export AWS_ACCESS_KEY=$KEY"
        echo "export AWS_SECRET_KEY=$SECRET"
        echo "export AWS_SESSION_TOKEN=$TOKEN"
        echo "export AWS_SECURITY_TOKEN=$TOKEN"
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

if [ $# == 2 ] || [ $# == 3 ] ; then
    if [ "$1" == "use" ] ; then
        aws_use "$2" "$3"
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
