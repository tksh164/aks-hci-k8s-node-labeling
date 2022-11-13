#Requires -RunAsAdministrator
#Requires -Version 5

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string] $Label,

    [Parameter(Mandatory)]
    [string] $Value
)

function Get-NormalizedAksVMNameK8sNodeNamePair
{
    $result = @{}
    kubectl get nodes --output=jsonpath='{range .items[*]}{.spec.providerID}{\"\t\"}{.metadata.name}{\"\n\"}{end}' |
        ForEach-Object -Process {
            $providerID, $k8sNodeName = $_ -split "`t"
            $normalizedAksVMName = $providerID.Replace('moc://', '')
            $result[$normalizedAksVMName] = $k8sNodeName
        }
    Write-Verbose -Message ('{0} K8s nodes found in the AKS cluster.' -f $result.Count)
    $result
}

function Get-NormalizedVMNameOnLocalHciNode
{
    $vmNames = Get-VM | Select-Object -ExpandProperty Name | ForEach-Object -Process {
        if ($_.LastIndexOf('-') -gt 0) { $_.Remove($_.LastIndexOf('-')) } else { $_ }
    }
    Write-Verbose -Message ('{0} Hyper-V VMs found on the HCI node "{1}".' -f $vmNames.Length, $env:ComputerName)
    $vmNames
}

$aksVMNameK8sNodeNamePairs = Get-NormalizedAksVMNameK8sNodeNamePair
Get-NormalizedVMNameOnLocalHciNode |
    ForEach-Object -Process {
        $vmName = $_
        if ($aksVMNameK8sNodeNamePairs.ContainsKey($vmName)) {
            $k8sNodeName = $aksVMNameK8sNodeNamePairs[$vmName]
            kubectl label --overwrite node $k8sNodeName $Label=$Value
            Write-Verbose -Message ('Added a label "{0}={1}" to the K8s node "{2}" that running as VM "{3}".' -f $Label, $Value, $k8sNodeName, $vmName)
        }
    }
