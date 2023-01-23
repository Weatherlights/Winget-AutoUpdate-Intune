<#
.SYNOPSIS
Installs and configures Winget-AutoUpdate

.DESCRIPTION
This script runs on a regular bases to read and apply the Winget-AutoUpdate configuration from the registry.
https://github.com/Weatherlights/Winget-AutoUpdate-Intune

#>


$PolicyRegistryLocation = "HKLM:\SOFTWARE\Policies\weatherlights.com\Winget-AutoUpdate";
$PolicyListLocation = $PolicyRegistryLocation + "\List"
$DataDir = "$env:Programdata\Winget-AutoUpdate-Configurator\";
$scriptlocation = $MyInvocation.MyCommand.Path + "\.."

Import-Module "$scriptLocation\WinGet-AutoUpdate-Configurator\Generic.psm1"

<# FUNCTIONS #>

function Write-ListConfigToFile {
    param(
        $FilePath,
        $List
    )

    $parsedList = "";

    ForEach ( $item in $list.PSObject.Properties | where { $_.Name -match "[0-9]+" } )
    {
        $parsedList += $item.Value + "`n"
    }

    Out-File -FilePath $FilePath -InputObject $parsedList
}

# by Thomas Kur from https://github.com/ThomasKur/ModernWorkplaceClientCenter licensed under GPL-3
function Invoke-TranslateMDMEnrollmentType {
    <#
    .SYNOPSIS
         This function translates the MDM Enrollment Type in a readable string.
    .DESCRIPTION
         This function translates the MDM Enrollment Type in a readable string.
 
    .EXAMPLE
         Invoke-TranslateMDMEnrollmentType
    #>
    [OutputType([String])]
    [CmdletBinding()]
    param(
        [Int]$Id
    )
    switch($Id){
        0 {"Not enrolled"}
        6 {"MDM enrolled"}
        13 {"Azure AD joined"}
    }
}

# by Thomas Kur from https://github.com/ThomasKur/ModernWorkplaceClientCenter licensed under GPL-3
function Get-MDMEnrollmentStatus {
    <#
    .Synopsis
    Get Windows 10 MDM Enrollment Status.
 
    .Description
    Get Windows 10 MDM Enrollment Status with Translated Error Codes.
 
    Returns $null if Device is not enrolled to an MDM.
 
    .Example
    # Get Windows 10 MDM Enrollment status
    Get-MDMEnrollmentStatus
    #>
    param()
    #Locate correct Enrollment Key
    $EnrollmentKey = Get-Item -Path HKLM:\SOFTWARE\Microsoft\Enrollments\* | Get-ItemProperty | Where-Object -FilterScript {$null -ne $_.UPN}
    if($EnrollmentKey){
        Add-Member -InputObject $EnrollmentKey -MemberType NoteProperty -Name EnrollmentTypeText -Value (Invoke-TranslateMDMEnrollmentType -Id ($EnrollmentKey.EnrollmentType))
    } else {
        Write-Error "Device is not enrolled to MDM."
    }
    return $EnrollmentKey
}


function Get-DomainJoinStatus {
    <#
    .Synopsis
    Get Windows 10 Domain Join.
 
    .Description
    Get Windows 10 Domain Join Status.
 
    Returns $null if Device is not domain joined.
 
    .Example
    # Get domain join status
    Get-DomainJoinStatus
    #>
    param()
  
    (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
}

function Get-CommandLine {
    param(
        $configuration
    )

    $commandLineArguments = "-silent -DisableWAUAutoUpdate -NoClean -ListPath `"$DataDir`""

    if ( $configuration.NotificationLevel ) {
        $commandLineArguments += " -NotificationLevel " + $configuration.NotificationLevel;
    }

    if ( $configuration.ModsPath ) {
        $commandLineArguments += " -ModsPath " + $configuration.ModsPath;
    }

    if ( $configuration.RunOnMetered ) {
        $commandLineArguments += " -RunOnMetered";
    }

    if ( $configuration.UseWhiteList ) {
        $commandLineArguments += " -UseWhiteList";
    }

    if ( $configuration.UpdatesInterval ) {
        $commandLineArguments += " -UpdatesInterval " + $configuration.UpdatesInterval;
    } else {
        $commandLineArguments += " -UpdatesInterval Never";
    }

    if ( $configuration.UpdatesAtTime ) {
        $commandLineArguments += " -UpdatesAtTime " + $configuration.UpdatesAtTime;
    }

    if ( $configuration.BypassListForUsers ) {
        $commandLineArguments += " -BypassListForUsers";
    }

    if ( $configuration.UpdatesAtLogon ) {
        $commandLineArguments += " -UpdatesAtLogon";
    }

    if ( $configuration.DesktopShortcut ) {
        $commandLineArguments += " -DesktopShortcut";
    }

    if ( $configuration.StartMenuShortcut ) {
        $commandLineArguments += " -StartMenuShortcut";
    }

    if ( $configuration.DoNotUpdate -ne 0) {
        $commandLineArguments += " -DoNotUpdate";
    }

    if ( $configuration.InstallUserContext ) {
        $commandLineArguments += " -InstallUserContext";
    }

    return $commandLineArguments
}


<# MAIN #>

if ( !(Test-Path -Path $DataDir) ) {
    md $DataDir -Force
    Write-LogFile -InputObject "Created non existing directory $DataDir."
}


if ( Test-Path -Path $PolicyRegistryLocation ) {
    $configuration = Get-ItemProperty -Path $PolicyRegistryLocation;   
    Write-LogFile -InputObject "Configuration received from $PolicyRegistryLocation"; 
    if ( Test-Path -Path $PolicyListLocation ) {
        $list = Get-ItemProperty -Path $PolicyListLocation

        $listFileName = "excluded_apps.txt"
        if ( $configuration.UseWhiteList ) {
            $listFileName = "included_apps.txt";
        }
        $ListLocation = "$DataDir\$listFileName";

        Write-ListConfigToFile -FilePath $ListLocation -List $list;

        Write-LogFile -InputObject "Parsed list to $ListLocation."
    } else {
        Write-LogFile -InputObject "No List provided."
    }

    $commandLineArguments = Get-CommandLine -configuration $configuration;
} else {
     Write-LogFile -InputObject "Warning: $PolicyRegistryLocation does not exist yet."
     if ( !(Get-MDMEnrollmentStatus ) -and !(Get-DomainJoinStatus) ) {
        $commandLineArguments = "-silent -DisableWAUAutoUpdate -NoClean -StartMenuShortcut"
     } else {
        $commandLineArguments = Get-CommandLine -configuration $configuration;
     }

}



Write-LogFile -InputObject "Commandline arguments $commandLineArguments generated."
if ( Test-Path "$DataDir\LastCommand.txt" -PathType Leaf ) {
    $previousCommandLineArguments = Get-Content -Path "$DataDir\LastCommand.txt"
} else {
    $previousCommandLineArguments = "";
}
Write-LogFile -InputObject "Previous commandline arguments $previousCommandLineArguments."

$installCommand  = "& `"$scriptlocation\Winget-AutoUpdate-Install.ps1`" $commandLIneArguments"
$uninstallCommand = "& `"$scriptlocation\Winget-AutoUpdate-Install.ps1`" -Uninstall"

if ( $commandLineArguments -ne $previousCommandLineArguments ) {
    if ( $configuration.ReinstallOnRefresh ) {
        iex $uninstallCommand;
        Write-LogFile "Removed WAU for Reinstall."
    }
    iex $installCommand;
    Write-LogFile "Updated WAU."
} else {
    Write-LogFile "Skipped updating WAU."
}


Out-File -FilePath "$DataDir\LastCommand.txt" -Force -InputObject $commandLineArguments;
Write-LogFile -InputObject "Stored commandline arguments."

    $winget_autoupdate_logpath = "$env:Programdata\Winget-AutoUpdate\logs\updates.log"

    if ( Test-PAth -path $winget_autoupdate_logpath ) {
        
    Copy-Item -Path $winget_autoupdate_logpath -Destination "$env:temp\$env:computername-Winget-AutoUpdate-Updates.log" -Force
    Write-LogFile -InputObject "Created copy of logfiles for intune diagnostics."

    # Rotate log since this is not implemented in WAU.
    $size=(Get-Item $winget_autoupdate_logpath).length
    if ( $size -gt 5120000 ) {
        Move-Item -Path $winget_autoupdate_logpath -Destination "$winget_autoupdate_logpath.bak" -Force
        Write-LogFile -InputObject "Rotated Winget-Autoupdate log $winget_autoupdate_logpath."
    }
}