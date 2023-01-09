$RegistryLocation = "HKLM:\SOFTWARE\Policies\weatherlights.com\Winget-AutoUpdate";
$ListLocation = $RegistryLocation + "\List"

if ( Test-Path -Path $RegistryLocation ) {
    $configuration = Get-ItemProperty -Path $RegistryLocation;
}

if ( Test-Path -Path $ListLocation ) {
    $list = Get-ItemProperty -Path $ListLocation;
}