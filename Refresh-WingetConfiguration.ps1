<#
.SYNOPSIS
Installs and configures Winget-AutoUpdate

.DESCRIPTION
This script runs on a regular bases to read and apply the Winget-AutoUpdate configuration from the registry.
https://github.com/Weatherlights/Winget-AutoUpdate-Intune

#>


$forbiddenApps = @(
"Microsoft.Teams.Classic",
"Romanitho.Winget-AutoUpdate"
);

$PolicyRegistryLocation = "HKLM:\SOFTWARE\Policies\weatherlights.com\Winget-AutoUpdate";
$PolicyListLocation = $PolicyRegistryLocation + "\List"
$PolicyModLocation = $PolicyRegistryLocation + "\Mods"
$DataDir = "$env:Programdata\Winget-AutoUpdate-Configurator";
$scriptlocation = $MyInvocation.MyCommand.Path + "\.."
$scriptlocation = (Get-Item $scriptlocation).FullName;

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

    [string[]]$parsedList = @();

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
        $parsedList += $item + "`n"
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

function Invoke-WAURefresh {
    param(
        $configuration
    )
    $WAUConfigLocation = "HKLM:\Software\Romanitho\Winget-AutoUpdate"


    Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_ListPath" -Value  $DataDir;
    Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_DisableAutoUpdate" -Value 1;

    if ( $configuration.NotificationLevel ) {
         Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_NotificationLevel" -Value $configuration.NotificationLevel;
    } else {
         Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_NotificationLevel" -Value "Full";
    }

    if ( $configuration.ModsPath ) {
        
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_ModsPath" -Value $configuration.ModsPath;
    } else {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_ModsPath" -Value "";
    }

    if ( $configuration.RunOnMetered ) {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_DoNotRunOnMetered" -Value  $configuration.RunOnMetered;
        $commandLineArguments += " DONOTRUNONMETERED=0";
    } else {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_DoNotRunOnMetered" -Value  1;
    }

    if ( $configuration.UseWhiteList ) {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_UseWhiteList" -Value  1;
    } else {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_UseWhiteList" -Value  0;
    }

    if ( $configuration.UpdatesInterval ) {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_UpdatesInterval" -Value  $configuration.UpdatesInterval;
    } else {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_UpdatesInterval" -Value  "Never";
    }

    if ( $configuration.UpdatesAtTime ) {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_UpdatesAtTime" -Value  $configuration.UpdatesAtTime;
    }

    if ( $configuration.BypassListForUsers ) {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_BypassListForUsers" -Value  1;
    } else {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_BypassListForUsers" -Value  0;
    }

    if ( $configuration.UpdatesAtLogon ) {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_UpdatesAtLogon" -Value  1;
    } else {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_UpdatesAtLogon" -Value  0;
    }

    if ( $configuration.DesktopShortcut ) {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_DesktopShortcut" -Value  1;
    } else {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_DesktopShortcut" -Value  0;
    }

    if ( $configuration.StartMenuShortcut ) {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_StartMenuShortcut" -Value  1;
    } else {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_StartMenuShortcut" -Value  0;
    }


    if ( $configuration.InstallUserContext ) {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_UserContext" -Value  1;
    } else {
        Set-ItemProperty -Path $WAUConfigLocation -Name "WAU_UserContext" -Value  0;
    }



    return $commandLineArguments

}

function Get-CommandLine {
    param(
        $configuration
    )

    $commandLineArguments = "/qn TRANSFORMS=`"WAUMSI\WAUaaS.mst`" DISABLEWAUAUTOUPDATE=1"

    if ( $configuration.NotificationLevel ) {
        $commandLineArguments += " NOTIFICATIONLEVEL=" + $configuration.NotificationLevel;
    } else {
        $commandLineArguments += " NOTIFICATIONLEVEL=None";
    }

    if ( $configuration.ModsPath ) {
        $commandLineArguments += " MODSPATH=" + $configuration.ModsPath;
    } else {
        $commandLineArguments += " MODSPATH=`"$DataDir\mods`"";
    }

    if ( $configuration.RunOnMetered ) {
        $commandLineArguments += " DONOTRUNONMETERED=0";
    } else {
        $commandLineArguments += " DONOTRUNONMETERED=1";
    }

    if ( $configuration.UseWhiteList ) {
        $commandLineArguments += " USEWHITELIST=1";
    }

    if ( $configuration.UpdatesInterval ) {
        $commandLineArguments += " UPDATESINTERVAL=" + $configuration.UpdatesInterval;
    } else {
        $commandLineArguments += " UPDATESINTERVAL=Never";
    }

    if ( $configuration.UpdatesAtTime ) {
        $commandLineArguments += " UPDATESATTIME=" + $configuration.UpdatesAtTime;
    }

    if ( $configuration.BypassListForUsers ) {
        $commandLineArguments += " BYPASSLISTFORUSERS=1";
    } else {
        $commandLineArguments += " BYPASSLISTFORUSERS=0";
    }

    if ( $configuration.UpdatesAtLogon ) {
        $commandLineArguments += " UPDATESATLOGON=1";
    } else {
        $commandLineArguments += " UPDATESATLOGON=0";
    }


    if ( $configuration.DesktopShortcut ) {
        $commandLineArguments += " DESKTOPSHORTCUT=1";
    } else {
        $commandLineArguments += " DESKTOPSHORTCUT=0";
    }

    if ( $configuration.StartMenuShortcut ) {
        $commandLineArguments += " STARTMENUSHORTCUT=1";
    } else {
        $commandLineArguments += " STARTMENUSHORTCUT=0";
    }

#    if ( $configuration.DoNotUpdate -ne 0) {
#        $commandLineArguments += " -DoNotUpdate";
#    }

    if ( $configuration.InstallUserContext ) {
        $commandLineArguments += " USERCONTEXT=1";
    } else {
        $commandLineArguments += " USERCONTEXT=0";
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

    if ( Test-Path "$DataDir\excluded_apps.txt" ) {
        Remove-Item -Path "$DataDir\excluded_apps.txt" -Force;
    }
    if ( Test-Path "$DataDir\included_apps.txt" ) {
        Remove-Item -Path "$DataDir\included_apps.txt";
    }

    Write-LogFile -InputObject "Configuration received from $PolicyRegistryLocation" -Severity 1; 
    if ( Test-Path -Path $PolicyListLocation ) {
        $registrylist = Get-ItemProperty -Path $PolicyListLocation;
        [string[]]$list = Get-ListToArray -List $registrylist;

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
        Write-LogFile -InputObject "No List provided. Will provide standard apps to remove." -Severity 1
        $ListLocation = "$DataDir\excluded_apps.txt";

        Write-ListConfigToFile -FilePath $ListLocation -List $forbiddenApps;
    }

    
    Invoke-ModCreation;
    
    
} else {
     Write-LogFile -InputObject "Warning: $PolicyRegistryLocation does not exist yet." -Severity 2
     if ( Get-MDMEnrollmentStatus -or Get-DomainJoinStatus ) {
        
        Write-LogFile -InputObject "The client MDM or domain joined. Therefore the default enterprise configuration is enabled." -Severity 1
     } else {
        $commandLineArguments = "/qn TRANSFORMS=`"WAUMSI\WAUaaS.mst`" DISABLEWAUAUTOUPDATE=1"
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

if ( ($configuration | ConvertTo-Json -Depth 1 -Compress) -ne $previousCommandLineArguments ) {
    Invoke-WAURefresh -configuration $configuration;

    if ( $configuration.ReinstallOnRefresh ) {
        & "$scriptlocation\Winget-Autoupdate\config\WAU-MSI_Actions.ps1" -InstallPath "$($scriptlocation)\Winget-Autoupdate" -Uninstall;
        Write-LogFile "Removed WAU for Reinstall." -Severity 1
    }

    & "$scriptlocation\Winget-Autoupdate\config\WAU-MSI_Actions.ps1" -InstallPath "$($scriptlocation)\Winget-Autoupdate";
  
    Write-LogFile "Updated WAU." -Severity 1

    $wauWrapperEXE = Get-WAUWrapperEXE;
    Write-LogFile -InputObject "Retrived wrapper exe $wauWrapperEXE." -Severity 1

    # Overwrite original Winget Tasks with WAUC Tasks. This is allows configuring WAUC as a managed installer.
    $RunWingetAutoupdateAction = New-ScheduledTaskAction -Execute $wauWrapperEXE -Argument "[ARGSSELECTOR|winget-upgrade]"

    #$UserRunWingetAutoupdateAction = New-ScheduledTaskAction -Execute "$scriptlocation\WinGet-AutoUpdate-Configurator\Winget-AutoUpdate.exe" -Argument "user-run"
    $NotifyUserAction = New-ScheduledTaskAction -Execute $wauWrapperEXE -Argument "[ARGSSELECTOR|notify-user]"
    Set-ScheduledTask -TaskName "WAU\Winget-Autoupdate" -Action $RunWingetAutoupdateAction
    
    if ( Get-ScheduledTask -TaskPath "\WAU\" -TaskName "Winget-AutoUpdate-UserContext" -ErrorAction SilentlyContinue ) {
        Set-ScheduledTask -TaskName "WAU\Winget-AutoUpdate-UserContext" -Action $RunWingetAutoupdateAction -ErrorAction SilentlyContinue
    }
    Set-ScheduledTask -TaskName "WAU\Winget-AutoUpdate-Notify" -Action $NotifyUserAction -ErrorAction SilentlyContinue
    Write-LogFile "Set Winget-Autoupdate tasks to run $wauWrapperEXE." -Severity 1

    if ( $configuration.StartMenuShortcut -eq 0) {
        rm "${env:ProgramData}\Microsoft\Windows\Start Menu\Programs\Winget-Autoupdate-aaS" -Recurse -Force;
        Write-LogFile "Deleted start menu shortcuts." -Severity 1
   } else {
        md "${env:ProgramData}\Microsoft\Windows\Start Menu\Programs\Winget-Autoupdate-aaS";
        Set-Shortcut -Target $wauWrapperEXE -Shortcut "${env:ProgramData}\Microsoft\Windows\Start Menu\Programs\Winget-Autoupdate-aaS\Run WAU.lnk" -Arguments "[ARGSSELECTOR|user-run]"
        Set-Shortcut -Target "$scriptlocation\Winget-Autoupdate\logs\updates.log" -Shortcut "${env:ProgramData}\Microsoft\Windows\Start Menu\Programs\Winget-Autoupdate-aaS\Open logs.lnk"
        Write-LogFile "Created start menu shortcuts to run $wauWrapperEXE." -Severity 1
   }

   if ( $configuration.DesktopShortcut ) {
        Set-Shortcut -Target $wauWrapperEXE -Shortcut "${env:Public}\Desktop\Run WAU.lnk" -Arguments "[ARGSSELECTOR|user-run]"
        Write-LogFile "Modified desktop shortcuts to run $wauWrapperEXE." -Severity 1
   } else {
        rm "${env:Public}\Desktop\Run WAU.lnk"
   } 

   if ( $configuration."PinWAUInstallation" -eq 1 ) {
& winget pin add --id Romanitho.Winget-AutoUpdate | Out-Null;
   } elseif ( $configuration."PinWAUInstallation" -eq 0 ) {
& winget pin remove --id Romanitho.Winget-AutoUpdate | Out-Null;
   }

   # Run WAU in case it is not specified otherwise.
   if ( $configuration.DoNotUpdate -ne 0 ) {
        Start-ScheduledTask -TaskName "Winget-Autoupdate";
        Write-LogFile "Starting Winget Autoupdate after setup $wauWrapperEXE." -Severity 1
   }
} else {
    Write-LogFile "Skipped updating WAU." -Severity 1
}


Out-File -FilePath "$DataDir\LastCommand.txt" -Force -InputObject ($configuration | ConvertTo-Json -Depth 1 -Compress);
Write-LogFile -InputObject "Stored commandline arguments." -Severity 1

    $winget_autoupdate_logpath = "$($scriptlocation)\Winget-AutoUpdate\logs\updates.log"

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