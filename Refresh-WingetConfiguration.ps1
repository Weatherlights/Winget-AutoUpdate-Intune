$PolicyRegistryLocation = "HKLM:\SOFTWARE\Policies\weatherlights.com\Winget-AutoUpdate";
$PolicyListLocation = $PolicyRegistryLocation + "\List"

$DataDir = "$env:Programdata\Winget-AutoUpdate-Configurator\";

$scriptlocation = $MyInvocation.MyCommand.Path + "\.."

Import-Module "$scriptLocation\WinGet-AutoUpdate-Configurator\Generic.psm1"

$InstallDir = "C:\Users\hauke\GitHub\Winget-AutoUpdate-Intune"


if ( !(Test-Path -Path $DataDir) ) {
    md $DataDir -Force
    Write-LogFile -InputObject "Created non existing directory $DataDir."
}


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



function Get-CommandLine {
    param(
        $configuration
    )

    $commandLineArguments = "-silent -NoClean -ListPath `"$DataDir`""

    if ( $configuration.NotificationLevel ) {
        $commandLineArguments += " -NotificationLevel " + $configuration.NotificationLevel;
    }

    if ( $configuration.RunOnMetered ) {
        $commandLineArguments += " -RunOnMetered";
    }

    if ( $configuration.UseWhiteList ) {
        $commandLineArguments += " -UseWhiteList";
    }

    if ( $configuration.UpdatesInterval ) {
        $commandLineArguments += " -UpdatesInterval " + $configuration.UpdatesInterval;
    }

    if ( $configuration.UpdatesAtTime ) {
        $commandLineArguments += " -UpdatesAtTime " + $configuration.UpdatesAtTime;
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

    if ( $configuration.DoNotUpdate ) {
        $commandLineArguments += " -DoNotUpdate";
    }

    if ( $configuration.DisableWAUAutoUpdate ) {
        $commandLineArguments += " -DisableWAUAutoUpdate";
    }

    if ( $configuration.InstallUserContext ) {
        $commandLineArguments += " -InstallUserContext";
    }

    return $commandLineArguments
}



if ( Test-Path -Path $PolicyRegistryLocation ) {
    $configuration = Get-ItemProperty -Path $PolicyRegistryLocation;   
    Write-LogFile -InputObject "Configuration received from $PolicyRegistryLocation"; 
} else {
     Write-LogFile -InputObject "Warning: $PolicyRegistryLocation does not exist yet."
}

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

# Generate filename for the include/exclude list.
$commandLineArguments = Get-CommandLine -configuration $configuration;
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
        Write-LogFile "Removed WUA for Reinstall."
    }
    iex $installCommand;
    Write-LogFile "Updated WUA."
} else {
    Write-LogFile "Skipped updating WUA."
}

Out-File -FilePath "$DataDir\LastCommand.txt" -Force -InputObject $commandLineArguments;
Write-LogFile -InputObject "Stored commandline arguments."