$ErrorActionPreference = "Stop"

$extensions = @(".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff", ".gif")
$scriptPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "compress-image.ps1"))
$command = "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -InputPath `"%1`""

foreach ($extension in $extensions) {
    $verbPath = "HKCU:\Software\Classes\SystemFileAssociations\$extension\shell\ImageCompressor"
    $commandPath = Join-Path $verbPath "command"
    New-Item -Path $verbPath -Force | Out-Null
    New-Item -Path $commandPath -Force | Out-Null
    New-ItemProperty -Path $verbPath -Name "MUIVerb" -PropertyType String -Value "压缩图片" -Force | Out-Null
    New-ItemProperty -Path $verbPath -Name "Icon" -PropertyType String -Value "$env:WINDIR\System32\imageres.dll,-113" -Force | Out-Null
    Set-Item -LiteralPath $commandPath -Value $command
}

Write-Host "已安装到当前 Windows 用户。右键 JPG/PNG 等图片，必要时先点“显示更多选项”，即可看到“压缩图片”。"
