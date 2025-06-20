
function CanPing {
	param (
        $ComputerName
    )
   $error.clear()
   $tmp = test-connection $ComputerName -erroraction SilentlyContinue

if (!$?)
       {write-host "Ping failed: $ComputerName "; return $false}
   else
       {write-host "Ping succeeded: $ComputerName"; return $true}
}
function Test-ComputerOnline {
    param (
        [string]$computerName
    )
    try {
        $pingResult = Test-Connection -ComputerName $computerName -Count 2 -Quiet
        return $pingResult
    } catch {
        Write-Host "Error pinging $computerName : $_"
        return $false
    }
}
function InstallGPS {
	param (
        $remoteComputer
    )
$sourcePath = "\\server\Software\Global\Paloalto\GlobalProtect\x64\GlobalProtect64.msi"
<#
	$sourcePath1 = Read-Host -Prompt "Pls input Source File path"
	if($sourcePath1)
	{$sourcePath=$sourcePath1.trim()}
	else
	{$sourcePath=$sourcePath.trim()}
#>
$SourceFile=Split-Path -Path $sourcePath -Leaf
$sourceComputer=$sourcePath.substring(2,$sourcePath.substring(2,$sourcePath.Length-2).IndexOf("\"))

$destinationPath = "\\$remoteComputer\C$\Temp\$SourceFile"
 
$logPath = "C:\Temp\install$SourceFile.log"  # Log file path
$installCommand = "msiexec /i C:\Temp\$SourceFile /quiet /norestart /L*V $logPath"
 

Write-Host "Target PC:$remoteComputer, File Source:$sourcePath";
# Function to check if a computer is online
# Check if both source and target computers are online
$isSourceOnline = Test-ComputerOnline -computerName $sourceComputer
$isTargetOnline = Test-ComputerOnline -computerName $remoteComputer

if (-not ($isSourceOnline -and $isTargetOnline)) {
    Write-Host "Source or target computer is offline. Exiting script."
    exit
} else {
  #  Write-Host "Both source and target computers are online. Proceeding with the script."
}


# Check and create the C:\Temp directory on the target machine
try {
    Invoke-Command -ComputerName $remoteComputer -ScriptBlock {
        $tempDir = "C:\Temp"
        if (-not (Test-Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory | Out-Null
            Write-Host "Directory created: $tempDir"
        } else {
            Write-Host "Directory already exists: $tempDir"
        }
    }
} catch {
    Write-Host "Error checking or creating directory: $_"
    exit
}

# Copy the installation package to $remoteComputer
try {
	if ( (Test-Path $sourcePath)) {  
		Copy-Item -Path $sourcePath -Destination $destinationPath -Force
		Write-Host "Installation package successfully copied to $remoteComputer."
	}
	else
	{Write-Host "Can not find file $sourcePath " }
    
} catch {
    Write-Host "Error copying installation package: $_"
    exit
}

# Execute the installation command on $remoteComputer
try {
	if ( (Test-Path $destinationPath)) { 
    Invoke-Command -ComputerName $remoteComputer -ScriptBlock {
        param($installCommand)
		#Start-Transcript -Path "C:\temp\tlog.log";
		Get-Process -name "msi*" | stop-process -Force;
	 
		start-process "powershell" -ArgumentList $installCommand   -NoNewWindow  -Wait;
		
		#Stop-Transcript;
    } -ArgumentList $installCommand;
    Write-Host "Installation package successfully installed on $remoteComputer."
		
	# Check if the log file exists
		try {
			$logExists = Invoke-Command -ComputerName $remoteComputer -ScriptBlock {
				param($logPath)
				Test-Path $logPath
			} -ArgumentList $logPath

			if ($logExists) {
				Write-Host "Installation log generated at: \\$remoteComputer\C$\Temp\install$SourceFile.log"
			} else {
				Write-Host "Installation log not generated. Please check the installation process."
			}
		} catch {
			Write-Host "Error checking log file: $_"
		}
	
	}
	else
	{Write-Host "Can not find file $destinationPath " }
} catch {
    Write-Host "Error installing on $remoteComputer : $_"
    exit
}
}
function CheckService
{
param (
        $ComputerName
    )
   $error.clear()
 
	$Result= Invoke-Command -ComputerName $ComputerName     -ScriptBlock { Get-Service PanGPS | Select-Object -Property Name, StartType, Status }  
		if($Result)
		{
			write-host "PanGPS Service was installed"
			write-host $result
			Invoke-Command -ComputerName $ComputerName     -ScriptBlock { Get-service PanGPS | Start-Service;Get-Service PanGPS | Select-Object -Property Name, StartType, Status } 
		}
		else
		{
			write-host "PanGPS Service is not installed and try to install it"
			$Result= Invoke-Command -ComputerName $ComputerName     -ScriptBlock { New-Service -Name "PanGPS" -BinaryPathName "C:\Program Files\Palo Alto Networks\GlobalProtect\PanGPS.exe" -DisplayName "PanGPS" -Description "Palo Alto Networks GlobalProtect App for Windows" -StartupType Automatic
			CheckService -computerName $ComputerName  
			}
			
		}
}




write-host "##############################"
write-host "Copy GlobalProtect to Target and install it on target remotely"
write-host "##############################"
##$remoteComputer = Read-Host -Prompt "Pls input target PC Name"
##$remoteComputer=$remoteComputer.trim()
$REMOTEhOSTString = Read-Host -Prompt "Pls input remote host"
		if ( $REMOTEhOSTString) 
		{
			$REMOTEhOSTString=$REMOTEhOSTString -replace " ","";
			$REMOTEhOST=$REMOTEhOSTString -split ","
			write-host "The New Host List $REMOTEhOST"
        }
 foreach ($computername  in $REMOTEhOST )
        {
			if (CanPing -ComputerName $computername)
			{
				 write-host "Check Program installation status on $ComputerName"
				 ##检查GlobalProtect是否安装
				 $Result=Invoke-Command -ComputerName $ComputerName     -ScriptBlock {Get-WmiObject -Class Win32_Product | Select-Object Name, Version, Vendor | where-object name -like "GlobalProtect*"}
					
					 if($Result)
					 {
							write-host "GlobalProtect was installed"
							CheckService -computerName $ComputerName
					}
					else
					{
						write-host "GlobalProtect is not installed, and Begin to install it...."
						InstallGPS -remoteComputer $ComputerName
						CheckService -computerName $ComputerName
						}
				  
				 
				 
			}
		
		
		}
