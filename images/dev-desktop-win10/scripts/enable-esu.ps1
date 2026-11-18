# Windows 10 Extended Security Updates. Azure Virtual Desktop session hosts are entitled at no cost, and Microsoft
# Learn asks for explicit ESU policy enablement on them ("Understanding Extended Security Updates (ESU) for Windows 10:
# Azure Virtual Desktop", section 3), pointing to "Enable Windows 10 Extended Security Updates (ESU) for clients
# accessing cloud and virtual machines". That page's policy is the Licensing CSP setting EnableESUSubscriptionCheck
# (./Device/Vendor/MSFT/Policy/Config/Licensing/EnableESUSubscriptionCheck = 1), stored in the registry value below.
# The same page requires KB5066791 or later and the ESU Licensing Preparation Package KB5072653; the pinned cumulative
# update (install-cumulative-update.ps1) and Windows Update install them in the next build steps.
$ErrorActionPreference = 'Stop'

$esu = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform\ESU'
New-Item -Path $esu -Force | Out-Null
New-ItemProperty -Path $esu -Name EnableESUSubscriptionCheck -Value 1 -PropertyType DWord -Force | Out-Null
Write-Output "EnableESUSubscriptionCheck = $((Get-ItemProperty -Path $esu).EnableESUSubscriptionCheck)"
