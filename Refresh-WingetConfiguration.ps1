$PolicyRegistryLocation = "HKLM:\SOFTWARE\Policies\weatherlights.com\Winget-AutoUpdate";
$PolicyListLocation = $PolicyRegistryLocation + "\List"
$programdata = "$env:Programdata\Intune-WingetConfigurator";
$DataDir = "$env:Programdata\Intune-WingetConfigurator\";

$scriptlocation = $MyInvocation.MyCommand.Path + "\.."
$InstallDir = "C:\Users\hauke\GitHub\Winget-AutoUpdate-Intune"

if ( !(Test-Path -Path $DataDir) ) {
    md $DataDir -Force
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

    $commandLineArguments = "-silent -NoClean -DoNotUpdate -ListPath `"$DataDir`""

    if ( $configuration.NotificationLevel ) {
        $commandLineArguments += " -NotificationLevel " + $configuration.NotificationLevel;
    }

    if ( $configuration.RunOnMetered ) {
        $commandLineArguments += " -RunOnMetered";
    }

    if ( $configuration.UseWhiteList ) {
        $commandLineArguments += " -UseWhiteList";
    }

    return $commandLineArguments
}



if ( Test-Path -Path $PolicyRegistryLocation ) {
    $configuration = Get-ItemProperty -Path $PolicyRegistryLocation;

    
}

if ( Test-Path -Path $PolicyListLocation ) {
    $list = Get-ItemProperty -Path $PolicyListLocation

    $listFileName = "excluded_apps.txt"
    if ( $configuration.UseWhiteList ) {
        $listFileName = "included_apps.txt";
    }
    $ListLocation = "$DataDir\$listFileName";

    Write-ListConfigToFile -FilePath $ListLocation -List $list;
}

# Generate filename for the include/exclude list.

$commandLineArguments = Get-CommandLine -configuration $configuration;
if ( Test-Path "$DataDir\LastCommand.txt" -PathType Leaf ) {
    $previousCommandLine = Get-Content -Path "$DataDir\LastCommand.txt"
} else {
    $previousCommandLine = "";
}

$command  = "& $scriptlocation\Winget-AutoUpdate-Install.ps1 $commandLIneArguments"

if ( $commandLineArguments -ne $previousCommandLine ) {
    iex $command;
}

Out-File -FilePath "$DataDir\LastCommand.txt" -Force -InputObject $commandLineArguments;