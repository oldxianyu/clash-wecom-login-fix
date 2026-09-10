# 图片右键压缩

Windows 当前用户右键图片即可压缩，原图不会被覆盖。

## 安装

在此目录打开 PowerShell，执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-context-menu.ps1
```

支持：`.jpg`、`.jpeg`、`.png`、`.bmp`、`.tif`、`.tiff`、`.gif`。Windows 11 如果菜单没有直接显示，请先点“显示更多选项”。

## 使用结果

- JPG/JPEG：生成同目录的 `原文件名-压缩.jpg`。
- PNG：先尝试保留透明度的 PNG；如果没有变小，再生成白底 JPEG 副本。
- BMP/TIFF/GIF：生成 JPEG 副本；GIF 只处理当前首帧。
- 如果压缩后没有更小，不生成文件，并提示“原图已保留”。
- 同名文件不会覆盖，会自动使用 `(2)`、`(3)` 等后缀。

## 卸载

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\uninstall-context-menu.ps1
```

卸载只移除当前工具创建的右键菜单，不删除图片。

## 本机自检

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\smoke-test.ps1
```
