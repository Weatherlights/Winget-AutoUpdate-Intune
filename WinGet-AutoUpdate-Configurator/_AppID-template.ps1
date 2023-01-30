<# ARRAYS/VARIABLES #>
$modsPath = "HKLM:\SOFTWARE\Policies\weatherlights.com\Winget-AutoUpdate\Mods"

<# FUNCTIONS #>

function Get-AppIdFromScriptPath {
    param (
        $ScriptPath
    )

    if ( $ScriptPath -match "\\([^\\]+?)\.ps1$" ) {
         $AppId = $matches[1]
    }
    return $AppId

}

function Get-ConfigurationForAppId {
    param(
        [string]$AppId
    )
    if ( Test-Path -Path $modsPath ) {
        $Attributes = Get-ItemProperty -Path $modsPath
        if ( $Attributes.$AppId ) {
            $Data = $Attributes.$AppId
            $Configuration = ConvertFrom-Json $Data;
            if ( $configuration ) {
                $configuration
            }
        }
    }
}

. $PSScriptRoot\_Mods-Functions.ps1


<# MAIN #>
$fullInvocationPath = $MyInvocation.MyCommand.Path

$AppId = Get-AppIdFromScriptPath -ScriptPath $fullInvocationPath;
$Configuration = Get-ConfigurationForAppId -AppId $AppId;

if ( $Configuration ) {
    if ( $Configuration."StopModsProc" ) {
        $Proc = @();
        ForEach ( $processToClose in $Configuration."StopModsProc" ) {
            $processToCloseEXE = $processToClose.Process;
            $Proc += $processToCloseEXE
        }
        Stop-ModsProc $Proc;
    }

    if ( $Configuration."WaitModsProc" ) {
        $Wait = @();
        ForEach ( $processToWaitFor in $Configuration."WaitModsProc" ) {
            $processToWaitForEXE = $processToWaitFor.Process;
            $Wait += $processToWaitForEXE
        }
        Wait-ModsProc $Wait;
    }

    if ( $Configuration."UninstallModsApp" ) {
        $App = @();
        ForEach ( $appToRemove in $Configuration."UninstallModsApp" ) {
            $appToRemoveName = $appToRemove.App;
            $App += $appToRemoveName
        }
        Uninstall-ModsApp $App;
    }

    if ( $Configuration."RemoveModsLnk" ) {
        $Lnk = @();
        ForEach ( $shortcutToRemove in $Configuration."RemoveModsLnk" ) {
            $shortcutPath = $shortcutToRemove.Shortcut;
            $Lnk += $shortcutPath
        }
        Remove-ModsLnk $Lnk;
    }
}
<# EXTRAS #>