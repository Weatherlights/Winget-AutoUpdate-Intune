$RegistryLocation = "HKLM:\SOFTWARE\Policies\weatherlights.com\Winget-AutoUpdate";
$ListLocation = $RegistryLocation + "\List"
$programdata = "$env:Programdata\Intune-WingetConfigurator";
$parsedListLocation = "$env:Programdata\Intune-WingetConfigurator\";


$InstallDir = "C:\Users\hauke\GitHub\Winget-AutoUpdate-Intune"


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

    Out-File -FilePath $parsedListLocation -InputObject $parsedList
}



function Get-CommandLine {
    param(
        $configuration
    )

    $commandLineArguments = "-silent -ListPath `"$parsedListLocation`""

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



if ( Test-Path -Path $RegistryLocation ) {
    $configuration = Get-ItemProperty -Path $RegistryLocation;

    
}

if ( Test-Path -Path $ListLocation ) {
    $list = Get-ItemProperty -Path $ListLocation

    $listFileName = "excluded_apps.txt"
    if ( $configuration.UseWhiteList ) {
        $listFileName = "included_apps.txt";
    }
    $ListLocation += $listFileName;

    Write-ListConfigToFile -FilePath $ListLocation -List $list;
}

# Generate filename for the include/exclude list.

$commandLineArguments = Get-CommandLine -configuration $configuration;

$command  = "& C:\Users\hauke\GitHub\Winget-AutoUpdate-Intune\Winget-AutoUpdate-Install.ps1 $commandLIneArguments"

iex $command;