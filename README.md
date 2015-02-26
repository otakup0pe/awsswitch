AWS Switch
==========

These scripts represent my approach for sanely working with multiple AWS accounts. When in use it will keep appropriate AWS related environment variables, and, optionally, certain configuration files up to date with the appropriate AWS keys. Only one AWS account may be active at a time and this is synchronized across login sessions for a given user on the local host.

I [wrote|http://blog.eghetto.ca/post/112089594641/juggling-clouds] about how I ended up with this workflow.

Installation
------------

Clone this repository somewhere comfortable on your workstation. There are four environment variables which configure the scripts. Define these as you wish and then source the `init.sh` script in your `.profile`.

 * `AWSSWITCH_PATH` points to the location you cloned this repository
 * `AWSSWITCH_KEYS` points to a yaml file containing your AWS keys
 * `AWSSWITCH_S3CFG` set to `true` if you want the script to update your `.s3cfg`
 * `AWSSWITCH_FOG` set to `true` if you want the script to update your `.fog`

#### `.profile` Example
```
export AWSSWITCH_PATH="${HOME}/src/awsswitch"
export AWSSWITCH_KEYS="${HOME}/.aws.yml"
export AWSSWITCH_S3CFG="true"
export AWSSWITCH_FOG="true"

. "${AWSSWITCH_PATH}/init.sh"
```

There is an additional component that is meant to be eval'd in the `PS1_COMMAND` context. This helps ensure that the AWS configuration is not only consistent across terminals but also that it may be visualized in the bash prompt. After this eval the `AWS_ACCOUNT` environment variable will be set to the name of the current AWS account.

#### eval Example

```
eval $("${AWSSWITCH_PATH}/awsswitch.sh" eval)
```

AWS Configuration
-----------------

The AWS configuration is stored in a simple yaml file. It is a list of id/secret pairs prefixed by a comment with the name of the AWS account. The comment is the name referenced when switching AWS accounts.

```
#my-aws
- id: My Key
  secret: My Secret
...
```

Script Actions
--------------

The script updates several pieces on a workstation. The minimalist form of which simply keeps various environment variables up to date. It may also optionally update other AWS related configuration files.

## Environment Variables

The script will keep the following environment variables updated accordingly.

* `AWS_ACCOUNT` The name of the AWS account
* `AWS_ACCESS_KEY_ID` AWS access key ID
* `AWS_ACCESS_KEY` AWS access key ID used by some older apps
* `AWS_SECRET_ACCESS_KEY` AWS secret access key
* `AWS_SECRET_KEY` AWS secret access key used by some older apps

## s3cfg

IF the script is updating the s3cfg a minimal configuration will be written containing only the base credentials. It will look as follows

```
[default]
access_key = ...
secret_key = ...
```

## fog

If the script is updating the fog config a minimal configuration will be written containing only the base credentials. It will look as follows

```
default:
   aws_access_key_id: ...
   aws_secret_access_key: ...
```

Usage
-----

Once you have initialized the script in your `.profile` usage is dead simple. Simply make use of the `awsswitch` command and reference one of the sets of AWS keys in your YAML configuration. This will then cause your current terminal context to be re-initialized. Other terminal contexts will _not_ be re-initialized until the next command concludes. This is where the inclusion of the `AWS_ACCOUNT` variable in your bash prompt is helpful as you can easily know which AWS account is currently active.