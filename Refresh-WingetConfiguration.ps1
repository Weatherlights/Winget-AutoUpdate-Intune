$RegistryLocation = "HKLM:\SOFTWARE\Policies\weatherlights.com\Winget-AutoUpdate";
$ListLocation = $RegistryLocation + "\List"
$programdata = "$env:Programdata\Intune-WingetConfigurator";
$parsedListLocation = "$env:Programdata\Intune-WingetConfigurator\List.txt";

if ( Test-Path -Path $RegistryLocation ) {
    $configuration = Get-ItemProperty -Path $RegistryLocation;
}

if ( Test-Path -Path $ListLocation ) {
    $list = Get-ItemProperty -Path $ListLocation -
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

    Out-File -FilePath $parsedListLocation -InputObject $parsedList
}

Write-ListConfigToFile -FilePath $ListLocation -List $list;

function Get-CommandLine {
    param(
        $configuration
    )

    $commandLineArgument = "-ListPath $parsedListLocation"

    if ( $configuration.NotificationLevel ) {
        $commandLineArgument += "-NotificationLevel " + $configuration.NotificationLevel;
    }

    if ( $configuration.RunOnMetered ) {
        $commandLineArgument += "-RunOnMetered";
    }

    if ( $configuration.UseWhiteList ) {
        $commandLineArgument += "-UseWhiteList";
    }
}
