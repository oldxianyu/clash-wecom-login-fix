$ErrorActionPreference = "Stop"

function Register-ContextVerb([string] $Extension, [string] $VerbId, [string] $Label, [string] $ScriptName) {
    $scriptPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $ScriptName))
    $command = "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -InputPath `"%1`""
    $verbPath = "HKCU:\Software\Classes\SystemFileAssociations\$Extension\shell\$VerbId"
    $commandPath = Join-Path $verbPath "command"
    New-Item -Path $verbPath -Force | Out-Null
    New-Item -Path $commandPath -Force | Out-Null
    New-ItemProperty -Path $verbPath -Name "MUIVerb" -PropertyType String -Value $Label -Force | Out-Null
    New-ItemProperty -Path $verbPath -Name "Icon" -PropertyType String -Value "$env:WINDIR\System32\imageres.dll,-113" -Force | Out-Null
    Set-Item -LiteralPath $commandPath -Value $command
}

foreach ($extension in @(".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff", ".gif")) {
    Register-ContextVerb $extension "ImageCompressor" "压缩图片" "compress-image.ps1"
}
Register-ContextVerb ".pdf" "PdfCompressor" "压缩 PDF" "compress-pdf.ps1"

$python = Get-Command python.exe -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py.exe -ErrorAction SilentlyContinue }
if (-not $python) {
    Write-Warning "PDF 右键菜单已注册，但未找到 Python 3；安装 Python 3 后即可使用。"
} else {
    $probe = if ($python.Name -eq "py.exe") { @("-3", "-c", "import pymupdf") } else { @("-c", "import pymupdf") }
    & $python.Source @probe 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Warning "未找到 PyMuPDF；请执行 python -m pip install PyMuPDF 后再压缩 PDF。" }
}
Write-Host "已安装到当前 Windows 用户。图片右键显示“压缩图片”，PDF 右键显示“压缩 PDF”。"
