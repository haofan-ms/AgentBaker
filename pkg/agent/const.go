// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT license.

package agent

const (
	// DefaultVNETCIDR is the default CIDR block for the VNET
	DefaultVNETCIDR = "10.0.0.0/8"
	// DefaultVNETCIDRIPv6 is the default IPv6 CIDR block for the VNET
	DefaultVNETCIDRIPv6 = "2001:1234:5678:9a00::/56"
	// DefaultInternalLbStaticIPOffset specifies the offset of the internal LoadBalancer's IP
	// address relative to the first consecutive Kubernetes static IP
	DefaultInternalLbStaticIPOffset = 10
	// NetworkPolicyNone is the string expression for the deprecated NetworkPolicy usage pattern "none"
	NetworkPolicyNone = "none"
	// NetworkPolicyCalico is the string expression for calico network policy config option
	NetworkPolicyCalico = "calico"
	// NetworkPolicyCilium is the string expression for cilium network policy config option
	NetworkPolicyCilium = "cilium"
	// NetworkPluginCilium is the string expression for cilium network plugin config option
	NetworkPluginCilium = NetworkPolicyCilium
	// NetworkPolicyAntrea is the string expression for antrea network policy config option
	NetworkPolicyAntrea = "antrea"
	// NetworkPolicyAzure is the string expression for Azure CNI network policy manager
	NetworkPolicyAzure = "azure"
	// NetworkPluginAzure is the string expression for Azure CNI plugin
	NetworkPluginAzure = "azure"
	// NetworkPluginKubenet is the string expression for kubenet network plugin
	NetworkPluginKubenet = "kubenet"
	// NetworkPluginFlannel is the string expression for flannel network plugin
	NetworkPluginFlannel = "flannel"
	// DefaultGeneratorCode specifies the source generator of the cluster template.
	DefaultGeneratorCode = "agentbaker"
	// DefaultKubernetesKubeletMaxPods is the max pods per kubelet
	DefaultKubernetesKubeletMaxPods = 110
	// DefaultMasterEtcdServerPort is the default etcd server port for Kubernetes master nodes
	DefaultMasterEtcdServerPort = 2380
	// DefaultMasterEtcdClientPort is the default etcd client port for Kubernetes master nodes
	DefaultMasterEtcdClientPort = 2379
	// etcdAccountNameFmt is the name format for a typical etcd account on Cosmos
	etcdAccountNameFmt = "%sk8s"
	// BasicLoadBalancerSku is the string const for Azure Basic Load Balancer
	BasicLoadBalancerSku = "Basic"
	// StandardLoadBalancerSku is the string const for Azure Standard Load Balancer
	StandardLoadBalancerSku = "Standard"
	// AzureStackCloud is the string const for Azure Stack Cloud
	AzureStackCloud = "azurestackcloud"
)

const (
	//DefaultExtensionsRootURL  Root URL for extensions
	DefaultExtensionsRootURL = "https://raw.githubusercontent.com/Azure/aks-engine/master/"
	// DefaultDockerEngineRepo for grabbing docker engine packages
	DefaultDockerEngineRepo = "https://download.docker.com/linux/ubuntu"
	// DefaultDockerComposeURL for grabbing docker images
	DefaultDockerComposeURL = "https://github.com/docker/compose/releases/download"
)

const (
	//DefaultConfigurationScriptRootURL  Root URL for configuration script (used for script extension on RHEL)
	DefaultConfigurationScriptRootURL = "https://raw.githubusercontent.com/Azure/aks-engine/master/parts/"
)

const (
	// kubernetesWindowsAgentCSECommandPS1 privides the command of Windows CSE
	kubernetesWindowsAgentCSECommandPS1 = "windows/csecmd.ps1"
	// kubernetesWindowsAgentCustomDataPS1 is used for generating the customdata of Windows VM
	kubernetesWindowsAgentCustomDataPS1 = "windows/kuberneteswindowssetup.ps1"
	// Windows custom scripts. These should all be listed in baker.go:func GetKubernetesWindowsAgentFunctions

	kubernetesWindowsAgentFunctionsPS1            = "windows/kuberneteswindowsfunctions.ps1"
	kubernetesWindowsConfigFunctionsPS1           = "windows/windowsconfigfunc.ps1"
	kubernetesWindowsContainerdFunctionsPS1       = "windows/windowscontainerdfunc.ps1"
	kubernetesWindowsCsiProxyFunctionsPS1         = "windows/windowscsiproxyfunc.ps1"
	kubernetesWindowsKubeletFunctionsPS1          = "windows/windowskubeletfunc.ps1"
	kubernetesWindowsCniFunctionsPS1              = "windows/windowscnifunc.ps1"
	kubernetesWindowsAzureCniFunctionsPS1         = "windows/windowsazurecnifunc.ps1"
	kubernetesWindowsHostsConfigAgentFunctionsPS1 = "windows/windowshostsconfigagentfunc.ps1"
	kubernetesWindowsOpenSSHFunctionPS1           = "windows/windowsinstallopensshfunc.ps1"
	kubernetesWindowsCalicoFunctionPS1            = "windows/windowscalicofunc.ps1"
	kubernetesWindowsCSEHelperPS1                 = "windows/windowscsehelper.ps1"
	kubernetesWindowsHypervtemplatetoml           = "windows/containerdtemplate.toml"
)

// cloud-init (i.e. ARM customData) source file references
const (
	kubernetesNodeCustomDataYaml      = "linux/cloud-init/nodecustomdata.yml"
	kubernetesCSECommandString        = "linux/cloud-init/artifacts/cse_cmd.sh"
	kubernetesCSEStartScript          = "linux/cloud-init/artifacts/cse_start.sh"
	kubernetesCSEMainScript           = "linux/cloud-init/artifacts/cse_main.sh"
	kubernetesCSEHelpersScript        = "linux/cloud-init/artifacts/cse_helpers.sh"
	kubernetesCSEHelpersScriptUbuntu  = "linux/cloud-init/artifacts/ubuntu/cse_helpers_ubuntu.sh"
	kubernetesCSEHelpersScriptMariner = "linux/cloud-init/artifacts/mariner/cse_helpers_mariner.sh"
	kubernetesCSEInstall              = "linux/cloud-init/artifacts/cse_install.sh"
	kubernetesCSEInstallUbuntu        = "linux/cloud-init/artifacts/ubuntu/cse_install_ubuntu.sh"
	kubernetesCSEInstallMariner       = "linux/cloud-init/artifacts/mariner/cse_install_mariner.sh"
	kubernetesCSEConfig               = "linux/cloud-init/artifacts/cse_config.sh"
	kubernetesCISScript               = "linux/cloud-init/artifacts/cis.sh"
	kubernetesHealthMonitorScript     = "linux/cloud-init/artifacts/health-monitor.sh"
	// kubernetesKubeletMonitorSystemdTimer     = "linux/cloud-init/artifacts/kubelet-monitor.timer" // TODO enable
	kubeadmConfig                             = "linux/cloud-init/artifacts/kubeadm-config.yaml"
	cloudControllerManager                    = "linux/cloud-init/artifacts/cloud-controller-manager.yaml"
	ipMasqAgentConfigmap                      = "linux/cloud-init/artifacts/ip-masq-agent-configmap.yaml"
	corednsAddonManifest                      = "linux/cloud-init/artifacts/coredns.yaml"
	kubeproxyAddonManifest                    = "linux/cloud-init/artifacts/kube-proxy.yaml"
	kubernetesKubeletMonitorSystemdService    = "linux/cloud-init/artifacts/kubelet-monitor.service"
	kubernetesDockerMonitorSystemdTimer       = "linux/cloud-init/artifacts/docker-monitor.timer"
	kubernetesDockerMonitorSystemdService     = "linux/cloud-init/artifacts/docker-monitor.service"
	kubernetesContainerdMonitorSystemdTimer   = "linux/cloud-init/artifacts/containerd-monitor.timer"
	kubernetesContainerdMonitorSystemdService = "linux/cloud-init/artifacts/containerd-monitor.service"
	updateNodeLabelsScript                    = "linux/cloud-init/artifacts/update-node-labels.sh"
	updateNodeLabelsSystemdService            = "linux/cloud-init/artifacts/update-node-labels.service"
	kubernetesCustomSearchDomainsScript       = "linux/cloud-init/artifacts/setup-custom-search-domains.sh"
	kubeletSystemdService                     = "linux/cloud-init/artifacts/kubelet.service"
	kmsSystemdService                         = "linux/cloud-init/artifacts/kms.service"
	aptPreferences                            = "linux/cloud-init/artifacts/apt-preferences"
	dockerClearMountPropagationFlags          = "linux/cloud-init/artifacts/docker_clear_mount_propagation_flags.conf"
	reconcilePrivateHostsScript               = "linux/cloud-init/artifacts/reconcile-private-hosts.sh"
	reconcilePrivateHostsService              = "linux/cloud-init/artifacts/reconcile-private-hosts.service"
	bindMountScript                           = "linux/cloud-init/artifacts/bind-mount.sh"
	bindMountSystemdService                   = "linux/cloud-init/artifacts/bind-mount.service"
	migPartitionScript                        = "linux/cloud-init/artifacts/mig-partition.sh"
	migPartitionSystemdService                = "linux/cloud-init/artifacts/mig-partition.service"

	// scripts and service for enabling ipv6 dual stack
	dhcpv6SystemdService      = "linux/cloud-init/artifacts/dhcpv6.service"
	dhcpv6ConfigurationScript = "linux/cloud-init/artifacts/enable-dhcpv6.sh"
	initAKSCustomCloudScript  = "linux/cloud-init/artifacts/init-aks-custom-cloud.sh"

	ensureNoDupEbtablesScript  = "linux/cloud-init/artifacts/ensure-no-dup.sh"
	ensureNoDupEbtablesService = "linux/cloud-init/artifacts/ensure-no-dup.service"
)

// cloud-init destination file references
const (
	customCloudConfigCSEScriptFilepath   = "/opt/azure/containers/provision_configs_custom_cloud.sh"
	cseHelpersScriptFilepath             = "/opt/azure/containers/provision_source.sh"
	cseHelpersScriptDistroFilepath       = "/opt/azure/containers/provision_source_distro.sh"
	cseInstallScriptFilepath             = "/opt/azure/containers/provision_installs.sh"
	cseInstallScriptDistroFilepath       = "/opt/azure/containers/provision_installs_distro.sh"
	cseConfigScriptFilepath              = "/opt/azure/containers/provision_configs.sh"
	customSearchDomainsCSEScriptFilepath = "/opt/azure/containers/setup-custom-search-domains.sh"
	dhcpV6ServiceCSEScriptFilepath       = "/etc/systemd/system/dhcpv6.service"
	dhcpV6ConfigCSEScriptFilepath        = "/opt/azure/containers/enable-dhcpv6.sh"
	initAKSCustomCloudFilepath           = "/opt/azure/containers/init-aks-custom-cloud.sh"
)

// Kubernetes manifests file references
const (
	kubeSchedulerManifestFilename               = "kubernetesmaster-kube-scheduler.yaml"
	kubeControllerManagerManifestFilename       = "kubernetesmaster-kube-controller-manager.yaml"
	kubeControllerManagerCustomManifestFilename = "kubernetesmaster-kube-controller-manager-custom.yaml"
	kubeAPIServerManifestFilename               = "kubernetesmaster-kube-apiserver.yaml"
	kubeAddonManagerManifestFilename            = "kubernetesmaster-kube-addon-manager.yaml"
)

// addons source and destination file references
const (
	heapsterAddonSourceFilename                    string = "kubernetesmasteraddons-heapster-deployment.yaml"
	heapsterAddonDestinationFilename               string = "kube-heapster-deployment.yaml"
	metricsServerAddonSourceFilename               string = "kubernetesmasteraddons-metrics-server-deployment.yaml"
	metricsServerAddonDestinationFilename          string = "kube-metrics-server-deployment.yaml"
	tillerAddonSourceFilename                      string = "kubernetesmasteraddons-tiller-deployment.yaml"
	tillerAddonDestinationFilename                 string = "kube-tiller-deployment.yaml"
	aadPodIdentityAddonSourceFilename              string = "kubernetesmasteraddons-aad-pod-identity-deployment.yaml"
	aadPodIdentityAddonDestinationFilename         string = "aad-pod-identity-deployment.yaml"
	aciConnectorAddonSourceFilename                string = "kubernetesmasteraddons-aci-connector-deployment.yaml"
	aciConnectorAddonDestinationFilename           string = "aci-connector-deployment.yaml"
	azureDiskCSIAddonSourceFilename                string = "kubernetesmasteraddons-azuredisk-csi-driver-deployment.yaml"
	azureDiskCSIAddonDestinationFilename           string = "azuredisk-csi-driver-deployment.yaml"
	azureFileCSIAddonSourceFilename                string = "kubernetesmasteraddons-azurefile-csi-driver-deployment.yaml"
	azureFileCSIAddonDestinationFilename           string = "azurefile-csi-driver-deployment.yaml"
	clusterAutoscalerAddonSourceFilename           string = "kubernetesmasteraddons-cluster-autoscaler-deployment.yaml"
	clusterAutoscalerAddonDestinationFilename      string = "cluster-autoscaler-deployment.yaml"
	blobfuseFlexVolumeAddonSourceFilename          string = "kubernetesmasteraddons-blobfuse-flexvolume-installer.yaml"
	blobfuseFlexVolumeAddonDestinationFilename     string = "blobfuse-flexvolume-installer.yaml"
	smbFlexVolumeAddonSourceFilename               string = "kubernetesmasteraddons-smb-flexvolume-installer.yaml"
	smbFlexVolumeAddonDestinationFilename          string = "smb-flexvolume-installer.yaml"
	keyvaultFlexVolumeAddonSourceFilename          string = "kubernetesmasteraddons-keyvault-flexvolume-installer.yaml"
	keyvaultFlexVolumeAddonDestinationFilename     string = "keyvault-flexvolume-installer.yaml"
	dashboardAddonSourceFilename                   string = "kubernetesmasteraddons-kubernetes-dashboard-deployment.yaml"
	dashboardAddonDestinationFilename              string = "kubernetes-dashboard-deployment.yaml"
	reschedulerAddonSourceFilename                 string = "kubernetesmasteraddons-kube-rescheduler-deployment.yaml"
	reschedulerAddonDestinationFilename            string = "kube-rescheduler-deployment.yaml"
	nvidiaAddonSourceFilename                      string = "kubernetesmasteraddons-nvidia-device-plugin-daemonset.yaml"
	nvidiaAddonDestinationFilename                 string = "nvidia-device-plugin.yaml"
	containerMonitoringAddonSourceFilename         string = "kubernetesmasteraddons-omsagent-daemonset.yaml"
	containerMonitoringAddonDestinationFilename    string = "omsagent-daemonset.yaml"
	ipMasqAgentAddonSourceFilename                 string = "ip-masq-agent.yaml"
	ipMasqAgentAddonDestinationFilename            string = "ip-masq-agent.yaml"
	azureCNINetworkMonitorAddonSourceFilename      string = "azure-cni-networkmonitor.yaml"
	azureCNINetworkMonitorAddonDestinationFilename string = "azure-cni-networkmonitor.yaml"
	dnsAutoscalerAddonSourceFilename               string = "dns-autoscaler.yaml"
	dnsAutoscalerAddonDestinationFilename          string = "dns-autoscaler.yaml"
	calicoAddonSourceFilename                      string = "kubernetesmasteraddons-calico-daemonset.yaml"
	calicoAddonDestinationFilename                 string = "calico-daemonset.yaml"
	azureNetworkPolicyAddonSourceFilename          string = "kubernetesmasteraddons-azure-npm-daemonset.yaml"
	azureNetworkPolicyAddonDestinationFilename     string = "azure-npm-daemonset.yaml"
	azurePolicyAddonSourceFilename                 string = "azure-policy-deployment.yaml"
	azurePolicyAddonDestinationFilename            string = "azure-policy-deployment.yaml"
	cloudNodeManagerAddonSourceFilename            string = "cloud-node-manager.yaml"
	cloudNodeManagerAddonDestinationFilename       string = "cloud-node-manager.yaml"
	nodeProblemDetectorAddonSourceFilename         string = "node-problem-detector.yaml"
	nodeProblemDetectorAddonDestinationFilename    string = "node-problem-detector.yaml"
	kubeDNSAddonSourceFilename                     string = "kubernetesmasteraddons-kube-dns-deployment.yaml"
	kubeDNSAddonDestinationFilename                string = "kube-dns-deployment.yaml"
	corednsAddonSourceFilename                     string = "coredns.yaml"
	corednsAddonDestinationFilename                string = "coredns.yaml"
	kubeProxyAddonSourceFilename                   string = "kubernetesmasteraddons-kube-proxy-daemonset.yaml"
	kubeProxyAddonDestinationFilename              string = "kube-proxy-daemonset.yaml"
)

const (
	// AADPodIdentityAddonName is the name of the aad-pod-identity addon deployment
	AADPodIdentityAddonName = "aad-pod-identity"
	// ACIConnectorAddonName is the name of the aci-connector addon deployment
	ACIConnectorAddonName = "aci-connector"
	// AppGwIngressAddonName appgw addon
	AppGwIngressAddonName = "appgw-ingress"
)
