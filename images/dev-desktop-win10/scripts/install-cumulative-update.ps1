# Installs the pinned Windows 10 cumulative update (variable cumulative_update). Windows Update offers no ESU
# cumulative update to this VM, so the update comes from the Microsoft Update Catalog. wusa exit 3010 means installed,
# reboot required; the next provisioner restarts the VM.
$ErrorActionPreference = 'Stop'

$update = Get-Content -Path 'C:\Windows\Temp\cumulative-update.json' -Raw | ConvertFrom-Json
$file = "C:\Windows\Temp\$($update.kb).msu"
(New-Object Net.WebClient).DownloadFile($update.url, $file)
$sha1 = (Get-FileHash -Path $file -Algorithm SHA1).Hash.ToLowerInvariant()
if ($sha1 -ne $update.sha1) { throw "$($update.kb) SHA-1 is $sha1, expected $($update.sha1)" }

$process = Start-Process -FilePath wusa.exe -ArgumentList "`"$file`" /quiet /norestart" -Wait -PassThru
Remove-Item -Path $file -Force
if ($process.ExitCode -notin 0, 3010) { throw "wusa $($update.kb) exited $($process.ExitCode)" }
Write-Output "$($update.kb) installed (wusa exit $($process.ExitCode))"
