$ErrorActionPreference = "Stop"

foreach ($extension in @(".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff", ".gif")) {
    $verbPath = "HKCU:\Software\Classes\SystemFileAssociations\$extension\shell\ImageCompressor"
    if (Test-Path -LiteralPath $verbPath) {
        Remove-Item -LiteralPath $verbPath -Recurse -Force
    }
}

$pdfVerbPath = "HKCU:\Software\Classes\SystemFileAssociations\.pdf\shell\PdfCompressor"
if (Test-Path -LiteralPath $pdfVerbPath) {
    Remove-Item -LiteralPath $pdfVerbPath -Recurse -Force
}

Write-Host "已移除图片和 PDF 右键压缩菜单。原图和已生成的压缩文件不会被删除。"
