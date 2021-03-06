[Back to Datashare](./README.md)

# Overview
Data Producers are users that should have administrative access to the Datashare UI. To modify the list of Data Producers for an existing setup, you must edit the when condition of the [allow-data-producers](./api/v1/istio-manifests/1.4/authz/allow-data-producers-policy.yaml) authorization policy.

# Updating the Authorization Policy
Run the following command to edit the authorization policy.

```
CLUSTER=datashare

# Replace with the zone
export ZONE=us-central1-a;

gcloud config set compute/zone $ZONE

export NAMESPACE=datashare-apis
kubectl edit authorizationpolicy.security.istio.io/allow-data-producers -n "$NAMESPACE"
```

Scroll to the bottom and you'll see a when condition that looks like this:

```
    when:
    - key: request.auth.claims[email]
      values:
      - '*@google.com'
```

Modify the values portion to include the list of domains or users and save. For more information see the Istio documentation: [Authorization Policies](https://istio.io/v1.4/docs/reference/config/security/authorization-policy/).

To confirm and view the changes, you can run this:

```
kubectl describe authorizationpolicy.security.istio.io/allow-data-producers -n "$NAMESPACE"
```

Once the ISTIO policies have been updated, update the API environmental variable.

```
export NAMESPACE=datashare-apis
CLUSTER=datashare
export ZONE=us-central1-a;

gcloud run services update ds-api \
  --platform gke \
  --namespace $NAMESPACE \
  --cluster $CLUSTER \
  --cluster-location $ZONE \
  --update-env-vars=DATA_PRODUCERS="*@google.com"
```