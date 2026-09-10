param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]] $InputPath,

    [switch] $Quiet,

    [switch] $Json
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms

function Format-Bytes([long] $Bytes) {
    if ($Bytes -lt 1KB) { return "${Bytes} B" }
    if ($Bytes -lt 1MB) { return "$([math]::Round($Bytes / 1KB, 1)) KB" }
    return "$([math]::Round($Bytes / 1MB, 1)) MB"
}

$pythonInfo = Get-Command python.exe -ErrorAction SilentlyContinue
$pythonExecutable = $null
$pythonPrefixArgs = @()
if ($pythonInfo) {
    $pythonExecutable = $pythonInfo.Source
} else {
    $launcherInfo = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($launcherInfo) {
        $pythonExecutable = $launcherInfo.Source
        $pythonPrefixArgs = @("-3")
    }
}

$pythonScript = Join-Path $PSScriptRoot "compress-pdf.py"
$results = foreach ($path in $InputPath) {
    try {
        if (-not $pythonExecutable) {
            throw "未找到 Python 3。请安装 Python 3 后重试。"
        }

        $arguments = @($pythonPrefixArgs + @($pythonScript, "--input", $path, "--json"))
        $raw = (& $pythonExecutable @arguments 2>&1 | Out-String).Trim()
        $item = $raw | ConvertFrom-Json
        $name = [System.IO.Path]::GetFileName($path)
        if ($item.ok) {
            $inputSize = Format-Bytes ([long] $item.input_bytes)
            $outputSize = Format-Bytes ([long] $item.output_bytes)
            [pscustomobject]@{
                Ok = $true
                OutputPath = [string] $item.output
                Message = "$name：$inputSize → $outputSize（$($item.pages) 页）"
            }
        } elseif ($item.error -eq "not_smaller") {
            [pscustomobject]@{ Ok = $false; Message = "$name：压缩后没有变小，未生成文件（原 PDF 已保留）" }
        } else {
            [pscustomobject]@{ Ok = $false; Message = "$name：$($item.error)" }
        }
    } catch {
        $name = if ($path) { [System.IO.Path]::GetFileName($path) } else { "PDF" }
        [pscustomobject]@{ Ok = $false; Message = "$name：$($_.Exception.Message)" }
    }
}

if ($Json) {
    $results | ConvertTo-Json -Compress
    exit 0
}

if ($Quiet) {
    $results
    exit 0
}

$failed = @($results | Where-Object { -not $_.Ok }).Count -gt 0
$title = if ($failed) { "PDF 压缩完成（有失败项）" } else { "PDF 压缩完成" }
$icon = if ($failed) { [System.Windows.Forms.MessageBoxIcon]::Warning } else { [System.Windows.Forms.MessageBoxIcon]::Information }
[void] [System.Windows.Forms.MessageBox]::Show(($results.Message -join [Environment]::NewLine), $title, [System.Windows.Forms.MessageBoxButtons]::OK, $icon)
