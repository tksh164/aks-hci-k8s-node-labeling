param (
    [Parameter(Mandatory)]
    [string] $Label,

    [Parameter(Mandatory)]
    [string] $Value
)

function Get-K8sNodeNamesOnHciNode
{
    Get-CimInstance -Namespace 'root\virtualization\v2' -ClassName 'Msvm_ComputerSystem' -Filter '(Caption = "Virtual Machine") AND (EnabledState = 2)' |
        ForEach-Object -Process {
            $vm = $_
            ($vm | Get-CimAssociatedInstance -ResultClassName 'Msvm_KvpExchangeComponent').GuestIntrinsicExchangeItems |
                ForEach-Object -Process {
                    $kvpExchangeDataItemXmlElement = [xml] $_
                    if ($kvpExchangeDataItemXmlElement.SelectSingleNode('/INSTANCE/PROPERTY[@NAME="Name"]/VALUE[child::text() = "FullyQualifiedDomainName"]') -ne $null) {
                        $kvpExchangeDataItemXmlElement.SelectSingleNode('/INSTANCE/PROPERTY[@NAME="Data"]/VALUE/child::text()').Value
                    }
                }
        }
}

function Get-K8sNodeNamesInAksCluster
{
    kubectl get nodes --output=jsonpath='{range .items[*]}{.metadata.name}{\"\n\"}{end}'
}

$k8sNodeNamesOnHciNode = Get-K8sNodeNamesOnHciNode
Get-K8sNodeNamesInAksCluster | ForEach-Object -Process {
    $k8sNodeName = $_
    if ($k8sNodeNamesOnHciNode -contains $k8sNodeName) {
        # Add a node label "$Label" with "$Value" as the value.
        kubectl label --overwrite nodes $k8sNodeName $Label=$Value
    }
}
