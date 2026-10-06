# WPS Office

## 基本信息

| 项 | 内容 |
| --- | --- |
| 软件名称 | WPS Office |
| 版本 | 安装包版本号 28505 |
| 安装包 | `packages/wps/WPS_Setup_28505.exe` |
| 安装脚本 | [`Include/Install/wps.au3`](../../Include/Install/wps.au3) |
| 安装类型 | 静默安装 |
| 用途 | 办公软件（文字 / 表格 / 演示） |

## 安装说明

- **安装方式**：运行官方安装包，带静默参数。
- **静默参数**：`/S`（需实测确认；不同渠道版本参数可能不同）
- **默认安装路径**：通常为 `C:\Users\<用户名>\AppData\Local\Kingsoft\WPS Office`，或 `C:\Program Files\WPS Office`
- **卸载方式**：控制面板卸载，或使用安装目录下的卸载程序

## 脚本实现

| 项 | 值 |
| --- | --- |
| 脚本常量 | `$WPS_DIR` / `$WPS_SETUP` / `$WPS_SILENT` / `$WPS_TIMEOUT` / `$WPS_MAINEXE` |
| 安装位置 | 由 WPS 自行决定，脚本不干预 |
| 静默参数 | `$SILENT_NSIS` = `/S`（**待实测确认**） |
| 已安装检测 / 结果校验 | 依次查 4 个候选目录，再查整个系统 `PATH` 中的 `wps.exe` |
| 超时 | `$WPS_TIMEOUT` = `$TIMEOUT_INSTALL_LONG`（30 分钟） |

候选安装目录（按顺序判断）：

1. `C:\Program Files\WPS Office`
2. `C:\Program Files\Kingsoft\WPS Office`
3. `%LOCALAPPDATA%\Kingsoft\WPS Office`
4. `%APPDATA%\Kingsoft\WPS Office`

> WPS 与 DBX 都使用**候选路径数组** —— 因为它们的安装位置不固定。
> 通用流程 `Installer_InstallSilent()` 的 `$vExpected` 参数支持传数组，正是为这种情况准备的。

## 注意事项

- WPS 安装包体积较大，安装耗时较长，脚本已相应放宽超时（见上方「脚本实现」）。
- 安装完成后通常会有**首次启动引导 / 广告推广**，建议在脚本中一并处理或预置配置以跳过。
- 若需统一去除弹窗，可考虑使用企业版 / 专业版安装包，或部署统一配置。
- 静默参数务必在目标系统实测确认后再批量使用。

## 变更记录

| 日期 | 版本 | 说明 |
| --- | --- | --- |
| 2026-10-06 | 28505 | 首次登记 |
