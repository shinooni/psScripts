$wifiNetworkMAC = Get-WmiObject -Query "SELECT MACAddress FROM Win32_NetworkAdapter WHERE NetConnectionID LIKE `"%Wi-Fi%`" AND NOT Description LIKE `"%Microsoft%`"" | Select-Object -Property MACAddress -First 1 | Format-List | Out-String | ForEach-Object { $_.Trim() } | % {$_.replace("MACAddress : ","")} | out-string | % {$_.Trim()}
$wifiConnectivity = Get-WmiObject -Query "SELECT IPEnabled FROM Win32_NetworkAdapterConfiguration WHERE MACAddress = ""$wifiNetworkMAC"" " | Select-Object -Property IPEnabled -First 1 | Format-List | Out-String | ForEach-Object { $_.Trim() } | % {$_.replace("IPEnabled : ","")} | out-string
$wifiNetworkIP = Get-WmiObject -Query "SELECT IPAddress FROM Win32_NetworkAdapterConfiguration WHERE MACAddress = ""$wifiNetworkMAC"" " | Select-Object -Property IPAddress -First 1 | Format-List | Out-String | ForEach-Object { $_.Trim() } | % {$_.replace("IPAddress : {","")} | out-string
$noDeviceOrConnection = " "

#Is there ANY device in the category
$wifiNonProcessedQuery = Get-WmiObject -Query "SELECT MACAddress FROM Win32_NetworkAdapter WHERE NetConnectionID LIKE `"%Wi-Fi%`" AND NOT Description LIKE `"%Microsoft%`""
$wifiDeviceExists = $wifiNonProcessedQuery -ne $null


if($wifiDeviceExists){
	
	$iswifiConnected = try {
		[bool]::Parse($wifiConnectivity)
	} catch {
		$false
	}
	if($iswifiConnected) {
		$wifiNetworkIP.Split(",")[0] | Format-List | Out-String | ForEach-Object { $_.Trim() }
	}
	
}
else {
	$noDeviceOrConnection | Out-String
}