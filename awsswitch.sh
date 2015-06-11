 #!/usr/bin/env bash

function problems {
    echo "ERROR $1"
    exit 1
}

function usage {
    >&2 echo "NOPE"
    exit 1
}

if [ "$AWSSWITCH_KEYS" == "" ] ; then
    problems "AWSSWITCH_KEYS is not defined"
    exit 1
fi

AWSSWITCH_CURRENT="${HOME}/.awsaccount"
if [ "$AWS_AUTO_SCALING_HOME" != "" ] ; then
    AWS_AUTOSCALE_CREDENTIAL_FILE=${AWS_AUTO_SCALING_HOME}/creds
fi

function aws_use {
    NAME="$1"
    if [ "$TMPDIR" == "" ] ; then
        T="/tmp/awsswitch${RANDOM}"
    else
        T="${TMPDIR}/awsswitch${RANDOM}"
    fi
    grep -A 3 -e "^#"$NAME"$" $AWSSWITCH_KEYS &> $T
    if [ $? == 0 ] ; then
        mv $T $AWSSWITCH_CURRENT ; chmod 0600 $AWSSWITCH_CURRENT
    else
        rm -f $T
        problems "awsaccount not found"
    fi
}

function aws_eval {
    if [ -e $AWSSWITCH_CURRENT ] ; then
        REGION="$(tail -n 1 $AWSSWITCH_CURRENT | cut -f 2 -d ':' | sed -e 's! !!g; s!\"!!g')"
        KEY="$(tail -n 3 $AWSSWITCH_CURRENT | head -n 1 | cut -f 2 -d ':' | sed -e 's! !!g; s!\"!!g')"
        SECRET="$(tail -n 2 $AWSSWITCH_CURRENT | head -n 1 | cut -f 2 -d ':' | sed -e 's! !!g; s!\"!!g')"
        if [ "$AWS_SECRET_KEY" != "$SECRET" ] || [ "$AWS_DEFAULT_REGION" == "" ] ; then
            echo "export AWS_DEFAULT_REGION=$REGION"
        fi
        echo "export AWS_ACCOUNT=$(head -n 1 $AWSSWITCH_CURRENT | cut -f 2 -d '#')"
        echo "export AWS_ACCESS_KEY_ID=$KEY"
        echo "export AWS_SECRET_ACCESS_KEY=$SECRET"
        echo "export AWS_ACCESS_KEY=$KEY"
        echo "export AWS_SECRET_KEY=$SECRET"

        if [ "$AWS_AUTOSCALE_CREDENTIAL_FILE" != "" ] ; then
            echo "AWSAccessKeyId=$KEY" > $AWS_AUTOSCALE_CREDENTIAL_FILE
            echo "AWSSecretKey=$SECRET" >> $AWS_AUTOSCALE_CREDENTIAL_FILE
            chmod 600 $AWS_AUTOSCALE_CREDENTIAL_FILE
        fi
        if [ "$AWSSWITCH_S3CFG" == "true" ] ; then
	        echo "[default]" > ~/.s3cfg
	        echo "access_key = ${KEY}" >> ~/.s3cfg
	        echo "secret_key = ${SECRET}" >> ~/.s3cfg
	        chmod 600 ~/.s3cfg
        fi
        if [ "$AWSSWITCH_FOG" == "true" ] ; then
            echo "default:" > ~/.fog
            echo "    aws_access_key_id: ${KEY}" >> ~/.fog
            echo "    aws_secret_access_key: ${SECRET}" >> ~/.fog
            chmod 600 ~/.fog
        fi
    else
        echo "export AWS_ACCOUNT=none"
        echo "export AWS_DEFAULT_REGION=\"\""
    fi
}

if [ $# == 2 ] ; then
    if [ $1 == "use" ] ; then
        aws_use $2
    else
        usage
    fi
elif [ $# == 1 ] ; then
    if [ $1 == "eval" ] ; then
        aws_eval
    else
        usage
    fi
else
    usage
fi
