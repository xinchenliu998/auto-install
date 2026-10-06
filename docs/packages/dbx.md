# DBX

## 基本信息

| 项 | 内容 |
| --- | --- |
| 软件名称 | DBX（数据库客户端） |
| 分组 | 开发工具（`dev`） |
| 版本 | 0.6.34（x64） |
| 安装包 | `packages/DBX/DBX_0.6.34_x64-offline-setup.exe` |
| 安装脚本 | [`Include/Install/dbx.au3`](../../Include/Install/dbx.au3) |
| 安装类型 | 静默安装（NSIS / Tauri 打包） |
| 用途 | 跨平台开源数据库客户端，支持 MySQL、PostgreSQL、SQLite、Redis、MongoDB、ClickHouse 等 70+ 数据库引擎 |

## 安装说明

- **安装方式**：运行官方安装包，带静默参数。
- **静默参数**：`/S`（NSIS 标准静默参数）。
- **默认安装路径**：`%LOCALAPPDATA%\DBX`。
  安装包的 PE 清单为 `asInvoker`，即 Tauri 的「**当前用户**」安装模式 —— 装到用户目录，
  **不需要管理员权限**，也不是 Program Files。
- **附带依赖**：安装包内置 **WebView2 离线运行时**（Tauri 应用必需）。
  安装程序会先查注册表，系统缺失时才静默安装；**若 WebView2 安装失败，整个安装会中止**。
- **快捷方式**：静默安装会**自动创建**桌面快捷方式与开始菜单项（无需脚本另建）。
- **卸载方式**：`%LOCALAPPDATA%\DBX\uninstall.exe /S`，或从「应用和功能」中卸载。

## 脚本实现

| 项 | 值 |
| --- | --- |
| 脚本常量 | `$DBX_DIR` / `$DBX_SETUP` / `$DBX_SILENT` / `$DBX_TIMEOUT` / `$DBX_MAINEXE` |
| 安装位置 | `%LOCALAPPDATA%\DBX`（走官方默认，脚本**不传** `/D`）；候选另含 `%ProgramFiles%\DBX` |
| 静默参数 | `$SILENT_NSIS` = `/S` |
| 结果校验 | 检查 `dbx.exe` 是否存在（预期目录 + 系统 `PATH`） |
| 超时 | `$TIMEOUT_INSTALL_LONG`（30 分钟）—— 安装包体积大且附带装 WebView2 |

> 已安装检测与结果校验都会先查候选路径，**再查整个系统 `PATH`**。

## 注意事项

- 安装包为 **Tauri**（Rust + WebView2）打包，不是 Electron；文件名中的 `offline` 指
  内置了 WebView2 离线运行时，因此体积较大（约 240MB），安装耗时明显长于普通小软件。
- **按当前用户安装**：安装目标由运行安装程序的那个账号决定。
  本项目会提权运行，若用**与目标用户不同的管理员账号**提权，
  会装到该管理员账号的 `%LOCALAPPDATA%` 下，普通用户看不到 ——
  建议用与目标使用账号相同的账号提权。
- 静默安装**不会**自动启动主程序（仅当追加 `/R` 参数时才启动）。
- 首次启动会在用户目录生成配置/连接信息，属正常行为。
- 更换安装包版本时要同时改三处：`packages/` 下的文件、`Include/Install/dbx.au3`
  顶部的常量、本文档。

## 变更记录

| 日期 | 版本 | 说明 |
| --- | --- | --- |
| 2026-10-06 | 0.6.34 | 首次登记，新增 NSIS 静默安装脚本 |
