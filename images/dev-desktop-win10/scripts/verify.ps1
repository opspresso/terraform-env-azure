# Fails the build unless every tool runs from the machine PATH alone, as a new user's session would see it.
$ErrorActionPreference = 'Stop'

$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$failed = @()
foreach ($command in 'git --version', 'code --version', 'node --version', 'npm --version', 'python --version',
  'claude --version', 'codex --version', 'opencode --version') {
  $output = & cmd.exe /d /c "$command 2>&1"
  if ($LASTEXITCODE -ne 0) { $failed += $command }
  Write-Output "$command -> $(($output | Select-Object -First 1)) (exit $LASTEXITCODE)"
}

$os = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
Write-Output "OS build $($os.CurrentBuild).$($os.UBR)"
$update = Get-Content -Path 'C:\Windows\Temp\cumulative-update.json' -Raw | ConvertFrom-Json
if ([version]"10.0.$($os.CurrentBuild).$($os.UBR)" -lt [version]"10.0.$($update.build)") { $failed += "OS build below $($update.build) ($($update.kb))" }
$esu = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform\ESU'
Write-Output "EnableESUSubscriptionCheck = $($esu.EnableESUSubscriptionCheck)"
Get-HotFix | Sort-Object InstalledOn | Select-Object -Last 5 | ForEach-Object { Write-Output "Hotfix $($_.HotFixID) $($_.InstalledOn)" }

if ($failed) { throw "Failed: $($failed -join ', ')" }
