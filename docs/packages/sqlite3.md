# SQLite3

## 基本信息

| 项 | 内容 |
| --- | --- |
| 软件名称 | SQLite（命令行工具包） |
| 分组 | 基础环境（`base`） |
| 版本 | 3.53.04（x64） |
| 安装包 | `packages/SQLite3/sqlite-tools-win-x64-3530400.zip` |
| 安装脚本 | [`Include/Install/sqlite3.au3`](../../Include/Install/sqlite3.au3) |
| 安装类型 | 绿色解压（无需安装） |
| 用途 | SQLite 数据库命令行工具 |

## 安装说明

- **安装方式**：解压压缩包到指定目录即可，无需运行安装程序。
- **解压内容**：`sqlite3.exe`、`sqldiff.exe`、`sqlite3_analyzer.exe` 等命令行工具。
- **安装路径**：`<安装根目录>\SQLite3`，默认即 `%LOCALAPPDATA%\BJ\auto-install\SQLite3`
  （安装根目录可在配置界面修改，见 [`../usage.md`](../usage.md)）。
- **环境变量**：脚本默认会将该目录写入系统 `PATH`，使 `sqlite3` 命令可全局调用。
- **卸载方式**：直接删除解压目录，并从 `PATH` 中移除。

## 脚本实现

| 项 | 值 |
| --- | --- |
| 脚本常量 | `$SQLITE_DIR` / `$SQLITE_ZIP` / `$SQLITE_SUBDIR` / `$SQLITE_MAINEXE` / `$SQLITE_ADD_PATH` |
| 解压目标 | `<安装根目录>\SQLite3` |
| 解压方式 | `Installer_ExtractZip()`：优先 7-Zip 命令行，失败回退 PowerShell `Expand-Archive` |
| 结果校验 | 检查 `sqlite3.exe` 是否存在 |
| PATH 写入 | `$SQLITE_ADD_PATH = True` 时调用 `Installer_AddToSystemPath()`；**只有本次真的解压到该目录才会写**，若已从 `PATH` 找到现成的 sqlite3 则跳过 |

> 绿色解压类软件（SQLite3、HslCommunicationDemo）会解压到**安装根目录**下；
> 安装包类软件则装到各自的官方默认路径。

## 注意事项

- 属于绿色工具，装机脚本用解压方式部署即可，注意覆盖前先确认目标目录。
- 版本号 `3530400` 对应 SQLite 3.53.04，如更换安装包请同步更新本文档。
- 写系统 `PATH` 需要管理员权限；不想要这个副作用就把 `$SQLITE_ADD_PATH` 改成 `False`，
  脚本会改为在日志里提示手动添加。

## 变更记录

| 日期 | 版本 | 说明 |
| --- | --- | --- |
| 2026-10-06 | 3.53.04 | 首次登记 |
