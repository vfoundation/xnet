#!/bin/bash

export CLOUD_FUNCTION_ZIP_FILE_NAME="datashare-toolkit-cloud-function.zip"
export USE_RUNTIME_CONFIG_WAITER=`curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/useRuntimeConfigWaiter -H "Metadata-Flavor: Google"`
echo $USE_RUNTIME_CONFIG_WAITER
export VM_STARTUP_SCRIPT=true

check_if_command_succeeded()
{
STATUS=$1
CMD=$2

if [ $STATUS -eq 0 ]; then
    echo "$CMD successful!"
else
    echo "$CMD failed."
    gcloud beta runtime-config configs variables set failure/my-instance failure --config-name $CONFIG_NAME
    exit 1;
fi
}
#{% raw %}
surround_with_quotes()
{
INPUT=$1
FORMATTED=""
IFS=', ' read -r -a LIST <<< "$INPUT"
LENGTH=$((${#LIST[*]} - 1))
for INDEX in "${!LIST[@]}"
do
    if [ $INDEX -ne $LENGTH ]; then
        FORMATTED="$FORMATTED\"${LIST[INDEX]}\","
    else
        FORMATTED="$FORMATTED\"${LIST[INDEX]}\""
    fi
done
echo $FORMATTED
}

format_data_producers_field()
{
DATA_PRODUCERS=$1
DATA_PRODUCERS_FORMATTED=""
COMMA=","
DOUBLE_QUOTE="\""

if [[ "$DATA_PRODUCERS" == *"$DOUBLE_QUOTE"* ]] && [[ "$DATA_PRODUCERS" == *"$COMMA"* ]]; then
    DATA_PRODUCERS=`surround_with_quotes $DATA_PRODUCERS`
    echo ${DATA_PRODUCERS:1:-1}
elif [[ "$DATA_PRODUCERS" == *"$COMMA"* ]]; then
    # convert comma delimitted string into an array
    DATA_PRODUCERS_FORMATTED=`surround_with_quotes $DATA_PRODUCERS`
    echo ${DATA_PRODUCERS_FORMATTED}
elif [[ "$DATA_PRODUCERS" == *"$DOUBLE_QUOTE"* ]]; then
    echo ${DATA_PRODUCERS}
else
    echo \"$DATA_PRODUCERS\"
fi
}
#{% endraw %}

if [ "$USE_RUNTIME_CONFIG_WAITER" = "true" ]; then
sudo apt-get -y update

echo "Using Runtime Config Waiter to install Datashare prerequisites..."
export CONFIG_NAME=`curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/configName -H "Metadata-Flavor: Google"`
echo $CONFIG_NAME

export IS_GIT_INSTALLED=`dpkg-query -W -f='${Status}\n' git`
if [ "$IS_GIT_INSTALLED" != "install ok installed" ]; then
    echo "Installing git."
    sudo apt-get install git -y
    check_if_command_succeeded $? "git install"
fi
export IS_ZIP_INSTALLED=`dpkg-query -W -f='${Status}\n' zip`
if [ "$IS_ZIP_INSTALLED" != "install ok installed" ]; then
    echo "Installing zip."
    sudo apt-get install zip -y
    check_if_command_succeeded $? "zip install"
fi
export IS_KUBECTL_INSTALLED=`dpkg-query -W -f='${Status}\n' kubectl`
if [ "$IS_KUBECTL_INSTALLED" != "install ok installed" ]; then
    echo "Installing kubectl."
    sudo apt-get install kubectl -y
    check_if_command_succeeded $? "kubectl install"
fi

cd /opt
echo "Cloning the Datashare repository..."
git clone https://github.com/GoogleCloudPlatform/datashare-toolkit.git
check_if_command_succeeded $? "git clone repo"

# checkout the Datashare release version specified in the Deployment package description
cd datashare-toolkit
check_if_command_succeeded $? "cd datashare-toolkit"

export DATASHARE_GIT_RELEASE_VERSION=`curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/datashareGitReleaseVersion -H "Metadata-Flavor: Google"`
echo $DATASHARE_GIT_RELEASE_VERSION
if [ "$DATASHARE_GIT_RELEASE_VERSION" != "master" ]; then
    echo "Using Datashare release version $DATASHARE_GIT_RELEASE_VERSION"
    git checkout -b $DATASHARE_GIT_RELEASE_VERSION # this should be changed to external metadata
fi

#cd ..
#export FUNCTION_SHARED="./datashare-toolkit/ingestion/batch/shared"
#if [ -d "${FUNCTION_SHARED}" ]; then
#    rm -R "${FUNCTION_SHARED}"
#fi

#echo "Copying shared module into function directory..."
#sudo cp -R datashare-toolkit/shared/ "${FUNCTION_SHARED}/"
#check_if_command_succeeded $? "sudo cp -R datashare-toolkit/shared/ ${FUNCTION_SHARED}/"

# linux
#echo 'Running on linux, performing package.json replacement for cds-shared module'
#sed -i -E 's/(file:)(\.\.\/\.\.\/)(shared)/\1\3/g' ./datashare-toolkit/ingestion/batch/package.json

# Zip the Cloud Function package
#export DATASHARE_BATCH_DIR="/opt/datashare-toolkit/ingestion/batch"
#if [ -d "$DATASHARE_BATCH_DIR" ]; then
#    cd /opt/datashare-toolkit/ingestion/batch
#    zip -r $CLOUD_FUNCTION_ZIP_FILE_NAME * .eslintrc.json configurationManager.js index.js package.json shared/
#else
#    echo "$DATASHARE_BATCH_DIR does not exist. Exiting"
#    gcloud beta runtime-config configs variables set failure/my-instance failure --config-name $CONFIG_NAME
#    exit 1;
#fi

#PROJECT=`curl http://metadata.google.internal/computeMetadata/v1/project/project-id -H "Metadata-Flavor: Google"`
export PROJECT_ID=$(gcloud config list --format 'value(core.project)')

# Enable APIs
echo "Enabling Cloud APIs"
gcloud services enable cloudbuild.googleapis.com # --quiet
gcloud services enable cloudfunctions.googleapis.com # --quiet
gcloud services enable iam.googleapis.com #--quiet
gcloud services enable run.googleapis.com #--quiet
gcloud services enable cloudresourcemanager.googleapis.com #--quiet
# gcloud services enable cloudcommerceprocurement.googleapis.com #--quiet
# Enabling APIs for GKE cluster
gcloud services enable container.googleapis.com containerregistry.googleapis.com #--quiet

# Upload Cloud Function to Google Cloud storage
gsutil cp $CLOUD_FUNCTION_ZIP_FILE_NAME gs://$PROJECT_ID-install-bucket/
check_if_command_succeeded $? "gsutil cp $CLOUD_FUNCTION_ZIP_FILE_NAME gs://$PROJECT_ID-install-bucket/"
# TODO - we should notify a new Waiter here so that the Cloud Function deployment can start at this point instead of waiting until the end.

# Update permission on Deployment Manager service account (cloudservices.gserviceaccount.com)
export PROJECT_NUMBER=`gcloud projects list --filter=$(gcloud config get-value project) --format="value(PROJECT_NUMBER)"`

#echo "Updating apt-get and updating gcloud..."
sudo apt-get -y --only-upgrade install google-cloud-sdk-skaffold kubectl google-cloud-sdk-anthos-auth google-cloud-sdk-minikube google-cloud-sdk google-cloud-sdk-app-engine-grpc google-cloud-sdk-kind google-cloud-sdk-pubsub-emulator google-cloud-sdk-app-engine-go google-cloud-sdk-firestore-emulator google-cloud-sdk-cloud-build-local google-cloud-sdk-datastore-emulator google-cloud-sdk-kpt google-cloud-sdk-app-engine-python google-cloud-sdk-spanner-emulator google-cloud-sdk-cbt google-cloud-sdk-bigtable-emulator google-cloud-sdk-app-engine-python-extras google-cloud-sdk-datalab google-cloud-sdk-app-engine-java
# sudo apt-get -y install google-cloud-sdk

# Create service account user for API
export CUSTOM_SA_NAME=`curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/apiServiceAccountName -H "Metadata-Flavor: Google"`
export CUSTOM_SA_DESCR="`curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/apiServiceAccountDesc -H "Metadata-Flavor: Google"`"
export CUSTOM_ROLE_NAME=`curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/apiCustomRole -H "Metadata-Flavor: Google"`
echo "Creating custom service account for Datashare API"
# OK if this displays an error if the service account already exists
gcloud iam service-accounts create $CUSTOM_SA_NAME --display-name="$CUSTOM_SA_DESCR" --format=disable
echo "Creating custom role for Datashare API"
# OK if this displays an error if the role already exists
gcloud iam roles create $CUSTOM_ROLE_NAME --project=$PROJECT_ID --file=/opt/datashare-toolkit/api/config/ds-api-mgr-role-definition.yaml --format=disable
echo "Creating the policy binding between the new SA and the custom role"
gcloud projects add-iam-policy-binding $PROJECT_ID --member=serviceAccount:$CUSTOM_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com --role="projects/$PROJECT_ID/roles/$CUSTOM_ROLE_NAME" --format=disable

# Setup GKE cluster
export DEPLOY_API_TO_GKE=`curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/deployApiToGke -H "Metadata-Flavor: Google"`
export GCE_SERVICE_ACCOUNT=`curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/gceServiceAccount -H "Metadata-Flavor: Google"`
if [ "$DEPLOY_API_TO_GKE" = "true" ]; then
    # This is executing from the VM's startup script
    if [ "$VM_STARTUP_SCRIPT" = true ]; then
        export KUBECONFIG="/opt/.kube/config"
    else
    # This is executing from Cloud Shell
        export KUBECONFIG="~/.kube/config"
    fi
    export GKE_ZONE=`curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/gkeZone -H "Metadata-Flavor: Google"`
    export GKE_CLUSTER_NAME=`curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/gkeClusterName -H "Metadata-Flavor: Google"`
    export ISTIO_EXCLUDE_IP_RANGES=`curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/istioExcludeIpRanges -H "Metadata-Flavor: Google"`

    echo "Getting the cluster credentials"
    gcloud container clusters get-credentials $GKE_CLUSTER_NAME --zone $GKE_ZONE
    echo "Setting up GKE cluster for Cloud Run."
    echo "Creating the cluster role binding."
    #kubectl create clusterrolebinding cluster-admin-binding \
    #    --clusterrole cluster-admin \
    #    --user ${PROJECT_NUMBER}-compute@developer.gserviceaccount.com
    kubectl create clusterrolebinding cluster-admin-binding \
        --clusterrole cluster-admin \
        --user ${GCE_SERVICE_ACCOUNT}

    export ISTIO_PACKAGE=$(kubectl -n gke-system get deployments istio-pilot \
        -o jsonpath="{.spec.template.spec.containers[0].image}" | \
        cut -d':' -f2)
    echo "Istio Package is " + $ISTIO_PACKAGE
    export ISTIO_VERSION=$(echo $ISTIO_PACKAGE | cut -d'-' -f1)
    echo "Istio version is " + $ISTIO_VERSION

    echo "Fetching Istio release."
    gsutil -m cp gs://istio-release/releases/${ISTIO_VERSION}/istio-${ISTIO_VERSION}-linux.tar.gz - | tar zx

    if ! helm &> /dev/null
    then
        echo "Installing Helm"
        curl https://helm.baltorepo.com/organization/signing.asc | sudo apt-key add -
        sudo apt-get install apt-transport-https --yes
        echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
        sudo apt-get update
        sudo apt-get install helm
        echo "Helm installed."
    fi

    echo "Building the Helm template"
    /usr/sbin/helm template \
        --namespace gke-system \
        --set global.hub=gcr.io/gke-release/asm \
        --set global.tag=$ISTIO_PACKAGE \
        --set pilot.enabled=false \
        --set global.proxy.excludeIPRanges=${ISTIO_EXCLUDE_IP_RANGES} \
        --set security.enabled=true \
        --set sidecarInjectorWebhook.enabled=true \
        --set sidecarInjectorWebhook.rewriteAppHTTPProbe=true \
        --values istio-${ISTIO_VERSION}/install/kubernetes/helm/istio/values-istio-minimal.yaml \
        istio-${ISTIO_VERSION}/install/kubernetes/helm/istio \
        > istio-${ISTIO_VERSION}-sidecar-injector-webhook.yaml

    echo "Installing Istio into the cluster."
    kubectl apply -f istio-${ISTIO_VERSION}-sidecar-injector-webhook.yaml
    echo "Checking the rollout status."
    kubectl rollout status deploy istio-sidecar-injector -n gke-system

    export NAMESPACE=datashare-apis
    kubectl create namespace $NAMESPACE
    export SERVICE_ACCOUNT_NAME=ds-api-mgr
    export KSA_NAME=$SERVICE_ACCOUNT_NAME
    echo "Creating Kubernets service account."
    kubectl create serviceaccount $KSA_NAME -n $NAMESPACE;

    echo "Binding the GCP service account to the K8S service account"
    gcloud iam service-accounts add-iam-policy-binding \
        --role roles/iam.workloadIdentityUser \
        --member "serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${KSA_NAME}]" ${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com

    echo "Annotating the service account."
    kubectl annotate serviceaccount $KSA_NAME -n $NAMESPACE iam.gke.io/gcp-service-account=${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com
    echo "Labeling the namespace."
    kubectl label namespace $NAMESPACE istio-injection=enabled

    # Apply Authentication policy
    echo "Istio - Applying Authentication policies."
    export PROJECT_ID=$(gcloud config list --format 'value(core.project)')
    cat /opt/datashare-toolkit/api/v1alpha/istio-manifests/1.4/authn/* | envsubst | kubectl apply -f -
    check_if_command_succeeded $? "cat /opt/datashare-toolkit/api/v1alpha/istio-manifests/1.4/authn/* | envsubst | kubectl apply -f -"
    export DATA_PRODUCERS_RAW=`curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/dataProducers -H "Metadata-Flavor: Google"`
    export DATA_PRODUCERS=`format_data_producers_field $DATA_PRODUCERS_RAW`
    # echo "DATA_PRODUCERS=$DATA_PRODUCERS"
    export OAUTH_CLIENT_ID=`curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/oauthClientId -H "Metadata-Flavor: Google"`
    # echo "OAUTH_CLIENT_ID=$OAUTH_CLIENT_ID"
    # Apply Authorization policy
    echo "Istio - Applying Authorization policies."
    cat /opt/datashare-toolkit/api/v1alpha/istio-manifests/1.4/authz/* | envsubst | kubectl apply -f -
    check_if_command_succeeded $? "cat /opt/datashare-toolkit/api/v1alpha/istio-manifests/1.4/authz/* | envsubst | kubectl apply -f -"

    echo "GKE setup complete."
fi

# Notify Listener
echo "Notifiying Waiter that this VM startup script is complete..."
gcloud beta runtime-config configs variables set success/my-instance success --config-name $CONFIG_NAME
echo "VM startup-script finished!"

else
echo "Will not use Google Cloud Runtime Config Waiter to install prerequisites."
echo "You must install the prerequisites before you launch this service. Execute the install-datashare-prerequisites.sh file from Cloud Shell."
echo "The file is located in the datashare-toolkit/marketplace folder."
echo "VM startup-script finished!"
fi
