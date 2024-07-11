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

    if ( $Configuration."StopModsSvc" ) {
        $Svc = @();
        ForEach ( $StopModsSvcItem in $Configuration."StopModsSvc" ) {
            $servicesToStop = $StopModsSvcItem.Service;
            $Svc += $servicesToStop
        }
        Stop-ModsSvc $Svc;
    }

    if ( $Configuration."InstallWingetID" ) {
        $WingetIDInst = @();
        ForEach ( $item in $Configuration."InstallWingetID" ) {
            $wingetid = $item.wingetid;
            $WingetIDInst += $wingetid
        }
        Install-WingetID $WingetIDInst;
    }

    if ( $Configuration."UninstallWingetID" ) {
        $WingetIDUninst = @();
        ForEach ( $item in $Configuration."UninstallWingetID" ) {
            $wingetid = $item.wingetid;
            $WingetIDUninst += $wingetid
        }
        Uninstall-WingetID $WingetIDUninst;
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

    if ( $Configuration."AddModsReg" ) {
        ForEach ( $AddModsReg in $Configuration."AddModsReg" ) {
            $AddKey = $AddModsReg.AddKey;
            $AddValue = $AddModsReg.AddValue;
            $AddTypeData = $AddModsReg.AddTypeData;
            $AddType = $AddModsReg.AddType;
        
            Add-ModsReg $AddKey $AddValue $AddTypeData $AddType
        }
    }

    if ( $Configuration."RemoveModsReg" ) {
        ForEach ( $RemoveModsReg in $Configuration."RemoveModsReg" ) {
            $DelKey = $RemoveModsReg.DelKey;
            $DelValue = $RemoveModsReg.DelValue;
        
            Remove-ModsReg $DelKey $DelValue;
        }
    }

    if ( $Configuration."InvokeModsApp" ) {
        ForEach ( $InvokeModsApp in $Configuration."RemoveModsReg" ) {
            $Run = $InvokeModsApp.Run;
            $RunSwitch = $InvokeModsApp.RunSwitch;
            $RunWait = $InvokeModsApp.RunWait;
            $User = $InvokeModsApp.User;
        
            Invoke-ModsApp $Run $RunSwitch $RunWait $User;
        }
    }

    if ( $Configuration."RemoveModsFile" ) {
        $DelFile = @();
        ForEach ( $RemoveModsFile in $Configuration."RemoveModsFile" ) {
            $fileToBeRemoved = $RemoveModsFile.File;
            $DelFile += $fileToBeRemoved;
        }
     
        Remove-ModsReg $DelFile;  
    }

    if ( $Configuration."RenameModsFile" ) {
        ForEach ( $RenameModsFile in $Configuration."RenameModsFile" ) {
            $RenFile = $RenameModsFile.RenFile;
            $NewName = $RenameModsFile.NewName;
        
            Rename-ModsFile $RenFile $NewName;
        }
    }

    if ( $Configuration."CopyModsFile" ) {
        ForEach ( $CopyModsFile in $Configuration."CopyModsFile" ) {
            $CopyFile = $CopyModsFile.CopyFile;
            $CopyTo = $CopyModsFile.CopyTo;
        
            Copy-ModsFile $CopyFile $CopyFile;
        }
    }

    if ( $Configuration."EditModsFile" ) {
        ForEach ( $EditModsFile in $Configuration."EditModsFile" ) {
            $File = $EditModsFile.File;
            $FindText = $EditModsFile.FindText;
            $ReplaceText = $EditModsFile.ReplaceText;
        
            Edit-ModsFile $File $FindText $ReplaceText;
        }
    }

    if ( $Configuration."GrantModsPath" ) {
        $GrantPath = @();
        ForEach ( $GrantModsPathItem in $Configuration."GrantModsPath" ) {
            $grant = $GrantModsPathItem.File;
            $GrantPath += $grant;
        }
     
        Grant-ModsPath $GrantPath;  
    }
}
<# EXTRAS #>