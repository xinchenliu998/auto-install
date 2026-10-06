# Sublime Text

## 基本信息

| 项 | 内容 |
| --- | --- |
| 软件名称 | Sublime Text |
| 版本 | Build 4215（x64） |
| 安装包 | `packages/Sublime Text/sublime_text_build_4215_x64_setup.exe` |
| 安装脚本 | [`Include/Install/sublime-text.au3`](../../Include/Install/sublime-text.au3) |
| 安装类型 | 静默安装（Inno Setup） |
| 用途 | 文本 / 代码编辑器 |

## 安装说明

- **安装方式**：运行官方安装包，带静默参数（Inno Setup 安装包）。
- **静默参数**：`/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-`
  - 指定安装目录：追加 `/DIR="C:\Program Files\Sublime Text"`
- **默认安装路径**：`C:\Program Files\Sublime Text`
- **卸载方式**：运行安装目录下的 `unins000.exe /VERYSILENT`

## 脚本实现

| 项 | 值 |
| --- | --- |
| 脚本常量 | `$SUBLIME_DIR` / `$SUBLIME_SETUP` / `$SUBLIME_SILENT` / `$SUBLIME_INSTDIR` / `$SUBLIME_MAINEXE` |
| 安装位置 | `C:\Program Files\Sublime Text`（走官方默认，脚本**不传** `/DIR`） |
| 静默参数 | `$SILENT_INNO` = `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-` |
| 结果校验 | 检查 `sublime_text.exe` 是否存在 |
| 超时 | `$TIMEOUT_INSTALL`（10 分钟） |

> 已安装检测与结果校验都会先查预期路径，**再查整个系统 `PATH`**。

## 注意事项

- Inno Setup 安装包静默参数为 `/VERYSILENT`（区别于 NSIS 的 `/S`）。
- 如需预置配置或插件，可在安装后拷贝 `Packages` / 配置文件到用户数据目录。

## 变更记录

| 日期 | 版本 | 说明 |
| --- | --- | --- |
| 2026-10-06 | Build 4215 | 首次登记 |
