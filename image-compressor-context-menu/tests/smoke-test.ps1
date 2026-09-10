$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "..\compress-image.ps1"
$testRoot = Join-Path $env:TEMP ("image-compressor-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$inputPath = Join-Path $testRoot "sample.jpg"
$bitmap = $null
$graphics = $null
$parameters = $null
$parameter = $null

try {
    Add-Type -AssemblyName System.Drawing
    $bitmap = [System.Drawing.Bitmap]::new(1800, 1200)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $random = [System.Random]::new(42)
    $graphics.Clear([System.Drawing.Color]::White)
    for ($i = 0; $i -lt 2200; $i++) {
        $color = [System.Drawing.Color]::FromArgb($random.Next(256), $random.Next(256), $random.Next(256))
        $brush = [System.Drawing.SolidBrush]::new($color)
        try { $graphics.FillRectangle($brush, $random.Next(1800), $random.Next(1200), $random.Next(20, 240), $random.Next(20, 180)) } finally { $brush.Dispose() }
    }
    $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq "image/jpeg"
    $parameters = [System.Drawing.Imaging.EncoderParameters]::new(1)
    $parameter = [System.Drawing.Imaging.EncoderParameter]::new([System.Drawing.Imaging.Encoder]::Quality, [long] 100)
    $parameters.Param[0] = $parameter
    $bitmap.Save([string] $inputPath, [System.Drawing.Imaging.ImageCodecInfo] $codec, [System.Drawing.Imaging.EncoderParameters] $parameters)

    $inputBytes = (Get-Item -LiteralPath $inputPath).Length
    $result = (& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $scriptPath -InputPath $inputPath -Json | Out-String | ConvertFrom-Json)
    if (-not $result.Ok) { throw (($result | Format-List * | Out-String).Trim()) }
    if (-not (Test-Path -LiteralPath $result.OutputPath)) { throw "压缩文件不存在：$($result.OutputPath)" }
    $outputBytes = (Get-Item -LiteralPath $result.OutputPath).Length
    if ($outputBytes -ge $inputBytes) { throw "压缩文件没有变小：$inputBytes -> $outputBytes" }
    Write-Host "PASS: $inputBytes -> $outputBytes"
} finally {
    if ($parameter) { $parameter.Dispose() }
    if ($parameters) { $parameters.Dispose() }
    if ($graphics) { $graphics.Dispose() }
    if ($bitmap) { $bitmap.Dispose() }
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
