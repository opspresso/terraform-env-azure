# Installs the developer tools machine-wide, for every user, from installers checked against their pinned SHA-256.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$tools = Get-Content -Path 'C:\Windows\Temp\tools.json' -Raw | ConvertFrom-Json
$work = 'C:\Windows\Temp\tools'
New-Item -ItemType Directory -Path $work -Force | Out-Null

function Get-Installer([string] $Name, $Tool) {
  $path = Join-Path $work $Name
  Invoke-WebRequest -Uri $Tool.url -OutFile $path -UseBasicParsing
  $hash = (Get-FileHash -Path $path -Algorithm SHA256).Hash
  if ($hash -ne $Tool.sha256) { throw "${Name}: SHA-256 $hash does not match the pinned $($Tool.sha256)" }
  return $path
}

# Windows PowerShell turns a native command's stderr (npm warnings) into errors under $ErrorActionPreference Stop, so
# native commands run with Continue and fail on their exit code instead.
function Invoke-Native([scriptblock] $Command) {
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try { & $Command 2>&1 | ForEach-Object { "$_" } } finally { $ErrorActionPreference = $previous }
  if ($LASTEXITCODE -ne 0) { throw "$Command exited with $LASTEXITCODE" }
}

function Invoke-Installer([string] $File, [string] $Arguments) {
  $process = Start-Process -FilePath $File -ArgumentList $Arguments -Wait -PassThru
  if ($process.ExitCode -notin 0, 3010) { throw "$File exited with $($process.ExitCode)" }
}

Write-Output "Git for Windows $($tools.git.version)"
$git = Get-Installer 'git.exe' $tools.git
Invoke-Installer $git '/VERYSILENT /NORESTART /NOCANCEL /SP- /SUPPRESSMSGBOXES /ALLUSERS /o:PathOption=Cmd'

Write-Output "VS Code $($tools.vscode.version) (system installer)"
$vscode = Get-Installer 'vscode.exe' $tools.vscode
Invoke-Installer $vscode '/VERYSILENT /NORESTART /SUPPRESSMSGBOXES /MERGETASKS=!runcode,addtopath'

Write-Output "Node.js $($tools.node.version)"
$node = Get-Installer 'node.msi' $tools.node
Invoke-Installer 'msiexec.exe' "/i `"$node`" /qn /norestart ALLUSERS=1 /l*v `"$work\node.log`""

Write-Output "Python $($tools.python.version) (all users)"
$python = Get-Installer 'python.exe' $tools.python
Invoke-Installer $python '/quiet InstallAllUsers=1 PrependPath=1 Include_test=0 Include_launcher=1 InstallLauncherAllUsers=1'

# The coding CLIs go into a prefix under Program Files: every user runs them, only administrators can change them.
# A user's own `npm install -g` still goes to %APPDATA%\npm.
$prefix = 'C:\Program Files\npm-global'
New-Item -ItemType Directory -Path $prefix -Force | Out-Null
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$packages = $tools.npm.PSObject.Properties | ForEach-Object { "$($_.Name)@$($_.Value)" }
Write-Output "npm: $($packages -join ' ')"
# npm 11.20 skips install scripts that no allowScripts policy covers. Claude Code and opencode need theirs (they place
# the native binary), so the pinned packages may run scripts and any other package's script fails the install.
$allowScripts = ($tools.npm.PSObject.Properties | ForEach-Object { $_.Name }) -join ','
# node runs npm directly: npm.cmd would pass the arguments through cmd.exe, which splits them at commas.
$nodeExe = "$env:ProgramFiles\nodejs\node.exe"
$npm = "$env:ProgramFiles\nodejs\node_modules\npm\bin\npm-cli.js"
Invoke-Native { & $nodeExe $npm install --global --prefix $prefix --no-fund --no-audit "--allow-scripts=$allowScripts" --strict-allow-scripts @packages }
Invoke-Native { & $nodeExe $npm cache clean --force }

$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
if (($machinePath -split ';') -notcontains $prefix) {
  [Environment]::SetEnvironmentVariable('Path', "$machinePath;$prefix", 'Machine')
}

# Fail before the long Windows Update step if a CLI does not start (verify.ps1 checks every tool at the end).
foreach ($cli in 'claude', 'codex', 'opencode') {
  Invoke-Native { & "$prefix\$cli.cmd" --version }
}

Remove-Item -Path $work -Recurse -Force
