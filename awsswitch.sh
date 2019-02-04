#!/usr/bin/env bash
set -e

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
    AWS_AUTOSCALE_CREDENTIAL_FILE="${AWS_AUTO_SCALING_HOME}/creds"
fi

function aws_list {
    grep -E '^\[profile .+\]$' ~/.aws/config | sed -re 's!^\[profile (.+)\]$!\1!g'
}

function assume_a_role {
    local NAME="$1"
    local ROLE="$2"
    local PARENT="$3"
    local REGION="$4"
    local CREDS
    local EXPIRY
    local SESSION
    local SECRET
    local KEY
    local T
    if [ -z "$TMPDIR" ] ; then
        T="/tmp/awsswitch-sts${RANDOM}"
    else
        T="${TMPDIR}/awsswitch-sts${RANDOM}"
    fi
    if ! CREDS="$(aws sts assume-role --role-arn "$ROLE" --role-session-name "awsswitch-${RANDOM}" --profile "$PARENT" --output text 2> /dev/null)" ; then
        problems "Unable to assume role"
    fi
    KEY="$(awk '$1 ~ /CREDENTIALS/ { print $2 }' <<< "$CREDS")"
    SECRET="$(awk '$1 ~ /CREDENTIALS/ { print $4 }' <<< "$CREDS")"
    EXPIRY="$(awk '$1 ~ /CREDENTIALS/ { print $3 }' <<< "$CREDS")"
    SESSION="$(awk '$1 ~ /CREDENTIALS/ { print $5 }' <<< "$CREDS")"
    EXPIRY="$(date -d "$EXPIRY" '+%s')"
    cat <<EOF > "$T"
NAME="$NAME"
KEY="$KEY"
SECRET="$SECRET"
REGION="$REGION"
SESSION="$SESSION"
EXPIRY="$EXPIRY"
PARENT="$PARENT"
ROLE="$ROLE"
EOF
    mv "$T" "$AWSSWITCH_CURRENT" ; chmod 0600 "$AWSSWITCH_CURRENT"
}

function aws_use {
    local CONFIG
    local CREDS
    local REGION
    local NAME="$1"

    if [ -z "$TMPDIR" ] ; then
        T="/tmp/awsswitch${RANDOM}"
    else
        T="${TMPDIR}/awsswitch${RANDOM}"
    fi

    # levelling up in awk; extracts the bit between two profile sections (or a profile section and eof)
    CONFIG="$(awk 'BEGIN{FS="\n"}$1 ~ /^\[profile '"$NAME"'\]/{mark=1; next}/^\[profile .+\]/{mark=0}mark && !/^#.+$/ && !/^ *$/' < ~/.aws/config)"
    if [ -z "$CONFIG" ] ; then
        problems "awsaccount not found"
    fi
    REGION="$(awk 'BEGIN{FS="="}/region/{gsub(/[ \t]?/, "", $2);print $2}' <<< "$CONFIG")"
    # default region if not in config file.
    if [ -z "$REGION" ]; then
        REGION="us-east-1"
    fi
    if ! grep 'role_arn' <<< "$CONFIG" &> /dev/null ; then
        local CREDS
        local KEY
        local SECRET
        CREDS="$(awk 'BEGIN{FS="\n"}$1 ~ /^\['"$NAME"'\]/{mark=1; next}/^\[.+\]/{mark=0}mark && !/^#.+$/ && !/^ *$/' < ~/.aws/credentials)"
        if [ -z "$CREDS" ] ; then
            problems "invalid awsaccount"
        fi
        KEY="$(awk 'BEGIN{FS="="}/aws_access_key_id/{gsub(/[ \t]?/, "", $2);print $2}' <<< "$CREDS")"
        SECRET="$(awk 'BEGIN{FS="="}/aws_secret_access_key/{gsub(/[ \t]?/, "", $2);print $2}' <<< "$CREDS")"
        if [ -z "$KEY" ] || [ -z "$SECRET" ] ; then
            problems "invalid awsaccount"
        fi
    cat <<EOF > "$T"
NAME="$NAME"
KEY="$KEY"
SECRET="$SECRET"
REGION="$REGION"
EOF
    mv "$T" "$AWSSWITCH_CURRENT" ; chmod 0600 "$AWSSWITCH_CURRENT"
    else
        local ROLE
        local PARENT
        ROLE="$(awk 'BEGIN{FS="="}/role_arn/{gsub(/[ \t]?/, "", $2);print $2}' <<< "$CONFIG")"
        PARENT="$(awk 'BEGIN{FS="="}/source_profile/{gsub(/[ \t]?/, "", $2);print $2}' <<< "$CONFIG")"        
        assume_a_role "$NAME" "$ROLE" "$PARENT" "$REGION"
    fi
}

function unset_aws {
    cat <<EOF 
export AWS_ACCOUNT=none
unset -v AWS_DEFAULT_REGION
unset -v REGION
unset -v EC2_REGION
unset -v AWS_PROFILE
unset -v AWS_ACCESS_KEY_ID
unset -v AWS_ACCESS_KEY
unset -v AWS_SECRET_ACCESS_KEY
unset -v AWS_SECRET_KEY
unset -v AWS_SESSION_TOKEN
EOF
}

function aws_eval {
    if [ -e "$AWSSWITCH_CURRENT" ] ; then
        local NAME
        local KEY
        local SECRET
        local REGION
        local SESSION
        local EXPIRY
        # "migration path"
        if [ "$(head -n 1 "$AWSSWITCH_CURRENT" | cut -c 1)" == "#" ] ; then
            unset_aws
            exit 1
        fi
        # shellcheck source=/dev/null
        source "$AWSSWITCH_CURRENT"
        if [ -z "$NAME" ] || [ -z "$REGION" ] ; then
            unset_aws
            exit 1
        fi
        if [ "$AWS_SECRET_KEY" != "$SECRET" ] || [ -z "$AWS_DEFAULT_REGION" ] ; then
            echo "export AWS_DEFAULT_REGION=$REGION        # aws cli / standard"
        fi
        cat <<EOF
        export REGION=$REGION                    # deprecated
        export EC2_REGION=$AWS_DEFAULT_REGION    # deprecated
        export AWS_PROFILE=$NAME                 # aws cli / standard
        export AWS_ACCOUNT=$NAME                 # internal
EOF
        if [ -n "$EXPIRY" ] ; then
            if [ -z "$ROLE" ] || [ -z "$PARENT" ] ;then
                unset_aws
                exit 1
            fi
            NOW="$(date '+%s')"
            if [ -z "$AWSSWITCH_STS_RENEW" ] ; then
                AWSSWITCH_STS_RENEW=300
            fi
            if [ $((EXPIRY - NOW)) -lt $AWSSWITCH_STS_RENEW ] ; then
                if [ -z "$TMPDIR" ] ; then
                    T="/tmp/awsswitch-renew${RANDOM}"
                else
                    T="${TMPDIR}/awsswitch-renew${RANDOM}"
                fi
                assume_a_role "$NAME" "$ROLE" "$PARENT" "$REGION"
                # shellcheck source=/dev/null
                source "$AWSSWITCH_CURRENT"
            fi
        fi
        cat <<EOF
        export AWS_ACCESS_KEY_ID=$KEY            # aws cli / standard
        export AWS_ACCESS_KEY=$KEY               # deprecated
        export AWS_SECRET_ACCESS_KEY=$SECRET     # aws cli / standard
        export AWS_SECRET_KEY=$SECRET            # aws secret
EOF
        if [ -n "$SESSION" ] ; then
            echo " export AWS_SESSION_TOKEN=$SESSION        # aws session"
        else
            echo "unset AWS_SESSION_TOKEN"
        fi
        if [ "$AWS_AUTOSCALE_CREDENTIAL_FILE" == "true" ] ; then
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
        unset_aws
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
