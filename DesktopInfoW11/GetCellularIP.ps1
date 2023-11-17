Start-Sleep -Seconds 5
$cellularNetworkMAC = Get-WmiObject -Query "SELECT MACAddress FROM Win32_NetworkAdapter WHERE NetConnectionID LIKE `"%Cellular%`" AND NOT Description LIKE `"%Microsoft%`"" | Select-Object -Property MACAddress -First 1 | Format-List | Out-String | ForEach-Object { $_.Trim() } | % {$_.replace("MACAddress : ","")} | out-string | % {$_.Trim()}
$cellularConnectivity = Get-WmiObject -Query "SELECT IPEnabled FROM Win32_NetworkAdapterConfiguration WHERE MACAddress = ""$cellularNetworkMAC"" " | Select-Object -Property IPEnabled -First 1 | Format-List | Out-String | ForEach-Object { $_.Trim() } | % {$_.replace("IPEnabled : ","")} | out-string
$cellularNetworkIP = Get-WmiObject -Query "SELECT IPAddress FROM Win32_NetworkAdapterConfiguration WHERE MACAddress = ""$cellularNetworkMAC"" " | Select-Object -Property IPAddress -First 1 | Format-List | Out-String | ForEach-Object { $_.Trim() } | % {$_.replace("IPAddress : {","")} | out-string
$noDeviceOrConnection = " " 

#Is there ANY device in the category
$cellularNonProcessedQuery = Get-WmiObject -Query "SELECT MACAddress FROM Win32_NetworkAdapter WHERE NetConnectionID LIKE `"%Cellular%`" AND NOT Description LIKE `"%Microsoft%`""
$cellularDeviceExists = $cellularNonProcessedQuery -ne $null


if($cellularDeviceExists){
	
	$isCellularConnected = try {
		[bool]::Parse($cellularConnectivity)
	} catch {
		$false
	}
	if($isCellularConnected) {
		$cellularNetworkIP.Split(",")[0] | Format-List | Out-String | ForEach-Object { $_.Trim() }
	}
	
}
else {
	$noDeviceOrConnection | Out-String
}
