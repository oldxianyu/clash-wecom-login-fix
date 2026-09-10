param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]] $InputPath,

    [int] $MaxDimension = 2560,

    [switch] $Quiet,

    [switch] $Json
)

$ErrorActionPreference = "Stop"
if ($MaxDimension -lt 1) { throw "MaxDimension 必须大于 0" }

try {
    Add-Type -AssemblyName System.Drawing
} catch {
    Add-Type -AssemblyName System.Drawing.Common
}
Add-Type -AssemblyName System.Windows.Forms

$SupportedExtensions = @(".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff", ".gif")
$JpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq "image/jpeg"

function Format-Bytes([long] $Bytes) {
    if ($Bytes -lt 1KB) { return "${Bytes} B" }
    if ($Bytes -lt 1MB) { return "$([math]::Round($Bytes / 1KB, 1)) KB" }
    return "$([math]::Round($Bytes / 1MB, 1)) MB"
}

function Get-ExifOrientation([System.Drawing.Image] $Image) {
    try {
        if ($Image.PropertyIdList -contains 274) {
            return [BitConverter]::ToUInt16($Image.GetPropertyItem(274).Value, 0)
        }
    } catch {
        # Some image formats do not expose readable EXIF metadata.
    }
    return 1
}

function Apply-ExifOrientation([System.Drawing.Image] $Image) {
    switch (Get-ExifOrientation $Image) {
        2 { $Image.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX) }
        3 { $Image.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
        4 { $Image.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipY) }
        5 { $Image.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipX) }
        6 { $Image.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
        7 { $Image.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipX) }
        8 { $Image.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
    }
}

function New-WorkingBitmap([System.Drawing.Image] $Image, [int] $Limit) {
    Apply-ExifOrientation $Image

    $scale = [math]::Min(1.0, [double] $Limit / [math]::Max($Image.Width, $Image.Height))
    $width = [math]::Max(1, [int] [math]::Round($Image.Width * $scale))
    $height = [math]::Max(1, [int] [math]::Round($Image.Height * $scale))
    $bitmap = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.DrawImage($Image, [System.Drawing.Rectangle]::new(0, 0, $width, $height))
    } finally {
        $graphics.Dispose()
    }
    return $bitmap
}

function Save-Jpeg([System.Drawing.Bitmap] $Bitmap, [string] $Path, [int] $Quality) {
    $canvas = [System.Drawing.Bitmap]::new($Bitmap.Width, $Bitmap.Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    $parameters = [System.Drawing.Imaging.EncoderParameters]::new(1)
    $parameter = [System.Drawing.Imaging.EncoderParameter]::new([System.Drawing.Imaging.Encoder]::Quality, [long] $Quality)
    try {
        $graphics.Clear([System.Drawing.Color]::White)
        $graphics.DrawImage($Bitmap, 0, 0, $Bitmap.Width, $Bitmap.Height)
        $parameters.Param[0] = $parameter
        $canvas.Save([string] $Path, [System.Drawing.Imaging.ImageCodecInfo] $JpegCodec, [System.Drawing.Imaging.EncoderParameters] $parameters)
    } finally {
        $parameter.Dispose()
        $parameters.Dispose()
        $graphics.Dispose()
        $canvas.Dispose()
    }
}

function Save-Png([System.Drawing.Bitmap] $Bitmap, [string] $Path) {
    $Bitmap.Save([string] $Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function New-OutputPath([string] $Directory, [string] $Stem, [string] $Extension) {
    $candidate = Join-Path $Directory "$Stem-压缩$Extension"
    $index = 2
    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path $Directory "$Stem-压缩 ($index)$Extension"
        $index++
    }
    return $candidate
}

function Remove-IfExists([string] $Path) {
    if ($Path -and (Test-Path -LiteralPath $Path)) {
        Remove-Item -LiteralPath $Path -Force
    }
}

function Try-Jpeg([System.Drawing.Bitmap] $Bitmap, [string] $Path, [long] $InputBytes) {
    foreach ($quality in @(82, 60, 40)) {
        Remove-IfExists $Path
        Save-Jpeg $Bitmap $Path $quality
        $outputBytes = (Get-Item -LiteralPath $Path).Length
        if ($outputBytes -lt $InputBytes) {
            return [pscustomobject]@{ Path = $Path; Bytes = $outputBytes; Quality = $quality }
        }
    }
    Remove-IfExists $Path
    return $null
}

function Compress-One([string] $Path) {
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $extension = [System.IO.Path]::GetExtension($resolved).ToLowerInvariant()
    if ($SupportedExtensions -notcontains $extension) {
        throw "不支持的图片格式：$extension"
    }

    $inputFile = Get-Item -LiteralPath $resolved
    $inputBytes = $inputFile.Length
    $directory = $inputFile.DirectoryName
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($resolved)
    $source = $null
    $bitmap = $null
    $outputPath = $null

    try {
        $source = [System.Drawing.Image]::FromFile($resolved)
        $bitmap = New-WorkingBitmap $source $MaxDimension

        if ($extension -eq ".png") {
            $outputPath = New-OutputPath $directory $stem ".png"
            Save-Png $bitmap $outputPath
            $outputBytes = (Get-Item -LiteralPath $outputPath).Length
            if ($outputBytes -ge $inputBytes) {
                Remove-IfExists $outputPath
                $outputPath = New-OutputPath $directory $stem ".jpg"
                $jpeg = Try-Jpeg $bitmap $outputPath $inputBytes
                if ($null -eq $jpeg) {
                    return [pscustomobject]@{ Ok = $false; Message = "$($inputFile.Name)：压缩后没有变小，未生成文件（原图已保留）" }
                }
                $outputBytes = $jpeg.Bytes
                $inputSize = Format-Bytes $inputBytes
                $outputSize = Format-Bytes $outputBytes
                return [pscustomobject]@{ Ok = $true; OutputPath = $jpeg.Path; Message = "$($inputFile.Name)：$inputSize → $outputSize，已生成 JPEG 副本" }
            }
            $inputSize = Format-Bytes $inputBytes
            $outputSize = Format-Bytes $outputBytes
            return [pscustomobject]@{ Ok = $true; OutputPath = $outputPath; Message = "$($inputFile.Name)：$inputSize → $outputSize" }
        }

        $outputPath = New-OutputPath $directory $stem ".jpg"
        $jpeg = Try-Jpeg $bitmap $outputPath $inputBytes
        if ($null -eq $jpeg) {
            return [pscustomobject]@{ Ok = $false; Message = "$($inputFile.Name)：压缩后没有变小，未生成文件（原图已保留）" }
        }
        $note = if ($extension -in @(".jpg", ".jpeg")) { "" } else { "，已转为 JPEG" }
        $inputSize = Format-Bytes $inputBytes
        $outputSize = Format-Bytes $jpeg.Bytes
        return [pscustomobject]@{ Ok = $true; OutputPath = $jpeg.Path; Message = "$($inputFile.Name)：$inputSize → $outputSize$note" }
    } finally {
        if ($bitmap) { $bitmap.Dispose() }
        if ($source) { $source.Dispose() }
        if ($outputPath -and (Test-Path -LiteralPath $outputPath)) {
            $outputBytes = (Get-Item -LiteralPath $outputPath).Length
            if ($outputBytes -ge $inputBytes) { Remove-IfExists $outputPath }
        }
    }
}

$results = foreach ($path in $InputPath) {
    try {
        Compress-One $path
    } catch {
        $name = if ($path) { [System.IO.Path]::GetFileName($path) } else { "图片" }
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
$title = if ($failed) { "图片压缩完成（有失败项）" } else { "图片压缩完成" }
$icon = if ($failed) { [System.Windows.Forms.MessageBoxIcon]::Warning } else { [System.Windows.Forms.MessageBoxIcon]::Information }
[void] [System.Windows.Forms.MessageBox]::Show(($results.Message -join [Environment]::NewLine), $title, [System.Windows.Forms.MessageBoxButtons]::OK, $icon)
