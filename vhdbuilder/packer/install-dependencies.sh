#!/bin/bash
source /home/packer/provision_installs.sh
source /home/packer/provision_source.sh
source /home/packer/tool_installs.sh
source /home/packer/packer_source.sh

VHD_LOGS_FILEPATH=/opt/azure/vhd-install.complete

echo "Starting build on " $(date) > ${VHD_LOGS_FILEPATH}

copyPackerFiles

echo ""
echo "Components downloaded in this VHD build (some of the below components might get deleted during cluster provisioning if they are not needed):" >> ${VHD_LOGS_FILEPATH}

AUDITD_ENABLED=true
installDeps
cat << EOF >> ${VHD_LOGS_FILEPATH}
  - azure-cli
  - apache2-utils
  - apt-transport-https
  - auditd
  - blobfuse=1.3.5
  - ca-certificates
  - ceph-common
  - cgroup-lite
  - cifs-utils
  - conntrack
  - cracklib-runtime
  - ebtables
  - ethtool
  - fuse
  - git
  - glusterfs-client
  - init-system-helpers
  - iproute2
  - ipset
  - iptables
  - jq
  - libpam-pwquality
  - libpwquality-tools
  - mount
  - nfs-common
  - pigz socat
  - traceroute
  - util-linux
  - xz-utils
  - zip
EOF

if [[ ${UBUNTU_RELEASE} == "18.04" ]]; then
  overrideNetworkConfig || exit 1
  disableSystemdTimesyncdAndEnableNTP || exit 1
fi

MOBY_VERSION="19.03.14"
installMoby
echo "  - moby v${MOBY_VERSION}" >> ${VHD_LOGS_FILEPATH}
cliTool="docker"

if [[ ${CONTAINER_RUNTIME:-""} == "containerd" ]]; then
  echo "VHD will be built with containerd as the container runtime"
  CONTAINERD_VERSION="1.4.3"
  installStandaloneContainerd
  echo "  - containerd v${CONTAINERD_VERSION}" >> ${VHD_LOGS_FILEPATH}
  CRICTL_VERSIONS="1.19.0"
  for CRICTL_VERSION in ${CRICTL_VERSIONS}; do
    downloadCrictl ${CRICTL_VERSION}
    echo "  - crictl version ${CRICTL_VERSION}" >> ${VHD_LOGS_FILEPATH}
  done
  # k8s will use images in the k8s.io namespaces - create it
  ctr namespace create k8s.io
  cliTool="ctr"

  # also pre-download Teleportd plugin for containerd
  # downloadTeleportdPlugin ${TELEPORTD_PLUGIN_DOWNLOAD_URL} "0.6.0"
fi

installBpftrace
echo "  - bpftrace" >> ${VHD_LOGS_FILEPATH}

installGPUDrivers
echo "  - nvidia-docker2 nvidia-container-runtime" >> ${VHD_LOGS_FILEPATH}
retrycmd_if_failure 30 5 3600 apt-get -o Dpkg::Options::="--force-confold" install -y nvidia-container-runtime="${NVIDIA_CONTAINER_RUNTIME_VERSION}+docker18.09.2-1" --download-only || exit $ERR_GPU_DRIVERS_INSTALL_TIMEOUT
echo "  - nvidia-container-runtime=${NVIDIA_CONTAINER_RUNTIME_VERSION}+docker18.09.2-1" >> ${VHD_LOGS_FILEPATH}

if grep -q "fullgpu" <<< "$FEATURE_FLAGS"; then
    echo "  - ensureGPUDrivers" >> ${VHD_LOGS_FILEPATH}
    ensureGPUDrivers
fi

installBcc
cat << EOF >> ${VHD_LOGS_FILEPATH}
  - bcc-tools
  - libbcc-examples
EOF

VNET_CNI_VERSIONS="
1.2.0_hotfix
1.2.0
1.1.8
1.4.0
"
for VNET_CNI_VERSION in $VNET_CNI_VERSIONS; do
    VNET_CNI_PLUGINS_URL="https://acs-mirror.azureedge.net/azure-cni/v${VNET_CNI_VERSION}/binaries/azure-vnet-cni-linux-amd64-v${VNET_CNI_VERSION}.tgz"
    downloadAzureCNI
    echo "  - Azure CNI version ${VNET_CNI_VERSION}" >> ${VHD_LOGS_FILEPATH}
done

CNI_PLUGIN_VERSIONS="
0.7.6
0.7.5
0.7.1
"
for CNI_PLUGIN_VERSION in $CNI_PLUGIN_VERSIONS; do
    CNI_PLUGINS_URL="https://acs-mirror.azureedge.net/cni/cni-plugins-amd64-v${CNI_PLUGIN_VERSION}.tgz"
    downloadCNI
    echo "  - CNI plugin version ${CNI_PLUGIN_VERSION}" >> ${VHD_LOGS_FILEPATH}
done

CNI_PLUGIN_VERSIONS="
0.8.6
"
for CNI_PLUGIN_VERSION in $CNI_PLUGIN_VERSIONS; do
    CNI_PLUGINS_URL="https://acs-mirror.azureedge.net/cni-plugins/v${CNI_PLUGIN_VERSION}/binaries/cni-plugins-linux-amd64-v${CNI_PLUGIN_VERSION}.tgz"
    downloadCNI
    echo "  - CNI plugin version ${CNI_PLUGIN_VERSION}" >> ${VHD_LOGS_FILEPATH}
done

installImg
echo "  - img" >> ${VHD_LOGS_FILEPATH}

echo "${CONTAINER_RUNTIME} images pre-pulled:" >> ${VHD_LOGS_FILEPATH}

DASHBOARD_VERSIONS="1.10.1"
for DASHBOARD_VERSION in ${DASHBOARD_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes/kubernetes-dashboard:v${DASHBOARD_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

NEW_DASHBOARD_VERSIONS="
2.0.0-beta8
2.0.0-rc3
2.0.0-rc7
2.0.1
"
for DASHBOARD_VERSION in ${NEW_DASHBOARD_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes/dashboard:v${DASHBOARD_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

NEW_DASHBOARD_METRICS_SCRAPER_VERSIONS="
1.0.2
1.0.3
1.0.4
"
for DASHBOARD_VERSION in ${NEW_DASHBOARD_METRICS_SCRAPER_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes/metrics-scraper:v${DASHBOARD_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

EXECHEALTHZ_VERSIONS="1.2"
for EXECHEALTHZ_VERSION in ${EXECHEALTHZ_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes/exechealthz:${EXECHEALTHZ_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

ADDON_RESIZER_VERSIONS="
1.8.5
1.8.4
1.8.1
1.7
"
for ADDON_RESIZER_VERSION in ${ADDON_RESIZER_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes/autoscaler/addon-resizer:${ADDON_RESIZER_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

METRICS_SERVER_VERSIONS="
0.3.6
0.3.5
"
for METRICS_SERVER_VERSION in ${METRICS_SERVER_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes/metrics-server:v${METRICS_SERVER_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

LEGACY_MCR_PAUSE_VERSIONS="1.2.0"
for PAUSE_VERSION in ${LEGACY_MCR_PAUSE_VERSIONS}; do
    # Pull the arch independent MCR pause image which is built for Linux and Windows
    CONTAINER_IMAGE="mcr.microsoft.com/k8s/core/pause:${PAUSE_VERSION}"
    pullContainerImage ${cliTool} "${CONTAINER_IMAGE}"
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

MCR_PAUSE_VERSIONS="
1.2.0
1.3.1
1.4.0
3.2
"
for PAUSE_VERSION in ${MCR_PAUSE_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes/pause:${PAUSE_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

# https://github.com/kubernetes/kubernetes/blob/v1.18.10/cmd/kubeadm/app/constants/constants.go#L340
# https://github.com/kubernetes/kubernetes/blob/v1.18.15/cmd/kubeadm/app/constants/constants.go#L343
CORE_DNS_VERSIONS="
1.7.0
1.6.7
1.6.6
1.6.5
1.5.0
1.3.1
1.2.6
"
for CORE_DNS_VERSION in ${CORE_DNS_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes/coredns:${CORE_DNS_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

# https://github.com/kubernetes/kubernetes/blob/v1.18.10/cmd/kubeadm/app/constants/constants.go#L270
# https://github.com/kubernetes/kubernetes/blob/v1.18.15/cmd/kubeadm/app/constants/constants.go#L273
# NOTE: MCR and GCR tags are not an exact match
ETCD_VERSIONS="
v3.4.3
v3.4.13
"
for ETCD_VERSION in ${ETCD_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/etcd-io/etcd:${ETCD_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

AZURE_CNIIMAGEBASE="mcr.microsoft.com/containernetworking"
AZURE_CNI_NETWORKMONITOR_VERSIONS="
1.1.8
0.0.7
0.0.6
"
for AZURE_CNI_NETWORKMONITOR_VERSION in ${AZURE_CNI_NETWORKMONITOR_VERSIONS}; do
    CONTAINER_IMAGE="${AZURE_CNIIMAGEBASE}/networkmonitor:v${AZURE_CNI_NETWORKMONITOR_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

AZURE_NPM_VERSIONS="
1.2.3
1.2.2_hotfix
1.2.1
1.1.8
1.1.7
"
for AZURE_NPM_VERSION in ${AZURE_NPM_VERSIONS}; do
    CONTAINER_IMAGE="${AZURE_CNIIMAGEBASE}/azure-npm:v${AZURE_NPM_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

AZURE_VNET_TELEMETRY_VERSIONS="
1.0.30
"
for AZURE_VNET_TELEMETRY_VERSION in ${AZURE_VNET_TELEMETRY_VERSIONS}; do
    CONTAINER_IMAGE="${AZURE_CNIIMAGEBASE}/azure-vnet-telemetry:v${AZURE_VNET_TELEMETRY_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

NVIDIA_DEVICE_PLUGIN_VERSIONS="
1.11
1.10
"
for NVIDIA_DEVICE_PLUGIN_VERSION in ${NVIDIA_DEVICE_PLUGIN_VERSIONS}; do
  if [[ "${cliTool}" == "ctr" ]]; then
    # containerd/ctr doesn't auto-resolve to docker.io
    CONTAINER_IMAGE="docker.io/nvidia/k8s-device-plugin:${NVIDIA_DEVICE_PLUGIN_VERSION}"
  else
    CONTAINER_IMAGE="nvidia/k8s-device-plugin:${NVIDIA_DEVICE_PLUGIN_VERSION}"
  fi
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

# GPU device plugin
if grep -q "fullgpu" <<< "$FEATURE_FLAGS" && grep -q "gpudaemon" <<< "$FEATURE_FLAGS"; then
  kubeletDevicePluginPath="/var/lib/kubelet/device-plugins"
  mkdir -p $kubeletDevicePluginPath
  echo "  - $kubeletDevicePluginPath" >> ${VHD_LOGS_FILEPATH}

  DEST="/usr/local/nvidia/bin"
  mkdir -p $DEST
  if [[ "${CONTAINER_RUNTIME}" == "containerd" ]]; then
    ctr --namespace k8s.io run --rm --mount type=bind,src=${DEST},dst=${DEST},options=bind:rw --cwd ${DEST} "docker.io/nvidia/k8s-device-plugin:1.11" plugingextract /bin/sh -c "cp /usr/bin/nvidia-device-plugin $DEST" || exit 1   
  else
    docker run --rm --entrypoint "" -v $DEST:$DEST "nvidia/k8s-device-plugin:1.11" /bin/bash -c "cp /usr/bin/nvidia-device-plugin $DEST" || exit 1
  fi
  chmod a+x $DEST/nvidia-device-plugin
  echo "  - extracted nvidia-device-plugin..." >> ${VHD_LOGS_FILEPATH}
  ls -ltr $DEST >> ${VHD_LOGS_FILEPATH}

  systemctlEnableAndStart nvidia-device-plugin || exit 1
fi

installSGX=${SGX_DEVICE_PLUGIN_INSTALL:-"False"}
if [[ ${installSGX} == "True" ]]; then
    SGX_DEVICE_PLUGIN_VERSIONS="1.0"
    for SGX_DEVICE_PLUGIN_VERSION in ${SGX_DEVICE_PLUGIN_VERSIONS}; do
        CONTAINER_IMAGE="mcr.microsoft.com/aks/acc/sgx-device-plugin:${SGX_DEVICE_PLUGIN_VERSION}"
        pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
        echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
    done

    SGX_PLUGIN_VERSIONS="0.1"
    for SGX_PLUGIN_VERSION in ${SGX_PLUGIN_VERSIONS}; do
        CONTAINER_IMAGE="mcr.microsoft.com/aks/acc/sgx-plugin:${SGX_PLUGIN_VERSION}"
        pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
        echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
    done

    SGX_WEBHOOK_VERSIONS="0.1"
    for SGX_WEBHOOK_VERSION in ${SGX_WEBHOOK_VERSIONS}; do
        CONTAINER_IMAGE="mcr.microsoft.com/aks/acc/sgx-webhook:${SGX_WEBHOOK_VERSION}"
        pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
        echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
    done
fi

TUNNELFRONT_VERSIONS="
v1.9.2-v3.0.18
v1.9.2-v3.0.19
v1.9.2-v3.0.20
"
for TUNNELFRONT_VERSION in ${TUNNELFRONT_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/aks/hcp/hcp-tunnel-front:${TUNNELFRONT_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

KONNECTIVITY_AGENT_VERSIONS="
v0.0.13
"
for KONNECTIVITY_AGENT_VERSION in ${KONNECTIVITY_AGENT_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes/apiserver-network-proxy/agent:${KONNECTIVITY_AGENT_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

# 1.0.10 is for the ipv6 fix
# 1.0.11 is for the cve fix
OPENVPN_VERSIONS="
1.0.8
1.0.10
1.0.11
"
for OPENVPN_VERSION in ${OPENVPN_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/aks/hcp/tunnel-openvpn:${OPENVPN_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

KUBE_SVC_REDIRECT_VERSIONS="1.0.7"
for KUBE_SVC_REDIRECT_VERSION in ${KUBE_SVC_REDIRECT_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/aks/hcp/kube-svc-redirect:v${KUBE_SVC_REDIRECT_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

# oms agent used by AKS
# keeping last-->last image (ciprod10272020) as last released (ciprod11092020) is not fully rolledout yet. Added latest (ciprod01112021)
OMS_AGENT_IMAGES="ciprod10272020 ciprod11092020 ciprod01112021"
for OMS_AGENT_IMAGE in ${OMS_AGENT_IMAGES}; do
    CONTAINER_IMAGE="mcr.microsoft.com/azuremonitor/containerinsights/ciprod:${OMS_AGENT_IMAGE}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

# calico images used by AKS
CALICO_CNI_IMAGES="
v3.8.9.1
v3.8.9.2
"
for CALICO_CNI_IMAGE in ${CALICO_CNI_IMAGES}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/calico/cni:${CALICO_CNI_IMAGE}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

CALICO_NODE_IMAGES="
v3.17.1
v3.8.9.1
v3.8.9.2
"
for CALICO_NODE_IMAGE in ${CALICO_NODE_IMAGES}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/calico/node:${CALICO_NODE_IMAGE}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

# typha and pod2daemon can't be patched like cni and node can as they use scratch as a base
CALICO_TYPHA_IMAGES="
v3.17.1
v3.8.9
"
for CALICO_TYPHA_IMAGE in ${CALICO_TYPHA_IMAGES}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/calico/typha:${CALICO_TYPHA_IMAGE}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

CALICO_KUBE_CONTROLLERS_IMAGES="
v3.17.1
"
for CALICO_KUBE_CONTROLLERS_IMAGE in ${CALICO_KUBE_CONTROLLERS_IMAGES}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/calico/kube-controllers:${CALICO_KUBE_CONTROLLERS_IMAGE}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

TIGERA_OPERATOR_IMAGES="
v1.13.3
"
for TIGERA_OPERATOR_IMAGE in ${TIGERA_OPERATOR_IMAGES}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/tigera/kube-controllers:${TIGERA_OPERATOR_IMAGE}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

CALICO_POD2DAEMON_IMAGES="
v3.8.9
"
for CALICO_POD2DAEMON_IMAGE in ${CALICO_POD2DAEMON_IMAGES}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/calico/pod2daemon-flexvol:${CALICO_POD2DAEMON_IMAGE}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

# Cluster Proportional Autoscaler
CPA_IMAGES="
1.3.0_v0.0.5
1.7.1
1.7.1-hotfix.20200403
"
for CPA_IMAGE in ${CPA_IMAGES}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes/autoscaler/cluster-proportional-autoscaler:${CPA_IMAGE}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

KV_FLEXVOLUME_VERSIONS="0.0.13"
for KV_FLEXVOLUME_VERSION in ${KV_FLEXVOLUME_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/k8s/flexvolume/keyvault-flexvolume:v${KV_FLEXVOLUME_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

BLOBFUSE_FLEXVOLUME_VERSIONS="1.0.15"
for BLOBFUSE_FLEXVOLUME_VERSION in ${BLOBFUSE_FLEXVOLUME_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/k8s/flexvolume/blobfuse-flexvolume:${BLOBFUSE_FLEXVOLUME_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

# this is the patched images which AKS are using.
AKS_IP_MASQ_AGENT_VERSIONS="
2.5.0.2
2.5.0.3
"
for IP_MASQ_AGENT_VERSION in ${AKS_IP_MASQ_AGENT_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes/ip-masq-agent:v${IP_MASQ_AGENT_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

NGINX_VERSIONS="1.13.12-alpine"
for NGINX_VERSION in ${NGINX_VERSIONS}; do
    if [[ "${cliTool}" == "ctr" ]]; then
      # containerd/ctr doesn't auto-resolve to docker.io
      CONTAINER_IMAGE="docker.io/library/nginx:${NGINX_VERSION}"
    else
      CONTAINER_IMAGE="nginx:${NGINX_VERSION}"
    fi
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

KMS_PLUGIN_VERSIONS="0.0.9"
for KMS_PLUGIN_VERSION in ${KMS_PLUGIN_VERSIONS}; do
    CONTAINER_IMAGE="mcr.microsoft.com/k8s/kms/keyvault:v${KMS_PLUGIN_VERSION}"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done


# kubelet and kubectl
# need to cover previously supported version for VMAS scale up scenario
# So keeping as many versions as we can - those unsupported version can be removed when we don't have enough space
# below are the required to support versions

# NOTE that we only keep the latest one per k8s patch version as kubelet/kubectl is decided by VHD version
K8S_VERSIONS="
1.17.17
1.18.18
1.19.10
1.19.11
1.20.6
1.20.7
"
for PATCHED_KUBERNETES_VERSION in ${K8S_VERSIONS}; do
  # Only need to store k8s components >= 1.19 for containerd VHDs
  if (($(echo ${PATCHED_KUBERNETES_VERSION} | cut -d"." -f2) < 19)) && [[ ${CONTAINER_RUNTIME} == "containerd" ]]; then
    continue
  fi
  if (($(echo ${PATCHED_KUBERNETES_VERSION} | cut -d"." -f2) < 17)); then
    HYPERKUBE_URL="mcr.microsoft.com/oss/kubernetes/hyperkube:v${PATCHED_KUBERNETES_VERSION}-azs"
    # NOTE: the KUBERNETES_VERSION will be used to tag the extracted kubelet/kubectl in /usr/local/bin
    # it should match the KUBERNETES_VERSION format(just version number, e.g. 1.15.7, no prefix v)
    # in installKubeletAndKubectl() executed by cse, otherwise cse will need to download the kubelet/kubectl again
    KUBERNETES_VERSION=$(echo ${PATCHED_KUBERNETES_VERSION} | cut -d"_" -f1 | cut -d"-" -f1 | cut -d"." -f1,2,3)
    # extractHyperkube will extract the kubelet/kubectl binary from the image: ${HYPERKUBE_URL}
    # and put them to /usr/local/bin/kubelet-${KUBERNETES_VERSION}
    extractHyperkube ${cliTool}
    # remove hyperkube here as the one that we really need is pulled later
    removeContainerImage ${cliTool} $HYPERKUBE_URL
  else
    # strip the last .1 as that is for base image patch for hyperkube
    if grep -iq hotfix <<< ${PATCHED_KUBERNETES_VERSION}; then
      # shellcheck disable=SC2006
      PATCHED_KUBERNETES_VERSION=`echo ${PATCHED_KUBERNETES_VERSION} | cut -d"." -f1,2,3,4`;
    else
      PATCHED_KUBERNETES_VERSION=`echo ${PATCHED_KUBERNETES_VERSION} | cut -d"." -f1,2,3`;
    fi
    KUBERNETES_VERSION=$(echo ${PATCHED_KUBERNETES_VERSION} | cut -d"_" -f1 | cut -d"-" -f1 | cut -d"." -f1,2,3)
    extractKubeBinaries $KUBERNETES_VERSION "https://acs-mirror.azureedge.net/kubernetes/v${PATCHED_KUBERNETES_VERSION}-azs/binaries/kubernetes-node-linux-amd64.tar.gz"
  fi
done
ls -ltr /usr/local/bin/* >> ${VHD_LOGS_FILEPATH}

# pull patched hyperkube image for AKS
# this is used by kube-proxy and need to cover previously supported version for VMAS scale up scenario
# So keeping as many versions as we can - those unsupported version can be removed when we don't have enough space
# below are the required to support versions

# NOTE that we keep multiple files per k8s patch version as kubeproxy version is decided by CCP.
PATCHED_HYPERKUBE_IMAGES="
1.17.17
1.18.18
1.19.10
1.19.11
1.20.6
1.20.7
"
for KUBERNETES_VERSION in ${PATCHED_HYPERKUBE_IMAGES}; do
  # Only need to store k8s components >= 1.19 for containerd VHDs
  if (($(echo ${KUBERNETES_VERSION} | cut -d"." -f2) < 19)) && [[ ${CONTAINER_RUNTIME} == "containerd" ]]; then
    continue
  fi
  # TODO: after CCP chart is done, change below to get hyperkube only for versions less than 1.17 only
  if (($(echo ${KUBERNETES_VERSION} | cut -d"." -f2) < 19)); then
      CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes/hyperkube:v${KUBERNETES_VERSION}-azs"
      pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
      echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
      if [[ ${cliTool} == "docker" ]]; then
          docker run --rm --entrypoint "" ${CONTAINER_IMAGE} /bin/sh -c "iptables --version" | grep -v nf_tables && echo "Hyperkube contains no nf_tables"
      else 
          ctr --namespace k8s.io run --rm ${CONTAINER_IMAGE} checkTask /bin/sh -c "iptables --version" | grep -v nf_tables && echo "Hyperkube contains no nf_tables"
      fi
      # shellcheck disable=SC2181
      if [[ $? != 0 ]]; then
      echo "Hyperkube contains nf_tables, exiting..."
      exit 99
      fi
  fi

  # from 1.17 onwards start using kube-proxy as well
  # strip the last .1 as that is for base image patch for hyperkube
  if (($(echo ${KUBERNETES_VERSION} | cut -d"." -f2) >= 17)); then
      if grep -iq hotfix <<< ${KUBERNETES_VERSION}; then
      KUBERNETES_VERSION=`echo ${KUBERNETES_VERSION} | cut -d"." -f1,2,3,4`;
      else
      KUBERNETES_VERSION=`echo ${KUBERNETES_VERSION} | cut -d"." -f1,2,3`;
      fi
      CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes/kube-proxy:v${KUBERNETES_VERSION}-azs"
      pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
      if [[ ${cliTool} == "docker" ]]; then
          docker run --rm --entrypoint "" ${CONTAINER_IMAGE} /bin/sh -c "iptables --version" | grep -v nf_tables && echo "kube-proxy contains no nf_tables"
      else
          ctr --namespace k8s.io run --rm ${CONTAINER_IMAGE} checkTask /bin/sh -c "iptables --version" | grep -v nf_tables && echo "kube-proxy contains no nf_tables"
      fi
      # shellcheck disable=SC2181
      if [[ $? != 0 ]]; then
      echo "Hyperkube contains nf_tables, exiting..."
      exit 99
      fi
      echo "  - ${CONTAINER_IMAGE}" >>${VHD_LOGS_FILEPATH}
  fi

  for component in kube-apiserver kube-controller-manager kube-scheduler; do
    if grep -iq hotfix <<< ${KUBERNETES_VERSION}; then
    KUBERNETES_VERSION=`echo ${KUBERNETES_VERSION} | cut -d"." -f1,2,3,4`;
    else
    KUBERNETES_VERSION=`echo ${KUBERNETES_VERSION} | cut -d"." -f1,2,3`;
    fi
    CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes/${component}:v${KUBERNETES_VERSION}-azs"
    pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
    echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
  done
done

ADDON_IMAGES="
mcr.microsoft.com/oss/open-policy-agent/gatekeeper:v3.1.3
mcr.microsoft.com/oss/open-policy-agent/gatekeeper:v3.2.3
mcr.microsoft.com/oss/kubernetes/external-dns:v0.6.0-hotfix-20200228
mcr.microsoft.com/oss/kubernetes/defaultbackend:1.4
mcr.microsoft.com/oss/kubernetes/ingress/nginx-ingress-controller:0.19.0
mcr.microsoft.com/oss/virtual-kubelet/virtual-kubelet:1.2.1.1
mcr.microsoft.com/azure-policy/policy-kubernetes-addon-prod:prod_20201015.1
mcr.microsoft.com/azure-policy/policy-kubernetes-addon-prod:prod_20210216.1
mcr.microsoft.com/azure-policy/policy-kubernetes-webhook:prod_20200505.3
mcr.microsoft.com/azure-policy/policy-kubernetes-webhook:prod_20210209.1
mcr.microsoft.com/azure-application-gateway/kubernetes-ingress:1.0.1-rc3
mcr.microsoft.com/azure-application-gateway/kubernetes-ingress:1.2.0
mcr.microsoft.com/azure-application-gateway/kubernetes-ingress:1.3.0
mcr.microsoft.com/containernetworking/azure-npm:v1.2.2_hotfix
mcr.microsoft.com/oss/azure/aad-pod-identity/nmi:v1.6.3
mcr.microsoft.com/oss/azure/aad-pod-identity/nmi:v1.7.0
mcr.microsoft.com/oss/kubernetes-csi/azuredisk-csi:v1.3.0.1
mcr.microsoft.com/oss/kubernetes-csi/csi-attacher:v3.1.0
mcr.microsoft.com/oss/kubernetes-csi/csi-node-driver-registrar:v2.2.0
mcr.microsoft.com/oss/kubernetes-csi/csi-provisioner:v2.1.1
mcr.microsoft.com/oss/kubernetes-csi/csi-resizer:v1.1.0
mcr.microsoft.com/oss/kubernetes-csi/csi-snapshotter:v3.0.3
mcr.microsoft.com/oss/kubernetes-csi/livenessprobe:v2.3.0
mcr.microsoft.com/oss/kubernetes-csi/snapshot-controller:v3.0.3
mcr.microsoft.com/oss/kubernetes/kube-state-metrics:v1.9.8
mcr.microsoft.com/oss/kubernetes/ip-masq-agent:v2.5.0
mcr.microsoft.com/oss/kubernetes/metrics-server:v0.5.0
"
for ADDON_IMAGE in ${ADDON_IMAGES}; do
  pullContainerImage ${cliTool} ${ADDON_IMAGE}
  echo "  - ${ADDON_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

ADDON_IMAGES="
mcr.microsoft.com/oss/fluent/fluentd-kubernetes-daemonset-azureblob:v1.12.4
"
for ADDON_IMAGE in ${ADDON_IMAGES}; do
  pullContainerImage docker ${ADDON_IMAGE}
  echo "  - ${ADDON_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

AZUREDISK_CSI_VERSIONS="
0.7.0
0.9.0
1.0.0
"
for AZUREDISK_CSI_VERSION in ${AZUREDISK_CSI_VERSIONS}; do
  CONTAINER_IMAGE="mcr.microsoft.com/k8s/csi/azuredisk-csi:v${AZUREDISK_CSI_VERSION}"
  pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
  echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

AZUREFILE_CSI_VERSIONS="
0.7.0
0.9.0
1.0.0
"
for AZUREFILE_CSI_VERSION in ${AZUREFILE_CSI_VERSIONS}; do
  CONTAINER_IMAGE="mcr.microsoft.com/k8s/csi/azurefile-csi:v${AZUREFILE_CSI_VERSION}"
  pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
  echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

CSI_LIVENESSPROBE_VERSIONS="
1.1.0
2.2.0
"
for CSI_LIVENESSPROBE_VERSION in ${CSI_LIVENESSPROBE_VERSIONS}; do
  CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes-csi/livenessprobe:v${CSI_LIVENESSPROBE_VERSION}"
  pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
  echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

CSI_NODE_DRIVER_REGISTRAR_VERSIONS="
1.2.0
2.0.1
"
for CSI_NODE_DRIVER_REGISTRAR_VERSION in ${CSI_NODE_DRIVER_REGISTRAR_VERSIONS}; do
  CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes-csi/csi-node-driver-registrar:v${CSI_NODE_DRIVER_REGISTRAR_VERSION}"
  pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
  echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

AZURE_CLOUD_NODE_MANAGER_VERSIONS="
0.5.1
0.6.0
0.7.0
"
for AZURE_CLOUD_NODE_MANAGER_VERSION in ${AZURE_CLOUD_NODE_MANAGER_VERSIONS}; do
  CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes/azure-cloud-node-manager:${AZURE_CLOUD_NODE_MANAGER_VERSION}"
  pullContainerImage ${cliTool} "${CONTAINER_IMAGE}"
  echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

SECRETS_STORE_CSI_DRIVER_VERSIONS="
0.0.19
"
for SECRETS_STORE_CSI_DRIVER_VERSION in ${SECRETS_STORE_CSI_DRIVER_VERSIONS}; do
  CONTAINER_IMAGE="mcr.microsoft.com/oss/kubernetes-csi/secrets-store/driver:v${SECRETS_STORE_CSI_DRIVER_VERSION}"
  pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
  echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

SECRETS_STORE_PROVIDER_AZURE_VERSIONS="
0.0.12
"
for SECRETS_STORE_PROVIDER_AZURE_VERSION in ${SECRETS_STORE_PROVIDER_AZURE_VERSIONS}; do
  CONTAINER_IMAGE="mcr.microsoft.com/oss/azure/secrets-store/provider-azure:${SECRETS_STORE_PROVIDER_AZURE_VERSION}"
  pullContainerImage ${cliTool} ${CONTAINER_IMAGE}
  echo "  - ${CONTAINER_IMAGE}" >> ${VHD_LOGS_FILEPATH}
done

# shellcheck disable=SC2010
ls -ltr /dev/* | grep sgx >>  ${VHD_LOGS_FILEPATH} 

df -h

# warn at 75% space taken
[ -s $(df -P | grep '/dev/sda1' | awk '0+$5 >= 75 {print}') ] || echo "WARNING: 75% of /dev/sda1 is used" >> ${VHD_LOGS_FILEPATH}
# error at 99% space taken
[ -s $(df -P | grep '/dev/sda1' | awk '0+$5 >= 99 {print}') ] || exit 1

echo "Using kernel:" >> ${VHD_LOGS_FILEPATH}
tee -a ${VHD_LOGS_FILEPATH} < /proc/version
{
  echo "Install completed successfully on " $(date)
  echo "VSTS Build NUMBER: ${BUILD_NUMBER}"
  echo "VSTS Build ID: ${BUILD_ID}"
  echo "Commit: ${COMMIT}"
  echo "Ubuntu version: ${UBUNTU_RELEASE}"
  echo "Hyperv generation: ${HYPERV_GENERATION}"
  echo "Feature flags: ${FEATURE_FLAGS}"
  echo "Container runtime: ${CONTAINER_RUNTIME}"
} >> ${VHD_LOGS_FILEPATH}

installAscBaseline
