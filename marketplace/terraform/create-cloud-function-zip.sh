#!/bin/bash

cd /tmp
rm -rf datashare-toolkit
echo "Cloning the Datashare repository..."
git clone https://github.com/GoogleCloudPlatform/datashare-toolkit.git
export CLOUD_FUNCTION_ZIP_FILE_NAME="datashare-toolkit-cloud-function.zip"
export DATASHARE_GIT_RELEASE_VERSION="0.7.2"
echo $DATASHARE_GIT_RELEASE_VERSION
if [ "$DATASHARE_GIT_RELEASE_VERSION" != "master" ]; then
    echo "Using Datashare release version $DATASHARE_GIT_RELEASE_VERSION"
    git checkout -b $DATASHARE_GIT_RELEASE_VERSION # this should be changed to external metadata
fi

cd ..
export FUNCTION_SHARED="/tmp/datashare-toolkit/ingestion/batch/shared"
if [ -d "${FUNCTION_SHARED}" ]; then
    rm -R "${FUNCTION_SHARED}"
fi

echo "Copying shared module into function directory..."
cp -R /tmp/datashare-toolkit/shared/ "${FUNCTION_SHARED}/"
#check_if_command_succeeded $? "sudo cp -R datashare-toolkit/shared/ ${FUNCTION_SHARED}/"

# linux
echo 'Running on linux, performing package.json replacement for cds-shared module'
sed -i -E 's/(file:)(\.\.\/\.\.\/)(shared)/\1\3/g' /tmp/datashare-toolkit/ingestion/batch/package.json

# Zip the Cloud Function package
export DATASHARE_BATCH_DIR="/tmp/datashare-toolkit/ingestion/batch"
if [ -d "$DATASHARE_BATCH_DIR" ]; then
    cd /tmp/datashare-toolkit/ingestion/batch
    zip -r $CLOUD_FUNCTION_ZIP_FILE_NAME .eslintrc.json configurationManager.js index.js package.json shared/
else
    echo "$DATASHARE_BATCH_DIR does not exist. Exiting"
    gcloud beta runtime-config configs variables set failure/my-instance failure --config-name $CONFIG_NAME
    exit 1;
fi
