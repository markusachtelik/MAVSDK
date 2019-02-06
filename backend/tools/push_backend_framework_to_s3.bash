#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAT_BIN_DIR=${SCRIPT_DIR}/../../build/fat_bin

INFO_PLIST=${FAT_BIN_DIR}/backend.framework/Info.plist
CURRENT_VERSION=`grep -A 1 "<key>CFBundleShortVersionString</key>" "${INFO_PLIST}" | grep -o "<string>.*<\/string>" | sed 's/<\(\/*\)string>//g'`

grep -qo '^[0-9]\+\.[0-9]\+\.[0-9]\+$' <<< ${CURRENT_VERSION} || (echo "error: invalid version number for Info.plist (${INFO_PLIST}): '${CURRENT_VERSION}' (expecting [0-9]+\.[0-9]+\.[0-9]+)" && echo "Not deploying." && exit 1)

if [ -z ${CURRENT_VERSION} ]
then
    echo "Invalid CFBundleShortVersionString in ${INFO_PLIST}"
    exit 1
fi

## Push release to AWS
aws s3 ls dronecode-sdk/dronecode-backend-${CURRENT_VERSION}.zip >/dev/null && echo "Trying to overwrite an existing release! Aborting..." && exit 1

aws s3 cp ${FAT_BIN_DIR}/dronecode-backend.zip s3://dronecode-sdk/dronecode-backend-latest.zip
aws s3api put-object-acl --bucket dronecode-sdk --key dronecode-backend-latest.zip --acl public-read

aws s3 cp ${FAT_BIN_DIR}/dronecode-backend.zip s3://dronecode-sdk/dronecode-backend-${CURRENT_VERSION}.zip
aws s3api put-object-acl --bucket dronecode-sdk --key dronecode-backend-${CURRENT_VERSION}.zip --acl public-read

# Update backend.json on AWS
TMP_DIR=${TMP_DIR:-"$(mktemp -d)"}
curl -s https://s3.eu-central-1.amazonaws.com/dronecode-sdk/backend.json -o ${TMP_DIR}/backend.json
sed -i "" '$ d' ${TMP_DIR}/backend.json
sed -i "" '$s/$/\,/' ${TMP_DIR}/backend.json
echo "    \"${CURRENT_VERSION}\": \"https://s3.eu-central-1.amazonaws.com/dronecode-sdk/dronecode-backend-${CURRENT_VERSION}.zip\"" >> ${TMP_DIR}/backend.json
echo "}" >> ${TMP_DIR}/backend.json

aws s3 cp ${TMP_DIR}/backend.json s3://dronecode-sdk/backend.json
aws s3api put-object-acl --bucket dronecode-sdk --key backend.json --acl public-read
