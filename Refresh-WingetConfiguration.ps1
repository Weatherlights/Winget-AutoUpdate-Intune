<#
.SYNOPSIS
Installs and configures Winget-AutoUpdate

.DESCRIPTION
This script runs on a regular bases to read and apply the Winget-AutoUpdate configuration from the registry.
https://github.com/Weatherlights/Winget-AutoUpdate-Intune

#>


$forbiddenApps = @(
"Microsoft.Edge",
"Microsoft.EdgeWebView2Runtime",
"Microsoft.Office",
"Microsoft.OneDrive",
"Microsoft.Teams",
"Microsoft.Teams.Classic",
"Mozilla.Firefox*",
"TeamViewer.TeamViewer*",
"Microsoft.RemoteDesktopClient",
"Romanitho.Winget-AutoUpdate"
);

$PolicyRegistryLocation = "HKLM:\SOFTWARE\Policies\weatherlights.com\Winget-AutoUpdate";
$PolicyListLocation = $PolicyRegistryLocation + "\List"
$PolicyModLocation = $PolicyRegistryLocation + "\Mods"
$DataDir = "$env:Programdata\Winget-AutoUpdate-Configurator";
$scriptlocation = $MyInvocation.MyCommand.Path + "\.."

Import-Module "$scriptLocation\WinGet-AutoUpdate-Configurator\Generic.psm1"

<# FUNCTIONS #>

function Get-WAUWrapperEXE {
    $arch = (Get-WMIObject -Class Win32_Processor).Architecture;

    $wauWrapperEXE = "$scriptlocation\WinGet-AutoUpdate-Configurator\Winget-AutoUpdate-x86.exe"
    if ( $arch -eq 9 ) {
        $wauWrapperEXE = "$scriptlocation\WinGet-AutoUpdate-Configurator\Winget-AutoUpdate-x64.exe"
    } elseif ( $arch -eq 12 ) {
        $wauWrapperEXE = "$scriptlocation\WinGet-AutoUpdate-Configurator\Winget-AutoUpdate-arm64.exe"
    }
    return $wauWrapperEXE;
}

function Get-ListToArray {
    param(
        $List
    )

    $parsedList = @();

    ForEach ( $item in $list.PSObject.Properties | where { $_.Name -match "[0-9]+" } )
    {
        $parsedList += $item.Value
    }

    return $parsedList;
}

function Add-EntriesToList {
    param(
        $list,
        $EntriesToAdd
    )

    ForEach ( $entry in $EntriesToAdd ) {
        if ( !$list.Contains($entry) ) {
            $list += $entry;
        }

    }
    return $list
}

function Remove-EntriesFromList {
    param(
        $list,
        $EntriesToRemove
    )

    ForEach ( $entry in $EntriesToRemove ) {
        if ( $list.Contains($entry) ) {
            $list = $list | Where-Object { $_ -ne $entry }
        }

    }
    return $list
}

function Write-ListConfigToFile {
    param(
        $FilePath,
        $List
    )

    $parsedList = "";

    ForEach ( $item in $list )
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

    $commandLineArguments = "-silent -DoNotUpdate -DisableWAUAutoUpdate -NoClean"

    if ( $configuration.NotificationLevel ) {
        $commandLineArguments += " -NotificationLevel " + $configuration.NotificationLevel;
    }

    if ( $configuration.ModsPath ) {
        $commandLineArguments += " -ModsPath " + $configuration.ModsPath;
    } else {
        $commandLineArguments += " -ModsPath `"$DataDir\mods`"";
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

#    if ( $configuration.DoNotUpdate -ne 0) {
#        $commandLineArguments += " -DoNotUpdate";
#    }

    if ( $configuration.InstallUserContext ) {
        $commandLineArguments += " -InstallUserContext";
    }

    return $commandLineArguments
}

function Set-Shortcut ($Target, $Shortcut, $Arguments) {
    $WScriptShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WScriptShell.CreateShortcut($Shortcut)
    $Shortcut.TargetPath = $Target
    $Shortcut.Arguments = $Arguments
    $Shortcut.Save()
}

function Invoke-ModCreation {
    $modsDir = "$DataDir\mods"
    
    Write-LogFile -InputObject "Started mod creation." -Severity 1

    if ( Test-Path -Path $PolicyModLocation ) {
        
        Write-LogFile -InputObject "Detected Mods registry location." -Severity 1
        $ModsList = Get-ItemProperty -Path $PolicyModLocation;
        ForEach ( $Mod in $ModsList.PSObject.Properties | where { $_.Name -match "^.*?-(preinstall|upgrade|install|installed|preuninstall|uninstall|uninstalled)$" } )
        {
            $ModName = $Mod.Name;
            Copy-Item -Path "$scriptlocation\WinGet-AutoUpdate-Configurator\_AppID-template.ps1" -Destination "$modsDir\$ModName.ps1" -Force
            Write-LogFile -InputObject "Created mod $ModName." -Severity 1
        }
        ForEach ( $ItemToCleanUpCheck in ( Get-ChildItem $modsDir ) ) {
            $appid = $ItemToCleanUpCheck.BaseName;
            $fullFileName = $ItemToCleanUpCheck.FullName
            
            if ( !$ModsList.$appid -and $appid -ne "_Mods-Functions" ) {
                Remove-Item -Path $fullFileName -Force
                Write-LogFile -InputObject "Removed $fullFileName. Since it is not configured anymore." -Severity 1
            }
        }
        
    } else {
        Write-LogFile -InputObject "No Mods location detected." -Severity 1
        Get-ChildItem $modsDir | where { $_.BaseName -ne "_Mods-Functions" } | Remove-Item;
    }
    Write-LogFile -InputObject "Finished mod creation." -Severity 1
}

<# MAIN #>

if ( !(Test-Path -Path $DataDir) ) {
    md $DataDir -Force
    Write-LogFile -InputObject "Created non existing directory $DataDir." -Severity 1
}


if ( Test-Path -Path $PolicyRegistryLocation ) {
    $configuration = Get-ItemProperty -Path $PolicyRegistryLocation;
    $commandLineArguments = Get-CommandLine -configuration $configuration;
    $commandLineArguments += " -ListPath `"$DataDir\`"" # Append path to the list file.

    Write-LogFile -InputObject "Configuration received from $PolicyRegistryLocation" -Severity 1; 
    if ( Test-Path -Path $PolicyListLocation ) {
        $list = Get-ItemProperty -Path $PolicyListLocation;
        $list = Get-ListToArray -List $list;

        $listFileName = "excluded_apps.txt"
        if ( $configuration.UseWhiteList ) {
            $listFileName = "included_apps.txt";
            $list = Remove-EntriesFromList -list $list -EntriesToRemove $forbiddenApps
        } else {
            $list = Add-EntriesToList -list $list -EntriesToAdd $forbiddenApps
        }
        $ListLocation = "$DataDir\$listFileName";

        Write-ListConfigToFile -FilePath $ListLocation -List $list;

        

        Write-LogFile -InputObject "Parsed list to $ListLocation." -Severity 1
    } else {
        Write-LogFile -InputObject "No List provided." -Severity 1
        $ListLocation = "$DataDir\excluded_apps.txt";

        Write-ListConfigToFile -FilePath $ListLocation -List $forbiddenApps;
    }

    
    Invoke-ModCreation;
    
    
} else {
     Write-LogFile -InputObject "Warning: $PolicyRegistryLocation does not exist yet." -Severity 2
     if ( Get-MDMEnrollmentStatus -or Get-DomainJoinStatus ) {
        $commandLineArguments = Get-CommandLine -configuration $configuration;
        Write-LogFile -InputObject "The client MDM or domain joined. Therefore the default enterprise configuration is enabled." -Severity 1
     } else {
        $commandLineArguments = "-silent -DoNotUpdate -DisableWAUAutoUpdate -NoClean -StartMenuShortcut"
        Write-LogFile -InputObject "The client is not domain joined or MDM enrolled. Therefore the default enduser configuration is enabled." -Severity 1
     }

}

Write-LogFile -InputObject "Commandline arguments $commandLineArguments generated." -Severity 1
if ( Test-Path "$DataDir\LastCommand.txt" -PathType Leaf ) {
    $previousCommandLineArguments = Get-Content -Path "$DataDir\LastCommand.txt"
} else {
    $previousCommandLineArguments = "";
}
Write-LogFile -InputObject "Previous commandline arguments $previousCommandLineArguments." -Severity 1

$installCommand  = "& `"$scriptlocation\Sources\WAU\Winget-AutoUpdate-Install.ps1`" $commandLIneArguments"
$uninstallCommand = "& `"$scriptlocation\Sources\WAU\Winget-AutoUpdate-Install.ps1`" -Uninstall"

if ( $commandLineArguments -ne $previousCommandLineArguments ) {
    if ( $configuration.ReinstallOnRefresh ) {
        iex $uninstallCommand;
        Write-LogFile "Removed WAU for Reinstall." -Severity 1
    }
    iex $installCommand;
    Write-LogFile "Updated WAU." -Severity 1

    if ( 1 ) { # This code is not ready yet.
    $wauWrapperEXE = Get-WAUWrapperEXE;
    Write-LogFile -InputObject "Retrived wrapper exe $wauWrapperEXE." -Severity 1

    # Overwrite original Winget Tasks with WAUC Tasks. This is allows configuring WAUC as a managed installer.
    $RunWingetAutoupdateAction = New-ScheduledTaskAction -Execute $wauWrapperEXE -Argument "[ARGSSELECTOR|winget-upgrade]"

    #$UserRunWingetAutoupdateAction = New-ScheduledTaskAction -Execute "$scriptlocation\WinGet-AutoUpdate-Configurator\Winget-AutoUpdate.exe" -Argument "user-run"
    $NotifyUserAction = New-ScheduledTaskAction -Execute $wauWrapperEXE -Argument "[ARGSSELECTOR|notify-user]"
    Set-ScheduledTask -TaskName "WAU\Winget-Autoupdate" -Action $RunWingetAutoupdateAction
    
    if ( $configuration.InstallUserContext ) {
        Set-ScheduledTask -TaskName "WAU\Winget-AutoUpdate-UserContext" -Action $RunWingetAutoupdateAction -ErrorAction SilentlyContinue
    }
    Set-ScheduledTask -TaskName "WAU\Winget-AutoUpdate-Notify" -Action $NotifyUserAction -ErrorAction SilentlyContinue
    Write-LogFile "Set Winget-Autoupdate tasks to run $wauWrapperEXE." -Severity 1

    if ( $commandLineArguments -match "-StartMenuShortcut" ) {
        Set-Shortcut -Target $wauWrapperEXE -Shortcut "${env:ProgramData}\Microsoft\Windows\Start Menu\Programs\Winget-AutoUpdate (WAU)\WAU - Check for updated Apps.lnk" -Arguments "[ARGSSELECTOR|user-run]"
        Set-Shortcut -Target $wauWrapperEXE -Shortcut "${env:ProgramData}\Microsoft\Windows\Start Menu\Programs\Winget-AutoUpdate (WAU)\WAU - Open logs.lnk" -Arguments "[ARGSSELECTOR|user-run] -Logs"
        Set-Shortcut -Target $wauWrapperEXE -Shortcut "${env:ProgramData}\Microsoft\Windows\Start Menu\Programs\Winget-AutoUpdate (WAU)\WAU - Web Help.lnk" -Arguments "[ARGSSELECTOR|user-run] -Help"
        Write-LogFile "Modified start menu shortcuts to run $wauWrapperEXE." -Severity 1
   }

   if ( $commandLineArguments -match "-DesktopShortcut" ) {
        Set-Shortcut -Target $wauWrapperEXE -Shortcut "${env:Public}\Desktop\WAU - Check for updated Apps.lnk" -Arguments "[ARGSSELECTOR|user-run]"
        Write-LogFile "Modified desktop shortcuts to run $wauWrapperEXE." -Severity 1
   }
   }

   # Run WAU in case it is not specified otherwise.
   if ( $configuration.DoNotUpdate -ne 0 ) {
        Start-ScheduledTask -TaskName "Winget-Autoupdate";
        Write-LogFile "Starting Winget Autoupdate after setup $wauWrapperEXE." -Severity 1
   }
} else {
    Write-LogFile "Skipped updating WAU." -Severity 1
}


Out-File -FilePath "$DataDir\LastCommand.txt" -Force -InputObject $commandLineArguments;
Write-LogFile -InputObject "Stored commandline arguments." -Severity 1

    $winget_autoupdate_logpath = "$env:Programdata\Winget-AutoUpdate\logs\updates.log"

    if ( Test-PAth -path $winget_autoupdate_logpath ) {
        
    Copy-Item -Path $winget_autoupdate_logpath -Destination "$env:temp\$env:computername-Winget-AutoUpdate-Updates.log" -Force
    Write-LogFile -InputObject "Created copy of logfiles for intune diagnostics." -Severity 1

    # Rotate log since this is not implemented in WAU.
    $size=(Get-Item $winget_autoupdate_logpath).length
    if ( $size -gt 5120000 ) {
        Move-Item -Path $winget_autoupdate_logpath -Destination "$winget_autoupdate_logpath.bak" -Force
        Write-LogFile -InputObject "Rotated Winget-Autoupdate log $winget_autoupdate_logpath." -Severity 1
    }
}