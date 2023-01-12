function Write-LogFile {
<#
.SYNOPSIS
    Writes an entry to the log file.
.DESCRIPTION
    Writes an entry to the WinGet-AutoUpdate-Configurato Log file in the temporary folder.
.INPUTS
    string
.PARAMETER InputObject
    The message that should be written to the log file.
.OUTPUTS
    bool
.NOTES
    Created by Hauke Goetze
.LINK
    https://github.com/Weatherlights/Winget-AutoUpdate-Intune
#>
    param(
        [Parameter(Mandatory=$True)][string]$InputObject,
        [String]$Component = "WinGet-AutoUpdate-Configurator"
    );

    $LogDir = "$env:temp\$env:COMPUTERNAME-WinGet-AutoUpdate-Configurator.log"
    $time = Get-Date -Format "HH:mm:ss";
    $date = Get-Date -Format "MM-dd-yyyy";
    $logmessage = "<![LOG[$InputObject]LOG]!><time=`"$time.0000000`" date=`"$date`" component=`"$Component`" context=`"`" type=`"`" thread=`"`" file=`"`">";
    Out-File -FilePath $LogDir -Append -InputObject $logmessage -Encoding UTF8;
    $size=(Get-Item $LogDir).length

    if ( $size -gt 5120000 ) {
        Move-Item -Path $LogDir -Destination "$LogDir.bak"
    }
    
}

# from https://gist.github.com/zommarin/1480974
function Get-FileEncoding($Path) {
<#
.SYNOPSIS
    Gets the file encoding of a file.
.DESCRIPTION
    Gets the file encoding of a file.
.OUTPUTS
    string
.PARAMETER Path
    Path to the file from that you want to get the encoding.
.LINK
    https://gist.github.com/zommarin/1480974
#>
    $bytes = [byte[]](Get-Content $Path -Encoding byte -ReadCount 4 -TotalCount 4)

    if(!$bytes) { return 'utf8' }

    switch -regex ('{0:x2}{1:x2}{2:x2}{3:x2}' -f $bytes[0],$bytes[1],$bytes[2],$bytes[3]) {
        '^efbbbf'   { return 'utf8' }
        '^2b2f76'   { return 'utf7' }
        '^fffe'     { return 'unicode' }
        '^feff'     { return 'bigendianunicode' }
        '^0000feff' { return 'utf32' }
        default     { return 'ascii' }
    }
}
