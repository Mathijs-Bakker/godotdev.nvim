param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$File,
  [Parameter(Position = 1)]
  [int]$Line = 1,
  [Parameter(Position = 2)]
  [int]$Column = 1
)

$ErrorActionPreference = "Stop"

$Socket = if ($env:GODOT_NVIM_SOCKET) { $env:GODOT_NVIM_SOCKET } else { "/tmp/godot.nvim" }
$Distro = $env:GODOT_WSL_DISTRO
$DistroArgs = @()

if ($Distro) {
  $DistroArgs = @("-d", $Distro)
}

$WslFile = & wsl.exe @DistroArgs wslpath -a $File
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

$WslFile = ($WslFile | Select-Object -First 1).Trim()
if (-not $WslFile) {
  throw "Failed to convert Windows path to WSL path: $File"
}

# Godot passes the column as well, but nvr opens by line for this bridge.
& wsl.exe @DistroArgs nvr --servername $Socket --remote "+$Line" $WslFile
exit $LASTEXITCODE
