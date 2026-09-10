$ErrorActionPreference = "Stop"

foreach ($extension in @(".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff", ".gif")) {
    $verbPath = "HKCU:\Software\Classes\SystemFileAssociations\$extension\shell\ImageCompressor"
    if (Test-Path -LiteralPath $verbPath) {
        Remove-Item -LiteralPath $verbPath -Recurse -Force
    }
}

Write-Host "已移除图片右键“压缩图片”菜单。原图和已生成的压缩文件不会被删除。"
