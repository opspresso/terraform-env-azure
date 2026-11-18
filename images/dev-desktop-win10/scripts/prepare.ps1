# Keeps the Microsoft Store from updating apps for the build user during the build. Such per-user app updates make
# sysprep /generalize fail. generalize.ps1 removes the policy again.
$ErrorActionPreference = 'Stop'

$store = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'
New-Item -Path $store -Force | Out-Null
New-ItemProperty -Path $store -Name AutoDownload -Value 2 -PropertyType DWord -Force | Out-Null

$os = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
Write-Output "Source image: $($os.ProductName) $($os.DisplayVersion) build $($os.CurrentBuild).$($os.UBR)"
