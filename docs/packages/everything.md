# Everything

## 基本信息

| 项 | 内容 |
| --- | --- |
| 软件名称 | Everything |
| 分组 | 必须安装（`required`） |
| 版本 | 1.4.1.1032（x86） |
| 安装包 | `packages/everything/Everything-1.4.1.1032.x86-Setup.exe` |
| 安装脚本 | [`Include/Install/everything.au3`](../../Include/Install/everything.au3) |
| 安装类型 | 静默安装（Inno Setup） |
| 用途 | 文件名快速搜索工具 |

## 安装说明

- **安装方式**：运行官方安装包，带静默参数（Inno Setup 安装包）。
- **静默参数**：`/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-`
  - 指定安装目录：追加 `/DIR="C:\Program Files\Everything"`
- **默认安装路径**：`C:\Program Files\Everything`
- **卸载方式**：控制面板卸载，或运行安装目录下的 `uninstall.exe /VERYSILENT`

## 脚本实现

| 项 | 值 |
| --- | --- |
| 脚本常量 | `$EVERYTHING_DIR` / `$EVERYTHING_SETUP` / `$EVERYTHING_SILENT` / `$EVERYTHING_INSTDIR` / `$EVERYTHING_MAINEXE` |
| 安装位置 | `C:\Program Files\Everything`（走官方默认，脚本**不传** `/DIR`） |
| 静默参数 | `$SILENT_INNO` = `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-` |
| 结果校验 | 检查 `Everything.exe` 是否存在 |
| 超时 | `$TIMEOUT_INSTALL`（10 分钟） |

> 已安装检测与结果校验都会先查预期路径，**再查整个系统 `PATH`** ——
> Everything 也有绿色版，挂在 `PATH` 上时同样能识别为「已安装」。

## 注意事项

- 当前提供的是 **x86 版本**，在 64 位系统上同样可运行；如需 64 位版本请另行准备安装包。
- Everything 依赖 NTFS 索引，首次启动可能需要管理员权限建立索引服务。

## 变更记录

| 日期 | 版本 | 说明 |
| --- | --- | --- |
| 2026-10-06 | 1.4.1.1032 | 首次登记 |
