param(
    [string]$AdbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    [string]$DeviceId = "",
    [string]$PackageName = "com.example.set_level",
    [string]$RemotePath,
    [string]$OutputPath = "C:\dev\jpworddb\data\jpword.db",
    [int]$IntervalSeconds = 5,
    [switch]$Once
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RemotePath)) {
    $RemotePath = "/storage/emulated/0/Android/data/$PackageName/files/exports/jpword_export.db"
}

$InternalDbPath = "/data/user/0/$PackageName/databases/set_level_jpword.db"

function Get-FileHashOrNull {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    }
    return $null
}

function Invoke-PullOnce {
    param(
        [string]$Adb,
        [string]$Serial,
        [string]$From,
        [string]$To
    )

    if (!(Test-Path -LiteralPath $Adb)) {
        throw "adb が見つかりません: $Adb"
    }

    $toDir = Split-Path -Parent $To
    if (!(Test-Path -LiteralPath $toDir)) {
        New-Item -ItemType Directory -Path $toDir | Out-Null
    }

    $tmp = "$To.tmp"
    if (Test-Path -LiteralPath $tmp) {
        Remove-Item -LiteralPath $tmp -Force
    }

    $args = @()
    if (-not [string]::IsNullOrWhiteSpace($Serial)) {
        $args += @("-s", $Serial)
    }

    # 1) First try normal adb pull from exported external path.
    $pullArgs = $args + @("pull", $From, $tmp)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & $Adb @pullArgs 2>&1
        $exit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldPreference
    }

    if ($exit -ne 0 -or !(Test-Path -LiteralPath $tmp)) {
        if (Test-Path -LiteralPath $tmp) {
            Remove-Item -LiteralPath $tmp -Force
        }

        # 2) Fallback: pull app internal DB via run-as (works when Android/data is blocked).
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $proc.StartInfo.FileName = $Adb
        $runAsArgs = @()
        if (-not [string]::IsNullOrWhiteSpace($Serial)) {
            $runAsArgs += @("-s", $Serial)
        }
        $runAsArgs += @("exec-out", "run-as", $PackageName, "cat", $InternalDbPath)
        $proc.StartInfo.Arguments = ($runAsArgs -join ' ')
        $proc.StartInfo.UseShellExecute = $false
        $proc.StartInfo.RedirectStandardOutput = $true
        $proc.StartInfo.RedirectStandardError = $true

        $null = $proc.Start()
        $fs = [System.IO.File]::Open($tmp, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
        $proc.StandardOutput.BaseStream.CopyTo($fs)
        $fs.Close()
        $proc.WaitForExit()
        $stderr = $proc.StandardError.ReadToEnd()

        if ($proc.ExitCode -ne 0 -or $stderr) {
            if (Test-Path -LiteralPath $tmp) {
                Remove-Item -LiteralPath $tmp -Force
            }
            return [pscustomobject]@{
                Success = $false
                Changed = $false
                Message = ((($output | Out-String).Trim()) + " | fallback: " + $stderr).Trim()
            }
        }

        # If fallback wrote plain-text error text, treat as failure.
        if ((Get-Item -LiteralPath $tmp).Length -lt 16) {
            Remove-Item -LiteralPath $tmp -Force
            return [pscustomobject]@{
                Success = $false
                Changed = $false
                Message = "fallback output is too small"
            }
        }
    }

    $oldHash = Get-FileHashOrNull -Path $To
    $newHash = Get-FileHashOrNull -Path $tmp

    if ($oldHash -eq $newHash) {
        Remove-Item -LiteralPath $tmp -Force
        return [pscustomobject]@{
            Success = $true
            Changed = $false
            Message = "No change"
        }
    }

    Move-Item -LiteralPath $tmp -Destination $To -Force
    return [pscustomobject]@{
        Success = $true
        Changed = $true
        Message = "Updated: $To"
    }
}

Write-Host "Watch start"
if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    Write-Host "  device : auto"
} else {
    Write-Host "  device : $DeviceId"
}
Write-Host "  remote : $RemotePath"
Write-Host "  internal: $InternalDbPath"
Write-Host "  output : $OutputPath"
Write-Host "  interval: ${IntervalSeconds}s"

while ($true) {
    try {
        $result = Invoke-PullOnce -Adb $AdbPath -Serial $DeviceId -From $RemotePath -To $OutputPath
        $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        if ($result.Success) {
            if ($result.Changed) {
                Write-Host "[$now] DB pulled: $($result.Message)"
            } else {
                Write-Host "[$now] $($result.Message)"
            }
        } else {
            Write-Host "[$now] Pull failed: $($result.Message)"
        }
    } catch {
        $now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$now] Error: $($_.Exception.Message)"
    }

    if ($Once) {
        break
    }

    Start-Sleep -Seconds $IntervalSeconds
}
