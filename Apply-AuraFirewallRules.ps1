
$hosts = (Read-Host "Enter AURA hostnames to apply firewall rules (comma separated)").split(',')
$fwrs = Import-Csv C:\Scripts\Input\aurapoc-fw.csv

ForEach($h in $hosts)
{
    $cs = New-CimSession -ComputerName $h
Foreach($fwr in $fwrs){
$ips = ($fwr.'Remote Address').Split(' ')
New-NetFirewallRule -CimSession $cs -Name $fwr.Name -DisplayName $fwr.Name -Description $fwr.Description -Enabled True -Profile Domain,Public,Private -Action $fwr.Action -LocalAddress $fwr.'Local Address' -RemoteAddress $ips -Protocol $fwr.Protocol -LocalPort $fwr.'Local Port' -RemotePort $fwr.'Remote Port'}
    Remove-CimSession $cs
}


# add1 branch
Write-out "testing branch and merge"