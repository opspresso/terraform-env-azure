# Generalizes the VM for the gallery. The build user pkrbuild survives sysprep, so the first boot of every desktop
# deletes it and its profile (SetupComplete.cmd runs as SYSTEM after setup). Do not use pkrbuild as a desktop's
# admin user name.
$ErrorActionPreference = 'Stop'

Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' -Name AutoDownload -ErrorAction SilentlyContinue

$scripts = "$env:SystemRoot\Setup\Scripts"
New-Item -ItemType Directory -Path $scripts -Force | Out-Null
Set-Content -Path "$scripts\remove-build-user.ps1" -Encoding ASCII -Value @'
Get-LocalUser -Name pkrbuild -ErrorAction SilentlyContinue | Remove-LocalUser
Get-CimInstance Win32_UserProfile | Where-Object { $_.LocalPath -like '*\pkrbuild' } | Remove-CimInstance
'@
Add-Content -Path "$scripts\SetupComplete.cmd" -Encoding ASCII -Value `
  'powershell.exe -NoProfile -ExecutionPolicy Bypass -File %WINDIR%\Setup\Scripts\remove-build-user.ps1'

# The Azure agents must be running before sysprep, or the generalized image does not provision.
while ((Get-Service RdAgent).Status -ne 'Running') { Start-Sleep -Seconds 5 }
while ((Get-Service WindowsAzureGuestAgent).Status -ne 'Running') { Start-Sleep -Seconds 5 }

& "$env:SystemRoot\System32\Sysprep\Sysprep.exe" /oobe /generalize /quiet /quit /mode:vm
while ($true) {
  $state = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State').ImageState
  if ($state -eq 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { break }
  Write-Output $state
  Start-Sleep -Seconds 10
}
