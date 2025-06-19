
# Define variables
write-host "##############################"
write-host "Copy EPM installation package to Target Folder and run it on target device remotely"
write-host "##############################"
# Function to check if a computer is online
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

$remoteComputer = Read-Host -Prompt "Pls input target PC Name"
$remoteComputer=$remoteComputer.trim()
$TargetFoler = Read-Host -Prompt "Pls input target Folder(c:\temp)"
if($TargetFoler)
{$sourcePath=$TargetFoler.trim()}
else
{$TargetFoler="C:\temp"}

$sourcePathUninstall = "\\tiabackup03\Software\Global\Ivanti\Current EPM Agent\UninstallWinClient.exe"

$sourcePath = "\\idcap47\Software\Global\Ivanti\Current EPM Agents\Non Production\*.*"
#$sourcePath1 = Read-Host -Prompt "Pls input Source File path"
if($sourcePath1)
{$sourcePath=$sourcePath1.trim()}
else
{$sourcePath=$sourcePath.trim()}
$SourceFile=Split-Path -Path $sourcePath -Leaf
$SourceFile="SelfContainedEpmAgentInstall.msi"
$sourceComputer=$sourcePath.substring(2,$sourcePath.substring(2,$sourcePath.Length-2).IndexOf("\"))

$TargetFoler1=$TargetFoler -Replace "C:","C$"
$RemotePath = "\\$remoteComputer\$TargetFoler1\"
$RemoteFile = "\\$remoteComputer\$TargetFoler1\SelfContainedEpmAgentInstall.msi"
 
$logPath = "$TargetFoler\install$SourceFile.log"  # Log file path

$installCommand = "msiexec /i $TargetFoler\$SourceFile /quiet /norestart /L*V $logPath"

$UNinstallCommand = "$TargetFoler\UninstallWinClient.exe"
#$installCommand = "msiexec /i C:\production\SelfContainedEpmAgentInstall.msi /quiet /norestart /L*V c:\production\installtest.log"

Write-Host "Target PC:$remoteComputer, File Source:$sourcePath，Traget Folder:$TargetFoler";
#write-host "Traget Folder:$RemotePath  Log File:$logPath"
#write-host "Install Script: $installCommand "

# Check if both source and target computers are online
$isSourceOnline = Test-ComputerOnline -computerName $sourceComputer
$isTargetOnline = Test-ComputerOnline -computerName $remoteComputer

if (-not ($isSourceOnline -and $isTargetOnline)) {
    Write-Host "Source or target computer is offline. Exiting script."
    exit
} else {
    Write-Host "Both source and target computers are online. Proceeding with the script."
}


# Check and create the C:\Temp directory on the target machine
try {
    Invoke-Command -ComputerName $remoteComputer -ScriptBlock {
		param($TargetFoler)
        $tempDir = $TargetFoler
		#write-host $tempDir
        if (-not (Test-Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory | Out-Null
            Write-Host "Directory created: $tempDir"
        } else {
            Write-Host "Directory already exists: $tempDir"
        }
    } -ArgumentList $TargetFoler
} catch {
    Write-Host "Error checking or creating directory: $_"
    exit
}
$TargetInstallpackage=Test-Path -path $RemoteFile -PathType leaf


# Copy the installation package to $remoteComputer
if ( -not $TargetInstallpackage) 
{
	try {
		if ( (Test-Path $sourcePath)) {  
			#Write-Host "Begin Copy UnInstallation package to $remoteComputer, Pls wait..."
			Copy-Item -Path $sourcePathUninstall -Destination $RemotePath -Force
			Write-Host "Begin Copy Installation package to $remoteComputer, Pls wait..."
			Copy-Item -Path $sourcePath -Destination $RemotePath -Force
			Write-Host "Installation package successfully copied to $remoteComputer."
		}
		else
		{Write-Host "Can not find file $sourcePath " }
		
	} catch {
		Write-Host "Error copying installation package: $_"
		exit
	}
}

# Execute the installation command on $remoteComputer
try {
	if ( (Test-Path -path $RemoteFile -PathType leaf)) { 
    Invoke-Command -ComputerName $remoteComputer -ScriptBlock {
        param($installCommand,$UNinstallCommand)
		#Start-Transcript -Path "C:\temp\tlog.log";
		#Start-Process -FilePath $UNinstallCommand -ArgumentList " /NoReboot /FORCECLEAN" -Wait
		#start-process "powershell" -ArgumentList $uninstallCommand   -NoNewWindow  -Wait;
		Get-Process -name "msi*" | stop-process -Force;
		start-process "powershell" -ArgumentList $installCommand   -NoNewWindow  -Wait;
		
		#Stop-Transcript;
    } -ArgumentList $installCommand,$UNinstallCommand;
    Write-Host "Installation package successfully installed on $remoteComputer."
		
	# Check if the log file exists
		try {
			$logExists = Invoke-Command -ComputerName $remoteComputer -ScriptBlock {
				param($logPath)
				Test-Path $logPath
			} -ArgumentList $logPath


			if ($logExists) {
				Write-Host "Installation log generated at: \\$RemotePath\install$SourceFile.log"
			} else {
				Write-Host "Installation log not generated. Please check the installation process."
			}
		} catch {
			Write-Host "Error checking log file: $_"
		}
	
	}
	else
	{Write-Host "Can not find file $RemotePath " }
} catch {
    Write-Host "Error installing on $remoteComputer : $_"
    exit
}
 

