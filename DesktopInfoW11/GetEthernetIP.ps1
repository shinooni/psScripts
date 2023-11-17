$ethernetNetworkMAC = Get-WmiObject -Query "SELECT MACAddress FROM Win32_NetworkAdapter WHERE NetConnectionID LIKE `"%Ethernet%`" AND NOT Description LIKE `"%Microsoft%`"" | Select-Object -Property MACAddress -First 1 | Format-List | Out-String | ForEach-Object { $_.Trim() } | % {$_.replace("MACAddress : ","")} | out-string | % {$_.Trim()}
$ethernetConnectivity = Get-WmiObject -Query "SELECT IPEnabled FROM Win32_NetworkAdapterConfiguration WHERE MACAddress = ""$ethernetNetworkMAC"" " | Select-Object -Property IPEnabled -First 1 | Format-List | Out-String | ForEach-Object { $_.Trim() } | % {$_.replace("IPEnabled : ","")} | out-string
$ethernetNetworkIP = Get-WmiObject -Query "SELECT IPAddress FROM Win32_NetworkAdapterConfiguration WHERE MACAddress = ""$ethernetNetworkMAC"" " | Select-Object -Property IPAddress -First 1 | Format-List | Out-String | ForEach-Object { $_.Trim() } | % {$_.replace("IPAddress : {","")} | out-string
$noDeviceOrConnection = " "

#Is there ANY device in the category
$ethernetNonProcessedQuery = Get-WmiObject -Query "SELECT MACAddress FROM Win32_NetworkAdapter WHERE NetConnectionID LIKE `"%Ethernet%`" AND NOT Description LIKE `"%Microsoft%`""
$ethernetDeviceExists = $ethernetNonProcessedQuery -ne $null


if($ethernetDeviceExists){
	
	$isEthernetConnected = try {
		[bool]::Parse($ethernetConnectivity)
	} catch {
		$false
	}
	if($isEthernetConnected) {
		$ethernetNetworkIP.Split(",")[0] | Format-List | Out-String | ForEach-Object { $_.Trim() }
	}
	
}
else {
	$noDeviceOrConnection | Out-String
}
