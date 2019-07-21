#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail


CREATE=0
COPY_TO_KUBE=0
TEST=0
TARGET_FOLDER="/tmp/kube"
CONFIG_FILE="$TARGET_FOLDER/config"

while getopts "a:cf:kt" opt; do
    case "${opt}" in
        a)
        	ACCOUNT=$OPTARG
            ;;
            
        c)
        	CREATE=1
            ;;
            
        f)
			CONFIG_FILE="$TARGET_FOLDER/$OPTARG"
        	;;
        	
        k)
			COPY_TO_KUBE=1
        	;;

        t)
			TEST=1
        	;;

		\?)
      		echo "Invalid option: -$OPTARG" >&2
      		exit 1
      		;;
          esac
done
shift $((OPTIND-1))


function createServiceAccount {
    mkdir -p "$TARGET_FOLDER"
    rm "$TARGET_FOLDER"/* 2>/dev/null || rc=$?
    
    if [[ "$CREATE" -eq 1 ]]
    then
	    kubectl create sa "$ACCOUNT"
		kubectl create clusterrolebinding "cluster-admin-$ACCOUNT" --clusterrole=cluster-admin --serviceaccount="$POD_NAMESPACE:$ACCOUNT"
	fi
}

function extractSecrets {
    SECRET=$(kubectl get sa "$ACCOUNT" -o json | jq -r .secrets[].name)
    kubectl get secret "$SECRET" -o json | jq -r '.data["ca.crt"]' | base64 -d > "$TARGET_FOLDER/ca.crt"
    TOKEN=$(kubectl get secret "$SECRET" -o json | jq -r '.data["token"]' | base64 -d)
}


function createConfig {
	CLUSTER_NAME="kubernetes"
    ENDPOINT="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT"

    kubectl config set-cluster "$CLUSTER_NAME" \
    --kubeconfig="$CONFIG_FILE" \
    --server="$ENDPOINT" \
    --certificate-authority="$TARGET_FOLDER/ca.crt" \
    --embed-certs=true

    kubectl config set-credentials \
    "$ACCOUNT-$POD_NAMESPACE-$CLUSTER_NAME" \
    --kubeconfig="$CONFIG_FILE" \
    --token="$TOKEN"

    kubectl config set-context \
    "$ACCOUNT-$POD_NAMESPACE-$CLUSTER_NAME" \
    --kubeconfig="$CONFIG_FILE" \
    --cluster="$CLUSTER_NAME" \
    --user="$ACCOUNT-$POD_NAMESPACE-$CLUSTER_NAME" \
    --namespace="$POD_NAMESPACE"

    kubectl config use-context "$ACCOUNT-$POD_NAMESPACE-$CLUSTER_NAME" \
    --kubeconfig="${CONFIG_FILE}"
}

createServiceAccount
extractSecrets
createConfig

if [[ "$TEST" -eq 1 ]]
then
	KUBECONFIG="$CONFIG_FILE" kubectl get pods
fi

if [[ "$COPY_TO_KUBE" -eq 1 ]]
then
	mkdir -p ~/.kube
	cp "$CONFIG_FILE" ~/.kube/config
fi
