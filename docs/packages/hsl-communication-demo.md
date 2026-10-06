# HslCommunicationDemo

## 基本信息

| 项 | 内容 |
| --- | --- |
| 软件名称 | HslCommunicationDemo（HslCommunication 通讯调试工具） |
| 版本 | 安装包内未标注（主程序文件版本为占位值 `1.0.0.0`，以包内 `HslCommunication.dll` 实际版本为准） |
| 安装包 | `packages/HslCommunicationDemo/HslCommunicationDemo.zip` |
| 安装脚本 | [`Include/Install/hsl-communication-demo.au3`](../../Include/Install/hsl-communication-demo.au3) |
| 安装类型 | 绿色解压（无需安装） |
| 用途 | 工业通讯协议（Modbus、西门子、三菱、欧姆龙等）在线调试 / 读写测试工具 |

## 安装说明

- **安装方式**：解压压缩包到指定目录即可，无需运行安装程序。
- **解压内容**：`HslCommunicationDemo.exe` 主程序，以及 `HslCommunication.dll`、`HslControls.dll`、
  `Newtonsoft.Json.dll` 等依赖库和 `libcrypto-3-x64.dll` / `libssl-3-x64.dll`。
  压缩包内文件**直接位于根层**（无顶层目录），解压后主程序与依赖 DLL 同级。
- **安装路径**：`<安装根目录>\HslCommunicationDemo`，默认即
  `%LOCALAPPDATA%\BJ\<软件名>\HslCommunicationDemo`（安装根目录可在配置界面修改，见 [`../usage.md`](../usage.md)）。
- **环境变量**：**不写入 `PATH`** —— 这是带界面的调试程序，不需要命令行全局调用。
- **快捷方式**：脚本**不创建**快捷方式；安装后可从解压目录直接运行 `HslCommunicationDemo.exe`。
- **卸载方式**：直接删除解压目录。

## 脚本实现

| 项 | 值 |
| --- | --- |
| 脚本常量 | `$HSL_DIR` / `$HSL_ZIP` / `$HSL_SUBDIR` / `$HSL_MAINEXE` |
| 解压目标 | `<安装根目录>\HslCommunicationDemo` |
| 解压方式 | `Installer_ExtractZip()`：优先 7-Zip 命令行，失败回退 PowerShell `Expand-Archive` |
| 结果校验 | 检查 `HslCommunicationDemo.exe` 是否存在（预期目录 + 系统 `PATH`） |
| 超时 | `$TIMEOUT_UNZIP` |
| PATH 写入 | 无 |

## 注意事项

- 属于绿色工具，装机脚本用解压方式部署即可；覆盖安装前先确认目标目录。
- 这是 **x64** 版本的 .NET WinForms 程序（包内含 `libcrypto-3-x64.dll`），
  目标机需已安装对应的 .NET Framework 运行时，否则无法启动 —— 具体所需版本以实机实测为准。
- 首次运行会在程序目录或用户目录生成配置文件（如 `DemoSettings.txt`），属正常行为。
- 包内版本号未标注，更换安装包后请同步更新 `Include/Install/hsl-communication-demo.au3`
  顶部的常量与本文档。

## 变更记录

| 日期 | 版本 | 说明 |
| --- | --- | --- |
| 2026-10-06 | 未标注 | 首次登记，新增绿色解压安装脚本 |
