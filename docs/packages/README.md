# 软件安装说明（docs/packages）

本目录与项目根目录的 [`packages/`](../../packages/) 一一对应，**每款软件一份文档**，记录其版本、安装包、安装方式、静默参数、安装路径及注意事项，供装机脚本开发与出厂核对时查阅。

## 文档索引

「分组」是配置界面软件列表里显示的分类，来自各软件目录下 `package.ini` 的 `Category`
（`required` = 必须安装，勾选被锁定，见 [`../usage.md`](../usage.md)）。

> **只有右侧「安装脚本」列有链接的软件才会出现在配置界面的列表里。**
> 配置界面扫描安装包目录时只收「已适配」的目录（已有 `Installer_Register()` 注册），
> 光有安装包、没有脚本的目录会被忽略（排障时把 `config.ini` 的
> `[General] ShowUnsupported` 设成 `1` 可让它们以「(未适配)」显示，见 [`../usage.md`](../usage.md)）。

| 软件 | 分组 | 说明文档 | 安装包目录 | 安装脚本 |
| --- | --- | --- | --- | --- |
| 7-Zip | 必须安装（`required`） | [7zip.md](7zip.md) | `packages/7zip/` | [`Include/Install/7zip.au3`](../../Include/Install/7zip.au3) |
| Everything | 必须安装（`required`） | [everything.md](everything.md) | `packages/everything/` | [`Include/Install/everything.au3`](../../Include/Install/everything.au3) |
| SQLite3 | 基础环境（`base`） | [sqlite3.md](sqlite3.md) | `packages/SQLite3/` | [`Include/Install/sqlite3.au3`](../../Include/Install/sqlite3.au3) |
| Sublime Text | 开发工具（`dev`） | [sublime-text.md](sublime-text.md) | `packages/Sublime Text/` | [`Include/Install/sublime-text.au3`](../../Include/Install/sublime-text.au3) |
| DBX | 开发工具（`dev`） | [dbx.md](dbx.md) | `packages/DBX/` | [`Include/Install/dbx.au3`](../../Include/Install/dbx.au3) |
| HslCommunicationDemo | 调试工具（`debug`） | [hsl-communication-demo.md](hsl-communication-demo.md) | `packages/HslCommunicationDemo/` | [`Include/Install/hsl-communication-demo.au3`](../../Include/Install/hsl-communication-demo.au3) |
| HALCON | 机器视觉（`vision`） | [halcon.md](halcon.md) | `packages/halcon/` | [`Include/Install/halcon.au3`](../../Include/Install/halcon.au3) |
| WPS Office | 办公软件（`office`） | [wps.md](wps.md) | `packages/wps/` | [`Include/Install/wps.au3`](../../Include/Install/wps.au3) |

## 文档模板

新增软件时，请按以下结构编写说明文档：

```markdown
# 软件名称

## 基本信息

| 项 | 内容 |
| --- | --- |
| 软件名称 | |
| 分组 | 必须安装（`required`）/ 基础环境（`base`）/ 开发工具（`dev`）/ 调试工具（`debug`）/ 机器视觉（`vision`）/ 办公软件（`office`）/ 未分组（`misc`）。未适配（`unsupported`）不用手写，由扫描自动归入 |
| 版本 | |
| 安装包 | `packages/<目录>/<安装包文件名>` |
| 安装脚本 | `Include/Install/<软件名>.au3` |
| 安装类型 | 静默安装 / 绿色解压 / 手动安装 |
| 用途 | |

## 安装说明

- **安装方式**：
- **静默参数**：
- **默认安装路径**：
- **卸载方式**：

## 脚本实现

> 有安装脚本时补这一节，记录脚本实际行为，避免文档与代码脱节。

| 项 | 值 |
| --- | --- |
| 脚本常量 | |
| 安装位置 | |
| 静默参数 | |
| 结果校验 | |
| 超时 | |

## 注意事项

- 

## 变更记录

| 日期 | 版本 | 说明 |
| --- | --- | --- |
```

> **说明**
>
> - 文档中的静默参数为**建议值**，实际以安装包类型和目标系统实测结果为准。
> - 「安装说明」记录**安装包本身**的特性；「脚本实现」记录**项目脚本**的实际做法，
>   两者不一致时（例如脚本没传 `/D` 参数）要以「脚本实现」为准。
> - 「分组」要和 `packages/<目录>/package.ini` 里的 `Category` 保持一致；
>   `package.ini` 只写 ASCII 键，不要写中文、不要带 BOM（原因见 [`../usage.md`](../usage.md)）。
> - 更换安装包版本时，需要同时改三处：`packages/` 下的文件、`Include/Install/<软件>.au3`
>   顶部的常量、本文档。
