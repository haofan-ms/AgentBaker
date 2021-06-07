#!/bin/bash
NODE_INDEX=$(hostname | tail -c 2)
NODE_NAME=$(hostname)
if [[ $OS == $COREOS_OS_NAME ]]; then
    PRIVATE_IP=$(ip a show eth0 | grep -Po 'inet \K[\d.]+')
else
    PRIVATE_IP=$(hostname -I | cut -d' ' -f1)
fi
ETCD_PEER_URL="https://${PRIVATE_IP}:2380"
ETCD_CLIENT_URL="https://${PRIVATE_IP}:2379"

configureAdminUser(){
    chage -E -1 -I -1 -m 0 -M 99999 "${ADMINUSER}"
    chage -l "${ADMINUSER}"
}

configureSecrets(){
    APISERVER_PRIVATE_KEY_PATH="/etc/kubernetes/certs/apiserver.key"
    touch "${APISERVER_PRIVATE_KEY_PATH}"
    chmod 0600 "${APISERVER_PRIVATE_KEY_PATH}"
    chown root:root "${APISERVER_PRIVATE_KEY_PATH}"

    CA_PRIVATE_KEY_PATH="/etc/kubernetes/certs/ca.key"
    touch "${CA_PRIVATE_KEY_PATH}"
    chmod 0600 "${CA_PRIVATE_KEY_PATH}"
    chown root:root "${CA_PRIVATE_KEY_PATH}"

    ETCD_SERVER_PRIVATE_KEY_PATH="/etc/kubernetes/certs/etcdserver.key"
    touch "${ETCD_SERVER_PRIVATE_KEY_PATH}"
    chmod 0600 "${ETCD_SERVER_PRIVATE_KEY_PATH}"
    if [[ -z "${COSMOS_URI}" ]]; then
      chown etcd:etcd "${ETCD_SERVER_PRIVATE_KEY_PATH}"
    fi

    ETCD_CLIENT_PRIVATE_KEY_PATH="/etc/kubernetes/certs/etcdclient.key"
    touch "${ETCD_CLIENT_PRIVATE_KEY_PATH}"
    chmod 0600 "${ETCD_CLIENT_PRIVATE_KEY_PATH}"
    chown root:root "${ETCD_CLIENT_PRIVATE_KEY_PATH}"

    ETCD_PEER_PRIVATE_KEY_PATH="/etc/kubernetes/certs/etcdpeer${NODE_INDEX}.key"
    touch "${ETCD_PEER_PRIVATE_KEY_PATH}"
    chmod 0600 "${ETCD_PEER_PRIVATE_KEY_PATH}"
    if [[ -z "${COSMOS_URI}" ]]; then
      chown etcd:etcd "${ETCD_PEER_PRIVATE_KEY_PATH}"
    fi

    ETCD_SERVER_CERTIFICATE_PATH="/etc/kubernetes/certs/etcdserver.crt"
    touch "${ETCD_SERVER_CERTIFICATE_PATH}"
    chmod 0644 "${ETCD_SERVER_CERTIFICATE_PATH}"
    chown root:root "${ETCD_SERVER_CERTIFICATE_PATH}"

    ETCD_CLIENT_CERTIFICATE_PATH="/etc/kubernetes/certs/etcdclient.crt"
    touch "${ETCD_CLIENT_CERTIFICATE_PATH}"
    chmod 0644 "${ETCD_CLIENT_CERTIFICATE_PATH}"
    chown root:root "${ETCD_CLIENT_CERTIFICATE_PATH}"

    ETCD_PEER_CERTIFICATE_PATH="/etc/kubernetes/certs/etcdpeer${NODE_INDEX}.crt"
    touch "${ETCD_PEER_CERTIFICATE_PATH}"
    chmod 0644 "${ETCD_PEER_CERTIFICATE_PATH}"
    chown root:root "${ETCD_PEER_CERTIFICATE_PATH}"

    set +x
    echo "${APISERVER_PRIVATE_KEY}" | base64 --decode > "${APISERVER_PRIVATE_KEY_PATH}"
    echo "${CA_PRIVATE_KEY}" | base64 --decode > "${CA_PRIVATE_KEY_PATH}"
    echo "${ETCD_SERVER_PRIVATE_KEY}" | base64 --decode > "${ETCD_SERVER_PRIVATE_KEY_PATH}"
    echo "${ETCD_CLIENT_PRIVATE_KEY}" | base64 --decode > "${ETCD_CLIENT_PRIVATE_KEY_PATH}"
    echo "${ETCD_PEER_KEY}" | base64 --decode > "${ETCD_PEER_PRIVATE_KEY_PATH}"
    echo "${ETCD_SERVER_CERTIFICATE}" | base64 --decode > "${ETCD_SERVER_CERTIFICATE_PATH}"
    echo "${ETCD_CLIENT_CERTIFICATE}" | base64 --decode > "${ETCD_CLIENT_CERTIFICATE_PATH}"
    echo "${ETCD_PEER_CERT}" | base64 --decode > "${ETCD_PEER_CERTIFICATE_PATH}"
}

customizeK8s() {
    mkdir -p /etc/kubernetes/pki/etcd
    cp -p /etc/kubernetes/certs/ca.crt /etc/kubernetes/pki/ca.crt
    cp -p /etc/kubernetes/pki/sa.key /etc/kubernetes/pki/sa.pub
    cp -p /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/front-proxy-ca.crt
    cp -p /etc/kubernetes/pki/ca.key /etc/kubernetes/pki/front-proxy-ca.key
    cp -p /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/etcd/ca.crt
    cp -p /etc/kubernetes/pki/ca.key /etc/kubernetes/pki/etcd/ca.key

    FIRST_MASTER_NODE=true
    echo $NODE_NAME | grep -E '*-0$' > /dev/null
    if [[ "$?" != "0" ]]; then
        FIRST_MASTER_NODE=false
    fi
    if [[ -d /var/lib/etcddisk/etcd/member/ ]]; then
        FIRST_MASTER_NODE=false
    fi

    if [ "${FIRST_MASTER_NODE}" = true ]; then
        retrycmd_if_failure 150 10 300 kubeadm init phase certs all --config /etc/kubernetes/kubeadm-config.yaml -v 9
        retrycmd_if_failure 150 10 300 kubeadm init phase kubeconfig all --config /etc/kubernetes/kubeadm-config.yaml -v 9
        retrycmd_if_failure 150 10 300 kubeadm init phase control-plane all --config /etc/kubernetes/kubeadm-config.yaml -v 9
        sed -i 's|imagePullPolicy: IfNotPresent|imagePullPolicy: IfNotPresent\n    env:\n    - name: AZURE_ENVIRONMENT_FILEPATH\n      value: \/etc\/kubernetes\/azurestackcloud.json|' /etc/kubernetes/manifests/kube-controller-manager.yaml
        retrycmd_if_failure 150 10 300 kubeadm init --config /etc/kubernetes/kubeadm-config.yaml --skip-phases=control-plane,certs,kubeconfig --ignore-preflight-errors=all  -v 9

        cat << EOF | retrycmd_if_failure 5 10 30 kubectl apply --kubeconfig /etc/kubernetes/admin.conf -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: nodegroup
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:nodes
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:node
EOF

        retrycmd_if_failure_no_stats 5 10 30 kubectl get deploy coredns -n kube-system --kubeconfig /etc/kubernetes/admin.conf -o yaml > /etc/kubernetes/kustomize/coredns/deployment.yaml
        retrycmd_if_failure_no_stats 5 10 30 kubectl get service coredns -n kube-system --kubeconfig /etc/kubernetes/admin.conf -o yaml > /etc/kubernetes/kustomize/coredns/service.yaml
        retrycmd_if_failure_no_stats 5 10 30 kubectl kustomize /etc/kubernetes/kustomize/coredns | kubectl apply --kubeconfig /etc/kubernetes/admin.conf -f -

        for ADDON in https://jadarsiearchive.blob.core.windows.net/pub/ip-masq-agent-azure.yaml https://jiaxsongarchive.blob.core.windows.net/pub/kube-state-metrics.yaml https://jiaxsongarchive.blob.core.windows.net/pub/coredns-custom-configmap.yaml https://jiaxsongarchive.blob.core.windows.net/pub/azuredisk-csi-driver-deployment.yaml https://jiaxsongarchive.blob.core.windows.net/pub/storage-classes.yaml https://jiaxsongarchive.blob.core.windows.net/pub/kube-metrics-server.yaml; do
            retrycmd_if_failure 5 10 30 kubectl apply -f ${ADDON} --kubeconfig /etc/kubernetes/admin.conf
        done
    else
        retrycmd_if_failure 150 10 300 kubeadm join phase control-plane-prepare all --config /etc/kubernetes/kubeadm-config.yaml -v 9
        sed -i 's|imagePullPolicy: IfNotPresent|imagePullPolicy: IfNotPresent\n    env:\n    - name: AZURE_ENVIRONMENT_FILEPATH\n      value: \/etc\/kubernetes\/azurestackcloud.json|' /etc/kubernetes/manifests/kube-controller-manager.yaml
        retrycmd_if_failure 150 10 300 kubeadm join phase kubelet-start --config /etc/kubernetes/kubeadm-config.yaml -v 9
        retrycmd_if_failure 150 10 300 kubeadm join phase control-plane-join all --config /etc/kubernetes/kubeadm-config.yaml -v 9
    fi

    # TODO ASH Delete
    mkdir -p /home/${ADMINUSER}/.kube
    cp /etc/kubernetes/admin.conf /home/${ADMINUSER}/.kube/config
    chown ${ADMINUSER}:${ADMINUSER} /home/${ADMINUSER}/.kube
    chown ${ADMINUSER}:${ADMINUSER} /home/${ADMINUSER}/.kube/config
}

ensureRPC() {
    systemctlEnableAndStart rpcbind || exit $ERR_SYSTEMCTL_START_FAIL
    systemctlEnableAndStart rpc-statd || exit $ERR_SYSTEMCTL_START_FAIL
}

ensureAuditD() {
  if [[ "${AUDITD_ENABLED}" == true ]]; then
    systemctlEnableAndStart auditd || exit $ERR_SYSTEMCTL_START_FAIL
  else
    if apt list --installed | grep 'auditd'; then
      apt_get_purge 20 30 120 auditd &
    fi
  fi
}

configureKubeletServerCert() {
    KUBELET_SERVER_PRIVATE_KEY_PATH="/etc/kubernetes/certs/kubeletserver.key"
    KUBELET_SERVER_CERT_PATH="/etc/kubernetes/certs/kubeletserver.crt"

    openssl genrsa -out $KUBELET_SERVER_PRIVATE_KEY_PATH 2048
    openssl req -new -x509 -days 7300 -key $KUBELET_SERVER_PRIVATE_KEY_PATH -out $KUBELET_SERVER_CERT_PATH -subj "/CN=${NODE_NAME}"
}

configureK8s() {
    KUBELET_PRIVATE_KEY_PATH="/etc/kubernetes/certs/client.key"
    touch "${KUBELET_PRIVATE_KEY_PATH}"
    chmod 0600 "${KUBELET_PRIVATE_KEY_PATH}"
    chown root:root "${KUBELET_PRIVATE_KEY_PATH}"

    APISERVER_PUBLIC_KEY_PATH="/etc/kubernetes/certs/apiserver.crt"
    touch "${APISERVER_PUBLIC_KEY_PATH}"
    chmod 0644 "${APISERVER_PUBLIC_KEY_PATH}"
    chown root:root "${APISERVER_PUBLIC_KEY_PATH}"

    AZURE_JSON_PATH="/etc/kubernetes/azure.json"
    touch "${AZURE_JSON_PATH}"
    chmod 0600 "${AZURE_JSON_PATH}"
    chown root:root "${AZURE_JSON_PATH}"

    set +x
    echo "${KUBELET_PRIVATE_KEY}" | base64 --decode > "${KUBELET_PRIVATE_KEY_PATH}"
    echo "${APISERVER_PUBLIC_KEY}" | base64 --decode > "${APISERVER_PUBLIC_KEY_PATH}"
    
    SERVICE_PRINCIPAL_CLIENT_SECRET=${SERVICE_PRINCIPAL_CLIENT_SECRET//\\/\\\\}
    SERVICE_PRINCIPAL_CLIENT_SECRET=${SERVICE_PRINCIPAL_CLIENT_SECRET//\"/\\\"}
    cat << EOF > "${AZURE_JSON_PATH}"
{
    "cloud": "AzurePublicCloud",
    "tenantId": "${TENANT_ID}",
    "subscriptionId": "${SUBSCRIPTION_ID}",
    "aadClientId": "${SERVICE_PRINCIPAL_CLIENT_ID}",
    "aadClientSecret": "${SERVICE_PRINCIPAL_CLIENT_SECRET}",
    "resourceGroup": "${RESOURCE_GROUP}",
    "location": "${LOCATION}",
    "vmType": "${VM_TYPE}",
    "subnetName": "${SUBNET}",
    "securityGroupName": "${NETWORK_SECURITY_GROUP}",
    "vnetName": "${VIRTUAL_NETWORK}",
    "vnetResourceGroup": "${VIRTUAL_NETWORK_RESOURCE_GROUP}",
    "routeTableName": "${ROUTE_TABLE}",
    "primaryAvailabilitySetName": "${PRIMARY_AVAILABILITY_SET}",
    "primaryScaleSetName": "${PRIMARY_SCALE_SET}",
    "cloudProviderBackoffMode": "${CLOUDPROVIDER_BACKOFF_MODE}",
    "cloudProviderBackoff": ${CLOUDPROVIDER_BACKOFF},
    "cloudProviderBackoffRetries": ${CLOUDPROVIDER_BACKOFF_RETRIES},
    "cloudProviderBackoffExponent": ${CLOUDPROVIDER_BACKOFF_EXPONENT},
    "cloudProviderBackoffDuration": ${CLOUDPROVIDER_BACKOFF_DURATION},
    "cloudProviderBackoffJitter": ${CLOUDPROVIDER_BACKOFF_JITTER},
    "cloudProviderRateLimit": ${CLOUDPROVIDER_RATELIMIT},
    "cloudProviderRateLimitQPS": ${CLOUDPROVIDER_RATELIMIT_QPS},
    "cloudProviderRateLimitBucket": ${CLOUDPROVIDER_RATELIMIT_BUCKET},
    "cloudProviderRateLimitQPSWrite": ${CLOUDPROVIDER_RATELIMIT_QPS_WRITE},
    "cloudProviderRateLimitBucketWrite": ${CLOUDPROVIDER_RATELIMIT_BUCKET_WRITE},
    "useManagedIdentityExtension": ${USE_MANAGED_IDENTITY_EXTENSION},
    "userAssignedIdentityID": "${USER_ASSIGNED_IDENTITY_ID}",
    "useInstanceMetadata": ${USE_INSTANCE_METADATA},
    "loadBalancerSku": "${LOAD_BALANCER_SKU}",
    "disableOutboundSNAT": ${LOAD_BALANCER_DISABLE_OUTBOUND_SNAT},
    "excludeMasterFromStandardLB": ${EXCLUDE_MASTER_FROM_STANDARD_LB},
    "providerVaultName": "${KMS_PROVIDER_VAULT_NAME}",
    "maximumLoadBalancerRuleCount": ${MAXIMUM_LOADBALANCER_RULE_COUNT},
    "providerKeyName": "k8s",
    "providerKeyVersion": ""
}
EOF
    set -x
    if [[ "${CLOUDPROVIDER_BACKOFF_MODE}" = "v2" ]]; then
        sed -i "/cloudProviderBackoffExponent/d" /etc/kubernetes/azure.json
        sed -i "/cloudProviderBackoffJitter/d" /etc/kubernetes/azure.json
    fi

    configureKubeletServerCert
}

configureCNI() {
    
    retrycmd_if_failure 120 5 25 modprobe br_netfilter || exit $ERR_MODPROBE_FAIL
    echo -n "br_netfilter" > /etc/modules-load.d/br_netfilter.conf
    configureCNIIPTables
    
}

customizeCNI() {
}

configureCNIIPTables() {
    if [[ "${NETWORK_PLUGIN}" = "azure" ]]; then
        jq '.plugins[0].ipam.environment = "mas"' $CNI_BIN_DIR/10-azure.conflist > $CNI_CONFIG_DIR/10-azure.conflist
        rm -f $CNI_BIN_DIR/10-azure.conflist
        chmod 600 $CNI_CONFIG_DIR/10-azure.conflist
        if [[ "${NETWORK_POLICY}" == "calico" ]]; then
          sed -i 's#"mode":"bridge"#"mode":"transparent"#g' $CNI_CONFIG_DIR/10-azure.conflist
        elif [[ "${NETWORK_POLICY}" == "" || "${NETWORK_POLICY}" == "none" ]] && [[ "${NETWORK_MODE}" == "transparent" ]]; then
          sed -i 's#"mode":"bridge"#"mode":"transparent"#g' $CNI_CONFIG_DIR/10-azure.conflist
        fi
        /sbin/ebtables -t nat --list
    fi
}

disable1804SystemdResolved() {
    ls -ltr /etc/resolv.conf
    cat /etc/resolv.conf
    echo "Disable1804SystemdResolved is false. Skipping."
}

configureAzureStackInterfaces() {
    NETWORK_INTERFACES_FILE="/etc/kubernetes/network_interfaces.json"
    AZURE_CNI_CONFIG_FILE="/etc/kubernetes/interfaces.json"
    AZURESTACK_ENVIRONMENT_JSON_PATH="/etc/kubernetes/AzureStackCloud.json"
    NETWORK_API_VERSION="2018-08-01"

    SERVICE_MANAGEMENT_ENDPOINT=$(jq -r '.serviceManagementEndpoint' ${AZURESTACK_ENVIRONMENT_JSON_PATH}) #
    ACTIVE_DIRECTORY_ENDPOINT=$(jq -r '.activeDirectoryEndpoint' ${AZURESTACK_ENVIRONMENT_JSON_PATH}) #
    RESOURCE_MANAGER_ENDPOINT=$(jq -r '.resourceManagerEndpoint' ${AZURESTACK_ENVIRONMENT_JSON_PATH}) #

    # if [[ ${IDENTITY_SYSTEM,,} == "adfs" ]]; then #
    TOKEN_URL="${ACTIVE_DIRECTORY_ENDPOINT}/oauth2/token"
    # else
    #     TOKEN_URL="${ACTIVE_DIRECTORY_ENDPOINT}${TENANT_ID}/oauth2/token"
    # fi

    echo "Generating token for Azure Resource Manager"
    echo "------------------------------------------------------------------------"
    echo "Parameters"
    echo "------------------------------------------------------------------------"
    echo "SERVICE_PRINCIPAL_CLIENT_ID:     ..."
    echo "SERVICE_PRINCIPAL_CLIENT_SECRET: ..."
    echo "SERVICE_MANAGEMENT_ENDPOINT:     ${SERVICE_MANAGEMENT_ENDPOINT}"
    echo "ACTIVE_DIRECTORY_ENDPOINT:       ${ACTIVE_DIRECTORY_ENDPOINT}"
    echo "TENANT_ID:                       ${TENANT_ID}"
    echo "IDENTITY_SYSTEM:                 ${IDENTITY_SYSTEM}"
    echo "TOKEN_URL:                       ${TOKEN_URL}"
    echo "------------------------------------------------------------------------"

    TOKEN=$(curl -s --retry 5 --retry-delay 10 --max-time 60 -f -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=client_credentials" \
        -d "client_id=${SERVICE_PRINCIPAL_CLIENT_ID}" \
        --data-urlencode "client_secret=${SERVICE_PRINCIPAL_CLIENT_SECRET}" \
        --data-urlencode "resource=${SERVICE_MANAGEMENT_ENDPOINT}" \
        ${TOKEN_URL} | jq '.access_token' | xargs)

    if [[ -z ${TOKEN} ]]; then
        echo "Error generating token for Azure Resource Manager"
        exit 120
    fi

    echo "Fetching network interface configuration for node"
    echo "------------------------------------------------------------------------"
    echo "Parameters"
    echo "------------------------------------------------------------------------"
    echo "RESOURCE_MANAGER_ENDPOINT: $RESOURCE_MANAGER_ENDPOINT"
    echo "SUBSCRIPTION_ID:           $SUBSCRIPTION_ID"
    echo "RESOURCE_GROUP:            $RESOURCE_GROUP"
    echo "NETWORK_API_VERSION:       $NETWORK_API_VERSION"
    echo "------------------------------------------------------------------------"

    curl -s --retry 5 --retry-delay 10 --max-time 60 -f -X GET \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        "${RESOURCE_MANAGER_ENDPOINT}subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Network/networkInterfaces?api-version=${NETWORK_API_VERSION}" > ${NETWORK_INTERFACES_FILE}

    if [[ ! -s ${NETWORK_INTERFACES_FILE} ]]; then
        echo "Error fetching network interface configuration for node"
        exit 121
    fi

    echo "Generating Azure CNI interface file"

    mapfile -t local_interfaces < <(cat /sys/class/net/*/address | tr -d : | sed 's/.*/\U&/g')

    SDN_INTERFACES=$(jq ".value | map(select(.properties != null) | select(.properties.macAddress != null) | select(.properties.macAddress | inside(\"${local_interfaces[*]}\"))) | map(select((.properties.ipConfigurations | length) > 0))" ${NETWORK_INTERFACES_FILE})

    if [[ -z ${SDN_INTERFACES} ]]; then
        echo "Error extracting the SDN interfaces from the network interfaces file"
        exit 123
    fi

    AZURE_CNI_CONFIG=$(echo ${SDN_INTERFACES} | jq "{Interfaces: [.[] | {MacAddress: .properties.macAddress, IsPrimary: .properties.primary, IPSubnets: [{Prefix: .properties.ipConfigurations[0].properties.subnet.id, IPAddresses: .properties.ipConfigurations | [.[] | {Address: .properties.privateIPAddress, IsPrimary: .properties.primary}]}]}]}")

    mapfile -t SUBNET_IDS < <(echo ${SDN_INTERFACES} | jq '[.[].properties.ipConfigurations[0].properties.subnet.id] | unique | .[]' -r)

    for SUBNET_ID in "${SUBNET_IDS[@]}"; do
        SUBNET_PREFIX=$(curl -s --retry 5 --retry-delay 10 --max-time 60 -f -X GET \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            "${RESOURCE_MANAGER_ENDPOINT}${SUBNET_ID:1}?api-version=${NETWORK_API_VERSION}" |
            jq '.properties.addressPrefix' -r)

        if [[ -z ${SUBNET_PREFIX} ]]; then
            echo "Error fetching the subnet address prefix for a subnet ID"
            exit 122
        fi

        AZURE_CNI_CONFIG=$(echo ${AZURE_CNI_CONFIG} | sed "s|${SUBNET_ID}|${SUBNET_PREFIX}|g")
    done

    echo ${AZURE_CNI_CONFIG} > ${AZURE_CNI_CONFIG_FILE}
    chmod 0444 ${AZURE_CNI_CONFIG_FILE}
}
ensureContainerd() {
  wait_for_file 1200 1 /etc/systemd/system/containerd.service.d/exec_start.conf || exit $ERR_FILE_WATCH_TIMEOUT
  wait_for_file 1200 1 /etc/containerd/config.toml || exit $ERR_FILE_WATCH_TIMEOUT
  wait_for_file 1200 1 /etc/sysctl.d/11-containerd.conf || exit $ERR_FILE_WATCH_TIMEOUT
  retrycmd_if_failure 120 5 25 sysctl --system || exit $ERR_SYSCTL_RELOAD
  systemctl is-active --quiet docker && (systemctl_disable 20 30 120 docker || exit $ERR_SYSTEMD_DOCKER_STOP_FAIL)
  systemctlEnableAndStart containerd || exit $ERR_SYSTEMCTL_START_FAIL
}
ensureMonitorService() {
    
    CONTAINERD_MONITOR_SYSTEMD_TIMER_FILE=/etc/systemd/system/containerd-monitor.timer
    wait_for_file 1200 1 $CONTAINERD_MONITOR_SYSTEMD_TIMER_FILE || exit $ERR_FILE_WATCH_TIMEOUT
    CONTAINERD_MONITOR_SYSTEMD_FILE=/etc/systemd/system/containerd-monitor.service
    wait_for_file 1200 1 $CONTAINERD_MONITOR_SYSTEMD_FILE || exit $ERR_FILE_WATCH_TIMEOUT
    systemctlEnableAndStart containerd-monitor.timer || exit $ERR_SYSTEMCTL_START_FAIL
}




ensureKubelet() {
    KUBELET_DEFAULT_FILE=/etc/default/kubelet
    wait_for_file 1200 1 $KUBELET_DEFAULT_FILE || exit $ERR_FILE_WATCH_TIMEOUT
    KUBECONFIG_FILE=/var/lib/kubelet/kubeconfig
    wait_for_file 1200 1 $KUBECONFIG_FILE || exit $ERR_FILE_WATCH_TIMEOUT
    KUBELET_RUNTIME_CONFIG_SCRIPT_FILE=/opt/azure/containers/kubelet.sh
    wait_for_file 1200 1 $KUBELET_RUNTIME_CONFIG_SCRIPT_FILE || exit $ERR_FILE_WATCH_TIMEOUT
    systemctlEnableAndStart kubelet || exit $ERR_KUBELET_START_FAIL
    
    
    
}

# The update-node-labels.service updates the labels for the kubernetes node. Runs until successful on startup
ensureUpdateNodeLabels() {
    KUBELET_DEFAULT_FILE=/etc/default/kubelet
    wait_for_file 1200 1 $KUBELET_DEFAULT_FILE || exit $ERR_FILE_WATCH_TIMEOUT
    UPDATE_NODE_LABELS_SCRIPT_FILE=/opt/azure/containers/update-node-labels.sh
    wait_for_file 1200 1 $UPDATE_NODE_LABELS_SCRIPT_FILE || exit $ERR_FILE_WATCH_TIMEOUT
    UPDATE_NODE_LABELS_SYSTEMD_FILE=/etc/systemd/system/update-node-labels.service
    wait_for_file 1200 1 $UPDATE_NODE_LABELS_SYSTEMD_FILE || exit $ERR_FILE_WATCH_TIMEOUT
    systemctlEnableAndStart update-node-labels || exit $ERR_SYSTEMCTL_START_FAIL
}

ensureSysctl() {
    SYSCTL_CONFIG_FILE=/etc/sysctl.d/999-sysctl-aks.conf
    wait_for_file 1200 1 $SYSCTL_CONFIG_FILE || exit $ERR_FILE_WATCH_TIMEOUT
    retrycmd_if_failure 24 5 25 sysctl --system
}

ensureJournal() {
    {
        echo "Storage=persistent"
        echo "SystemMaxUse=1G"
        echo "RuntimeMaxUse=1G"
        echo "ForwardToSyslog=yes"
    } >> /etc/systemd/journald.conf
    systemctlEnableAndStart systemd-journald || exit $ERR_SYSTEMCTL_START_FAIL
}

ensureK8sControlPlane() {
    if $REBOOTREQUIRED || [ "$NO_OUTBOUND" = "true" ]; then
        return
    fi
    retrycmd_if_failure 120 5 25 $KUBECTL 2>/dev/null cluster-info || exit $ERR_K8S_RUNNING_TIMEOUT
}

createKubeManifestDir() {
    KUBEMANIFESTDIR=/etc/kubernetes/manifests
    mkdir -p $KUBEMANIFESTDIR
}

writeKubeConfig() {
    KUBECONFIGDIR=/home/$ADMINUSER/.kube
    KUBECONFIGFILE=$KUBECONFIGDIR/config
    mkdir -p $KUBECONFIGDIR
    touch $KUBECONFIGFILE
    chown $ADMINUSER:$ADMINUSER $KUBECONFIGDIR
    chown $ADMINUSER:$ADMINUSER $KUBECONFIGFILE
    chmod 700 $KUBECONFIGDIR
    chmod 600 $KUBECONFIGFILE
    set +x
    echo "
---
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: \"$CA_CERTIFICATE\"
    server: $KUBECONFIG_SERVER
  name: \"$MASTER_FQDN\"
contexts:
- context:
    cluster: \"$MASTER_FQDN\"
    user: \"$MASTER_FQDN-admin\"
  name: \"$MASTER_FQDN\"
current-context: \"$MASTER_FQDN\"
kind: Config
users:
- name: \"$MASTER_FQDN-admin\"
  user:
    client-certificate-data: \"$KUBECONFIG_CERTIFICATE\"
    client-key-data: \"$KUBECONFIG_KEY\"
" > $KUBECONFIGFILE
    set -x
}

configClusterAutoscalerAddon() {
    CLUSTER_AUTOSCALER_ADDON_FILE=/etc/kubernetes/addons/cluster-autoscaler-deployment.yaml
    wait_for_file 1200 1 $CLUSTER_AUTOSCALER_ADDON_FILE || exit $ERR_FILE_WATCH_TIMEOUT
    sed -i "s|<clientID>|$(echo $SERVICE_PRINCIPAL_CLIENT_ID | base64)|g" $CLUSTER_AUTOSCALER_ADDON_FILE
    sed -i "s|<clientSec>|$(echo $SERVICE_PRINCIPAL_CLIENT_SECRET | base64)|g" $CLUSTER_AUTOSCALER_ADDON_FILE
    sed -i "s|<subID>|$(echo $SUBSCRIPTION_ID | base64)|g" $CLUSTER_AUTOSCALER_ADDON_FILE
    sed -i "s|<tenantID>|$(echo $TENANT_ID | base64)|g" $CLUSTER_AUTOSCALER_ADDON_FILE
    sed -i "s|<rg>|$(echo $RESOURCE_GROUP | base64)|g" $CLUSTER_AUTOSCALER_ADDON_FILE
}

configACIConnectorAddon() {
    ACI_CONNECTOR_CREDENTIALS=$(printf "{\"clientId\": \"%s\", \"clientSecret\": \"%s\", \"tenantId\": \"%s\", \"subscriptionId\": \"%s\", \"activeDirectoryEndpointUrl\": \"https://login.microsoftonline.com\",\"resourceManagerEndpointUrl\": \"https://management.azure.com/\", \"activeDirectoryGraphResourceId\": \"https://graph.windows.net/\", \"sqlManagementEndpointUrl\": \"https://management.core.windows.net:8443/\", \"galleryEndpointUrl\": \"https://gallery.azure.com/\", \"managementEndpointUrl\": \"https://management.core.windows.net/\"}" "$SERVICE_PRINCIPAL_CLIENT_ID" "$SERVICE_PRINCIPAL_CLIENT_SECRET" "$TENANT_ID" "$SUBSCRIPTION_ID" | base64 -w 0)

    openssl req -newkey rsa:4096 -new -nodes -x509 -days 3650 -keyout /etc/kubernetes/certs/aci-connector-key.pem -out /etc/kubernetes/certs/aci-connector-cert.pem -subj "/C=US/ST=CA/L=virtualkubelet/O=virtualkubelet/OU=virtualkubelet/CN=virtualkubelet"
    ACI_CONNECTOR_KEY=$(base64 /etc/kubernetes/certs/aci-connector-key.pem -w0)
    ACI_CONNECTOR_CERT=$(base64 /etc/kubernetes/certs/aci-connector-cert.pem -w0)

    ACI_CONNECTOR_ADDON_FILE=/etc/kubernetes/addons/aci-connector-deployment.yaml
    wait_for_file 1200 1 $ACI_CONNECTOR_ADDON_FILE || exit $ERR_FILE_WATCH_TIMEOUT
    sed -i "s|<creds>|$ACI_CONNECTOR_CREDENTIALS|g" $ACI_CONNECTOR_ADDON_FILE
    sed -i "s|<rgName>|$RESOURCE_GROUP|g" $ACI_CONNECTOR_ADDON_FILE
    sed -i "s|<cert>|$ACI_CONNECTOR_CERT|g" $ACI_CONNECTOR_ADDON_FILE
    sed -i "s|<key>|$ACI_CONNECTOR_KEY|g" $ACI_CONNECTOR_ADDON_FILE
}

configAzurePolicyAddon() {
    AZURE_POLICY_ADDON_FILE=/etc/kubernetes/addons/azure-policy-deployment.yaml
    sed -i "s|<resourceId>|/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP|g" $AZURE_POLICY_ADDON_FILE
}


installGPUDriversRun() {
    set -x
    MODULE_NAME="nvidia"
    NVIDIA_DKMS_DIR="/var/lib/dkms/${MODULE_NAME}/${GPU_DV}"
    KERNEL_NAME=$(uname -r)
    if [ -d "${NVIDIA_DKMS_DIR}" ]; then
        if [ -x "$(command -v dkms)" ]; then
          dkms remove -m ${MODULE_NAME} -v ${GPU_DV} -k ${KERNEL_NAME}
        else
          rm -rf "${NVIDIA_DKMS_DIR}"
        fi
    fi
    local log_file_name="/var/log/nvidia-installer-$(date +%s).log"
    if [ ! -f "${GPU_DEST}/nvidia-drivers-${GPU_DV}" ]; then
        installGPUDrivers
    fi
    sh $GPU_DEST/nvidia-drivers-$GPU_DV -s \
        -k=$KERNEL_NAME \
        --log-file-name=${log_file_name} \
        -a --no-drm --dkms --utility-prefix="${GPU_DEST}" --opengl-prefix="${GPU_DEST}"
    exit $?
}

configGPUDrivers() {
    
    
    rmmod nouveau
    echo blacklist nouveau >> /etc/modprobe.d/blacklist.conf
    retrycmd_if_failure_no_stats 120 5 25 update-initramfs -u || exit $ERR_GPU_DRIVERS_INSTALL_TIMEOUT
    wait_for_apt_locks
    
    retrycmd_if_failure 600 1 3600 apt-get -o Dpkg::Options::="--force-confold" install -y nvidia-container-runtime="${NVIDIA_CONTAINER_RUNTIME_VERSION}+${NVIDIA_DOCKER_SUFFIX}" || exit $ERR_GPU_DRIVERS_INSTALL_TIMEOUT
    tmpDir=$GPU_DEST/tmp
    (
      set -e -o pipefail
      cd "${tmpDir}"
      wait_for_apt_locks
      dpkg-deb -R ./nvidia-docker2*.deb "${tmpDir}/pkg" || exit $ERR_GPU_DRIVERS_INSTALL_TIMEOUT
      cp -r ${tmpDir}/pkg/usr/* /usr/ || exit $ERR_GPU_DRIVERS_INSTALL_TIMEOUT
    )
    rm -rf $GPU_DEST/tmp
    
    retrycmd_if_failure 120 5 25 pkill -SIGHUP containerd || exit $ERR_GPU_DRIVERS_INSTALL_TIMEOUT
    
    mkdir -p $GPU_DEST/lib64 $GPU_DEST/overlay-workdir
    retrycmd_if_failure 120 5 25 mount -t overlay -o lowerdir=/usr/lib/x86_64-linux-gnu,upperdir=${GPU_DEST}/lib64,workdir=${GPU_DEST}/overlay-workdir none /usr/lib/x86_64-linux-gnu || exit $ERR_GPU_DRIVERS_INSTALL_TIMEOUT
    export -f installGPUDriversRun
    retrycmd_if_failure 3 1 600 bash -c installGPUDriversRun || exit $ERR_GPU_DRIVERS_START_FAIL
    mv ${GPU_DEST}/bin/* /usr/bin
    echo "${GPU_DEST}/lib64" > /etc/ld.so.conf.d/nvidia.conf
    retrycmd_if_failure 120 5 25 ldconfig || exit $ERR_GPU_DRIVERS_START_FAIL
    umount -l /usr/lib/x86_64-linux-gnu
    retrycmd_if_failure 120 5 25 nvidia-modprobe -u -c0 || exit $ERR_GPU_DRIVERS_START_FAIL
    retrycmd_if_failure 120 5 25 nvidia-smi || exit $ERR_GPU_DRIVERS_START_FAIL
    retrycmd_if_failure 120 5 25 ldconfig || exit $ERR_GPU_DRIVERS_START_FAIL
}

validateGPUDrivers() {
    retrycmd_if_failure 24 5 25 nvidia-modprobe -u -c0 && echo "gpu driver loaded" || configGPUDrivers || exit $ERR_GPU_DRIVERS_START_FAIL
    which nvidia-smi
    if [[ $? == 0 ]]; then
        SMI_RESULT=$(retrycmd_if_failure 24 5 25 nvidia-smi)
    else
        SMI_RESULT=$(retrycmd_if_failure 24 5 25 $GPU_DEST/bin/nvidia-smi)
    fi
    SMI_STATUS=$?
    if [[ $SMI_STATUS != 0 ]]; then
        if [[ $SMI_RESULT == *"infoROM is corrupted"* ]]; then
            exit $ERR_GPU_INFO_ROM_CORRUPTED
        else
            exit $ERR_GPU_DRIVERS_START_FAIL
        fi
    else
        echo "gpu driver working fine"
    fi
}

ensureGPUDrivers() {
    if [[ "${CONFIG_GPU_DRIVER_IF_NEEDED}" = true ]]; then
        configGPUDrivers
    else
        validateGPUDrivers
    fi
    systemctlEnableAndStart nvidia-modprobe || exit $ERR_GPU_DRIVERS_START_FAIL
}

#EOF
