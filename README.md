# Winget-AutoUpdate-aaS
WinGet-AutoUpdate-aaS is based on WinGet-AutoUpdate (WAU) and is dedicated to the approach to bring you WAU in the form of a service (aaS). So this means:
* No packaging and automatic servicing through the Microsoft Store
* Configurable and ready to use modifications that do not require scripting
* No infrastructure deployment: Everything can be reached right out of Intune

WinGet-AutoUpdate-aaS takes the configuration from Microsoft Intune and applies it to WinGet-AutoUpdate so your users stay up-to-date with their software.

![image](https://user-images.githubusercontent.com/96626929/150645599-9460def4-0818-4fe9-819c-dd7081ff8447.png)

## Intune integration using ADMX backed profiles
Winget-AutoUpdate-Configurator integrates well into Microsoft Intune by using ADMX backed policies. You can configure nearly all aspects of Winget-AutoUpdate from your Microsoft Intune console and change settings when you need without redeploying Winget-AutoUpdate.

You can also configure your white- and blacklist from within the Microsoft Intune console and do not need to host them on an external data source.

![image](https://github.com/Weatherlights/Winget-AutoUpdate-Intune/blob/b4e70d7e476eef0e99c841bb807c0604ba2d7676/docs/img/teaser1.png)

## Features
* Updates (nearly) every 3rd Party App that using WinGet
* Fully ADMX backed configuration using Microsoft Intune
* White- or Blacklist apps you want to update
* Easy deployment using a single MSI file
* Available as Microsoft Store App (new)

## Where to start from here
Take a look into the [Wiki](https://github.com/Weatherlights/Winget-AutoUpdate-Intune/wiki)... I just wrote some stuff together that helps you getting started.

WinGet-Autoupdate-aaS is also available from the Microsoft Store and can be deployed using the Microsoft Store App (new) mechanism:

<a href="https://apps.microsoft.com/store/detail/wingetautoupdateconfigurator/XP89BSK82W9J28"><img src="https://developer.microsoft.com/store/badges/images/English_get-it-from-MS.png" alt="Get it from Microsoft" width="280"/></a>
