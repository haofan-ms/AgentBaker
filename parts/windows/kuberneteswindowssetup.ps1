<#
    .SYNOPSIS
        Provisions VM as a Kubernetes agent.

    .DESCRIPTION
        Provisions VM as a Kubernetes agent.

        The parameters passed in are required, and will vary per-deployment.

        Notes on modifying this file:
        - This file extension is PS1, but it is actually used as a template from pkg/engine/template_generator.go
        - All of the lines that have braces in them will be modified. Please do not change them here, change them in the Go sources
        - Single quotes are forbidden, they are reserved to delineate the different members for the ARM template concat() call
#>
[CmdletBinding(DefaultParameterSetName="Standard")]
param(
    [string]
    [ValidateNotNullOrEmpty()]
    $MasterIP,

    [parameter()]
    [ValidateNotNullOrEmpty()]
    $KubeDnsServiceIp,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $MasterFQDNPrefix,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $Location,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $AgentKey,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $AADClientId,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $AADClientSecret, # base64

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $NetworkAPIVersion,

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    $TargetEnvironment,

    [string]
    $UserAssignedClientID
)

# These globals will not change between nodes in the same cluster, so they are not
# passed as powershell parameters

## SSH public keys to add to authorized_keys
$global:SSHKeys = @( {{ GetSshPublicKeysPowerShell }} )

## Certificates generated by aks-engine
$global:CACertificate = "{{GetParameter "caCertificate"}}"
$global:AgentCertificate = "{{GetParameter "clientCertificate"}}"

## Download sources provided by aks-engine
$global:KubeBinariesPackageSASURL = "{{GetParameter "kubeBinariesSASURL"}}"
$global:WindowsKubeBinariesURL = "{{GetParameter "windowsKubeBinariesURL"}}"
$global:KubeBinariesVersion = "{{GetParameter "kubeBinariesVersion"}}"
$global:ContainerdUrl = "{{GetParameter "windowsContainerdURL"}}"
$global:ContainerdSdnPluginUrl = "{{GetParameter "windowsSdnPluginURL"}}"

## Docker Version
$global:DockerVersion = "{{GetParameter "windowsDockerVersion"}}"

## ContainerD Usage
$global:ContainerRuntime = "{{GetParameter "containerRuntime"}}"
$global:DefaultContainerdWindowsSandboxIsolation = "{{GetParameter "defaultContainerdWindowsSandboxIsolation"}}"
$global:ContainerdWindowsRuntimeHandlers = "{{GetParameter "containerdWindowsRuntimeHandlers"}}"

# To support newer Windows OS version, we need to support set ContainerRuntime,
# ContainerdWindowsRuntimeHandlers and DefaultContainerdWindowsSandboxIsolation per agent pool but
# current code does not support this. Below is a workaround to set contianer
# runtime variables per Windows OS version.
#
# Set default values for container runtime variables for AKS Windows 2004
if ($([System.Environment]::OSVersion.Version).Build -eq "19041") {
    $global:ContainerRuntime = "containerd"
    $global:ContainerdWindowsRuntimeHandlers = "17763,19041"
    $global:DefaultContainerdWindowsSandboxIsolation = "process"
}

{{if IsAKSCustomCloud}}
$global:ContainerRuntime = "docker"
{{end}}

## VM configuration passed by Azure
$global:WindowsTelemetryGUID = "{{GetParameter "windowsTelemetryGUID"}}"
{{if eq GetIdentitySystem "adfs"}}
$global:TenantId = "adfs"
{{else}}
$global:TenantId = "{{GetVariable "tenantID"}}"
{{end}}
$global:SubscriptionId = "{{GetVariable "subscriptionId"}}"
$global:ResourceGroup = "{{GetVariable "resourceGroup"}}"
$global:VmType = "{{GetVariable "vmType"}}"
$global:SubnetName = "{{GetVariable "subnetName"}}"
# NOTE: MasterSubnet is still referenced by `kubeletstart.ps1` and `windowsnodereset.ps1`
# for case of Kubenet
$global:MasterSubnet = ""
$global:SecurityGroupName = "{{GetVariable "nsgName"}}"
$global:VNetName = "{{GetVariable "virtualNetworkName"}}"
$global:RouteTableName = "{{GetVariable "routeTableName"}}"
$global:PrimaryAvailabilitySetName = "{{GetVariable "primaryAvailabilitySetName"}}"
$global:PrimaryScaleSetName = "{{GetVariable "primaryScaleSetName"}}"

$global:KubeClusterCIDR = "{{GetParameter "kubeClusterCidr"}}"
$global:KubeServiceCIDR = "{{GetParameter "kubeServiceCidr"}}"
$global:VNetCIDR = "{{GetParameter "vnetCidr"}}"
{{if IsKubernetesVersionGe "1.16.0"}}
$global:KubeletNodeLabels = "{{GetAgentKubernetesLabels . }}"
{{else}}
$global:KubeletNodeLabels = "{{GetAgentKubernetesLabelsDeprecated . }}"
{{end}}
$global:KubeletConfigArgs = @( {{GetKubeletConfigKeyValsPsh .KubernetesConfig }} )

$global:KubeproxyFeatureGates = @( {{GetKubeProxyFeatureGatesPsh}} )

$global:UseManagedIdentityExtension = "{{GetVariable "useManagedIdentityExtension"}}"
$global:UseInstanceMetadata = "{{GetVariable "useInstanceMetadata"}}"

$global:LoadBalancerSku = "{{GetVariable "loadBalancerSku"}}"
$global:ExcludeMasterFromStandardLB = "{{GetVariable "excludeMasterFromStandardLB"}}"


# Windows defaults, not changed by aks-engine
$global:CacheDir = "c:\akse-cache"
$global:KubeDir = "c:\k"
$global:HNSModule = [Io.path]::Combine("$global:KubeDir", "hns.psm1")

$global:KubeDnsSearchPath = "svc.cluster.local"

$global:CNIPath = [Io.path]::Combine("$global:KubeDir", "cni")
$global:NetworkMode = "L2Bridge"
$global:CNIConfig = [Io.path]::Combine($global:CNIPath, "config", "`$global:NetworkMode.conf")
$global:CNIConfigPath = [Io.path]::Combine("$global:CNIPath", "config")


$global:AzureCNIDir = [Io.path]::Combine("$global:KubeDir", "azurecni")
$global:AzureCNIBinDir = [Io.path]::Combine("$global:AzureCNIDir", "bin")
$global:AzureCNIConfDir = [Io.path]::Combine("$global:AzureCNIDir", "netconf")

# Azure cni configuration
# $global:NetworkPolicy = "{{GetParameter "networkPolicy"}}" # BUG: unused
$global:NetworkPlugin = "{{GetParameter "networkPlugin"}}"
$global:VNetCNIPluginsURL = "{{GetParameter "vnetCniWindowsPluginsURL"}}"
$global:IsDualStackEnabled = {{if IsIPv6DualStackFeatureEnabled}}$true{{else}}$false{{end}}

# Telemetry settings
$global:EnableTelemetry = [System.Convert]::ToBoolean("{{GetVariable "enableTelemetry" }}");
$global:TelemetryKey = "{{GetVariable "applicationInsightsKey" }}";

# CSI Proxy settings
$global:EnableCsiProxy = [System.Convert]::ToBoolean("{{GetVariable "windowsEnableCSIProxy" }}");
$global:CsiProxyUrl = "{{GetVariable "windowsCSIProxyURL" }}";

# Hosts Config Agent settings
$global:EnableHostsConfigAgent = [System.Convert]::ToBoolean("{{ EnableHostsConfigAgent }}");

$global:ProvisioningScriptsPackageUrl = "{{GetVariable "windowsProvisioningScriptsPackageURL" }}";

# PauseImage
$global:WindowsPauseImageURL = "{{GetVariable "windowsPauseImageURL" }}";
$global:AlwaysPullWindowsPauseImage = [System.Convert]::ToBoolean("{{GetVariable "alwaysPullWindowsPauseImage" }}");

# Calico
$global:WindowsCalicoPackageURL = "{{GetVariable "windowsCalicoPackageURL" }}";

# Base64 representation of ZIP archive
$zippedFiles = "{{ GetKubernetesWindowsAgentFunctions }}"

# Extract ZIP from script
[io.file]::WriteAllBytes("scripts.zip", [System.Convert]::FromBase64String($zippedFiles))
Expand-Archive scripts.zip -DestinationPath "C:\\AzureData\\"

# Dot-source scripts with functions that are called in this script
. c:\AzureData\windows\kuberneteswindowsfunctions.ps1
. c:\AzureData\windows\windowsconfigfunc.ps1
. c:\AzureData\windows\windowskubeletfunc.ps1
. c:\AzureData\windows\windowscnifunc.ps1
. c:\AzureData\windows\windowsazurecnifunc.ps1
. c:\AzureData\windows\windowscsiproxyfunc.ps1
. c:\AzureData\windows\windowsinstallopensshfunc.ps1
. c:\AzureData\windows\windowscontainerdfunc.ps1
. c:\AzureData\windows\windowshostsconfigagentfunc.ps1
. c:\AzureData\windows\windowscalicofunc.ps1

$useContainerD = ($global:ContainerRuntime -eq "containerd")
$global:KubeClusterConfigPath = "c:\k\kubeclusterconfig.json"

try
{
    # Set to false for debugging.  This will output the start script to
    # c:\AzureData\CustomDataSetupScript.log, and then you can RDP
    # to the windows machine, and run the script manually to watch
    # the output.
    if ($true) {
        Write-Log ".\CustomDataSetupScript.ps1 -MasterIP $MasterIP -KubeDnsServiceIp $KubeDnsServiceIp -MasterFQDNPrefix $MasterFQDNPrefix -Location $Location -AADClientId $AADClientId -NetworkAPIVersion $NetworkAPIVersion -TargetEnvironment $TargetEnvironment"

        if ($global:EnableTelemetry) {
            $global:globalTimer = [System.Diagnostics.Stopwatch]::StartNew()

            $configAppInsightsClientTimer = [System.Diagnostics.Stopwatch]::StartNew()
            # Get app insights binaries and set up app insights client
            mkdir c:\k\appinsights
            DownloadFileOverHttp -Url "https://globalcdn.nuget.org/packages/microsoft.applicationinsights.2.11.0.nupkg" -DestinationPath "c:\k\appinsights\microsoft.applicationinsights.2.11.0.zip"
            Expand-Archive -Path "c:\k\appinsights\microsoft.applicationinsights.2.11.0.zip" -DestinationPath "c:\k\appinsights"
            $appInsightsDll = "c:\k\appinsights\lib\net46\Microsoft.ApplicationInsights.dll"
            [Reflection.Assembly]::LoadFile($appInsightsDll)
            $conf = New-Object "Microsoft.ApplicationInsights.Extensibility.TelemetryConfiguration"
            $conf.DisableTelemetry = -not $global:EnableTelemetry
            $conf.InstrumentationKey = $global:TelemetryKey
            $global:AppInsightsClient = New-Object "Microsoft.ApplicationInsights.TelemetryClient"($conf)

            $global:AppInsightsClient.Context.Properties["correlation_id"] = New-Guid
            $global:AppInsightsClient.Context.Properties["cri"] = $global:ContainerRuntime
            # TODO: Update once containerd versioning story is decided
            $global:AppInsightsClient.Context.Properties["cri_version"] = if ($global:ContainerRuntime -eq "docker") { $global:DockerVersion } else { "" }
            $global:AppInsightsClient.Context.Properties["k8s_version"] = $global:KubeBinariesVersion
            $global:AppInsightsClient.Context.Properties["lb_sku"] = $global:LoadBalancerSku
            $global:AppInsightsClient.Context.Properties["location"] = $Location
            $global:AppInsightsClient.Context.Properties["os_type"] = "windows"
            $global:AppInsightsClient.Context.Properties["os_version"] = Get-WindowsVersion
            $global:AppInsightsClient.Context.Properties["network_plugin"] = $global:NetworkPlugin
            $global:AppInsightsClient.Context.Properties["network_plugin_version"] = Get-CniVersion
            $global:AppInsightsClient.Context.Properties["network_mode"] = $global:NetworkMode
            $global:AppInsightsClient.Context.Properties["subscription_id"] = $global:SubscriptionId

            $vhdId = ""
            if (Test-Path "c:\vhd-id.txt") {
                $vhdId = Get-Content "c:\vhd-id.txt"
            }
            $global:AppInsightsClient.Context.Properties["vhd_id"] = $vhdId

            $imdsProperties = Get-InstanceMetadataServiceTelemetry
            foreach ($key in $imdsProperties.keys) {
                $global:AppInsightsClient.Context.Properties[$key] = $imdsProperties[$key]
            }

            $configAppInsightsClientTimer.Stop()
            $global:AppInsightsClient.TrackMetric("Config-AppInsightsClient", $configAppInsightsClientTimer.Elapsed.TotalSeconds)
        }

        # Install OpenSSH if SSH enabled
        $sshEnabled = [System.Convert]::ToBoolean("{{ WindowsSSHEnabled }}")

        if ( $sshEnabled ) {
            Write-Log "Install OpenSSH"
            if ($global:EnableTelemetry) {
                $installOpenSSHTimer = [System.Diagnostics.Stopwatch]::StartNew()
            }
            Install-OpenSSH -SSHKeys $SSHKeys
            if ($global:EnableTelemetry) {
                $installOpenSSHTimer.Stop()
                $global:AppInsightsClient.TrackMetric("Install-OpenSSH", $installOpenSSHTimer.Elapsed.TotalSeconds)
            }
        }

        Write-Log "Apply telemetry data setting"
        Set-TelemetrySetting -WindowsTelemetryGUID $global:WindowsTelemetryGUID

        Write-Log "Resize os drive if possible"
        if ($global:EnableTelemetry) {
            $resizeTimer = [System.Diagnostics.Stopwatch]::StartNew()
        }
        Resize-OSDrive
        if ($global:EnableTelemetry) {
            $resizeTimer.Stop()
            $global:AppInsightsClient.TrackMetric("Resize-OSDrive", $resizeTimer.Elapsed.TotalSeconds)
        }

        Write-Log "Initialize data disks"
        Initialize-DataDisks

        Write-Log "Create required data directories as needed"
        Initialize-DataDirectories

        New-Item -ItemType Directory -Path "c:\k" -Force | Out-Null
        Get-ProvisioningScripts

        Write-KubeClusterConfig -MasterIP $MasterIP -KubeDnsServiceIp $KubeDnsServiceIp

        if ($useContainerD) {
            Write-Log "Installing ContainerD"
            if ($global:EnableTelemetry) {
                $containerdTimer = [System.Diagnostics.Stopwatch]::StartNew()
            }
            $cniBinPath = $global:AzureCNIBinDir
            $cniConfigPath = $global:AzureCNIConfDir
            if ($global:NetworkPlugin -eq "kubenet") {
                $cniBinPath = $global:CNIPath
                $cniConfigPath = $global:CNIConfigPath
            }
            Install-Containerd -ContainerdUrl $global:ContainerdUrl -CNIBinDir $cniBinPath -CNIConfDir $cniConfigPath
            if ($global:EnableTelemetry) {
                $containerdTimer.Stop()
                $global:AppInsightsClient.TrackMetric("Install-ContainerD", $containerdTimer.Elapsed.TotalSeconds)
            }
            # TODO: disable/uninstall Docker later
        } else {
            Write-Log "Install docker"
            if ($global:EnableTelemetry) {
                $dockerTimer = [System.Diagnostics.Stopwatch]::StartNew()
            }
            Install-Docker -DockerVersion $global:DockerVersion
            Set-DockerLogFileOptions
            if ($global:EnableTelemetry) {
                $dockerTimer.Stop()
                $global:AppInsightsClient.TrackMetric("Install-Docker", $dockerTimer.Elapsed.TotalSeconds)
            }
        }

        Write-Log "Download kubelet binaries and unzip"
        Get-KubePackage -KubeBinariesSASURL $global:KubeBinariesPackageSASURL

        # this overwrite the binaries that are download from the custom packge with binaries
        # The custom package has a few files that are nessary for future steps (nssm.exe)
        # this is a temporary work around to get the binaries until we depreciate
        # custom package and nssm.exe as defined in #3851.
        if ($global:WindowsKubeBinariesURL){
            Write-Log "Overwriting kube node binaries from $global:WindowsKubeBinariesURL"
            Get-KubeBinaries -KubeBinariesURL $global:WindowsKubeBinariesURL
        }

        # For AKSClustomCloud, TargetEnvironment must be set to AzureStackCloud
        Write-Log "Write Azure cloud provider config"
        Write-AzureConfig `
            -KubeDir $global:KubeDir `
            -AADClientId $AADClientId `
            -AADClientSecret $([System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($AADClientSecret))) `
            -TenantId $global:TenantId `
            -SubscriptionId $global:SubscriptionId `
            -ResourceGroup $global:ResourceGroup `
            -Location $Location `
            -VmType $global:VmType `
            -SubnetName $global:SubnetName `
            -SecurityGroupName $global:SecurityGroupName `
            -VNetName $global:VNetName `
            -RouteTableName $global:RouteTableName `
            -PrimaryAvailabilitySetName $global:PrimaryAvailabilitySetName `
            -PrimaryScaleSetName $global:PrimaryScaleSetName `
            -UseManagedIdentityExtension $global:UseManagedIdentityExtension `
            -UserAssignedClientID $UserAssignedClientID `
            -UseInstanceMetadata $global:UseInstanceMetadata `
            -LoadBalancerSku $global:LoadBalancerSku `
            -ExcludeMasterFromStandardLB $global:ExcludeMasterFromStandardLB `
            -TargetEnvironment {{if IsAKSCustomCloud}}"AzureStackCloud"{{else}}$TargetEnvironment{{end}} 

        # we borrow the logic of AzureStackCloud to achieve AKSCustomCloud. 
        # In case of AKSCustomCloud, customer cloud env will be loaded from azurestackcloud.json 
        {{if IsAKSCustomCloud}}
        $azureStackConfigFile = [io.path]::Combine($global:KubeDir, "azurestackcloud.json")
        $envJSON = "{{ GetBase64EncodedEnvironmentJSON }}"
        [io.file]::WriteAllBytes($azureStackConfigFile, [System.Convert]::FromBase64String($envJSON))
        {{end}}

        Write-Log "Write ca root"
        Write-CACert -CACertificate $global:CACertificate `
            -KubeDir $global:KubeDir

        if ($global:EnableCsiProxy) {
            New-CsiProxyService -CsiProxyPackageUrl $global:CsiProxyUrl -KubeDir $global:KubeDir
        }

        Write-Log "Write kube config"
        Write-KubeConfig -CACertificate $global:CACertificate `
            -KubeDir $global:KubeDir `
            -MasterFQDNPrefix $MasterFQDNPrefix `
            -MasterIP $MasterIP `
            -AgentKey $AgentKey `
            -AgentCertificate $global:AgentCertificate

        if ($global:EnableHostsConfigAgent) {
             Write-Log "Starting hosts config agent"
             New-HostsConfigService
         }

        Write-Log "Create the Pause Container kubletwin/pause"
        if ($global:EnableTelemetry) {
            $infraContainerTimer = [System.Diagnostics.Stopwatch]::StartNew()
        }
        New-InfraContainer -KubeDir $global:KubeDir -ContainerRuntime $global:ContainerRuntime
        if ($global:EnableTelemetry) {
            $infraContainerTimer.Stop()
            $global:AppInsightsClient.TrackMetric("New-InfraContainer", $infraContainerTimer.Elapsed.TotalSeconds)
        }

        if (-not (Test-ContainerImageExists -Image "kubletwin/pause" -ContainerRuntime $global:ContainerRuntime)) {
            Write-Log "Could not find container with name kubletwin/pause"
            if ($useContainerD) {
                $o = ctr -n k8s.io image list
                Write-Log $o
            } else {
                $o = docker image list
                Write-Log $o
            }
            throw "kubletwin/pause container does not exist!"
        }

        Write-Log "Configuring networking with NetworkPlugin:$global:NetworkPlugin"

        # Configure network policy.
        Get-HnsPsm1 -HNSModule $global:HNSModule
        Import-Module $global:HNSModule

        Write-Log "Installing Azure VNet plugins"
        Install-VnetPlugins -AzureCNIConfDir $global:AzureCNIConfDir `
            -AzureCNIBinDir $global:AzureCNIBinDir `
            -VNetCNIPluginsURL $global:VNetCNIPluginsURL

        Set-AzureCNIConfig -AzureCNIConfDir $global:AzureCNIConfDir `
            -KubeDnsSearchPath $global:KubeDnsSearchPath `
            -KubeClusterCIDR $global:KubeClusterCIDR `
            -KubeServiceCIDR $global:KubeServiceCIDR `
            -VNetCIDR $global:VNetCIDR `
            -IsAzureStack {{if IsAKSCustomCloud}}$true{{else}}$false{{end}} `
            -IsDualStackEnabled $global:IsDualStackEnabled

        if ($TargetEnvironment -ieq "AzureStackCloud") {
            GenerateAzureStackCNIConfig `
                -TenantId $global:TenantId `
                -SubscriptionId $global:SubscriptionId `
                -ResourceGroup $global:ResourceGroup `
                -AADClientId $AADClientId `
                -KubeDir $global:KubeDir `
                -AADClientSecret $([System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($AADClientSecret))) `
                -NetworkAPIVersion $NetworkAPIVersion `
                -AzureEnvironmentFilePath $([io.path]::Combine($global:KubeDir, "azurestackcloud.json"))
        }

        New-ExternalHnsNetwork -IsDualStackEnabled $global:IsDualStackEnabled

        Install-KubernetesServices `
            -KubeDir $global:KubeDir

        Get-LogCollectionScripts

        Write-Log "Disable Internet Explorer compat mode and set homepage"
        Set-Explorer

        Write-Log "Adjust pagefile size"
        Adjust-PageFileSize

        Write-Log "Start preProvisioning script"
        PREPROVISION_EXTENSION

        Write-Log "Update service failure actions"
        Update-ServiceFailureActions -ContainerRuntime $global:ContainerRuntime

        Adjust-DynamicPortRange
        Register-LogsCleanupScriptTask
        Register-NodeResetScriptTask
        Register-NodeLabelSyncScriptTask
        Update-DefenderPreferences

        if ($windowsSecureTlsEnabled) {
            Write-Host "Enable secure TLS protocols"
            try {
                . C:\k\windowssecuretls.ps1
                Enable-SecureTls
            }
            catch {
                Set-ExitCode -ExitCode $global:WINDOWS_CSE_ERROR_ENABLE_SECURE_TLS -ErrorMessage $_
            }
        }

        Enable-FIPSMode -FipsEnabled $fipsEnabled
        if ($global:WindowsGmsaPackageUrl) {
            Write-Log "Start to install Windows gmsa package"
            Install-GmsaPlugin -GmsaPackageUrl $global:WindowsGmsaPackageUrl
        }

        Check-APIServerConnectivity -MasterIP $MasterIP -RetryInterval 10 -ConnectTimeout 3 -MaxRetryCount 360

        if ($global:WindowsCalicoPackageURL) {
            Write-Log "Start calico installation"
            Start-InstallCalico -RootDir "c:\" -KubeServiceCIDR $global:KubeServiceCIDR -KubeDnsServiceIp $KubeDnsServiceIp
        }

        if (Test-Path $CacheDir)
        {
            Write-Log "Removing aks-engine bits cache directory"
            Remove-Item $CacheDir -Recurse -Force
        }

        if ($global:EnableTelemetry) {
            $global:globalTimer.Stop()
            $global:AppInsightsClient.TrackMetric("TotalDuration", $global:globalTimer.Elapsed.TotalSeconds)
            $global:AppInsightsClient.Flush()
        }

        Write-Log "Setup Complete, reboot computer"
        Restart-Computer
    }
    else
    {
        # keep for debugging purposes
        Write-Log ".\CustomDataSetupScript.ps1 -MasterIP $MasterIP -KubeDnsServiceIp $KubeDnsServiceIp -MasterFQDNPrefix $MasterFQDNPrefix -Location $Location -AgentKey $AgentKey -AADClientId $AADClientId -AADClientSecret $AADClientSecret -NetworkAPIVersion $NetworkAPIVersion -TargetEnvironment $TargetEnvironment"
    }
}
catch
{
    if ($global:EnableTelemetry) {
        $exceptionTelemtry = New-Object "Microsoft.ApplicationInsights.DataContracts.ExceptionTelemetry"
        $exceptionTelemtry.Exception = $_.Exception
        $global:AppInsightsClient.TrackException($exceptionTelemtry)
        $global:AppInsightsClient.Flush()
    }

    # Add timestamp in the logs
    Write-Log $_
    throw $_
}

