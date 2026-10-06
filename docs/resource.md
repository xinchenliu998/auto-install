# 参考资料

> 本文收集与本项目相关的参考链接。项目自身的文档索引见 [`../README.md`](../README.md)。

## AutoIt

| 链接 | 说明 |
| --- | --- |
| <https://www.autoitscript.com/autoit3/docs/> | **AutoIt v3 官方文档** —— 函数、宏、UDF 参考。写代码时最主要的查阅对象 |
| <https://www.autoitscript.com/autoit3/docs/libfunctions.htm> | 官方 UDF（`Include\*.au3`）索引，本项目用到的 `GuiRichEdit` / `GuiListView` / `File` 等都在这里 |
| <https://www.autoitx.com/> | AutoIt 中文社区（中文教程与提问） |

> 本机安装 AutoIt 后，官方文档的离线版在安装目录的 `AutoIt.chm`；
> 命令行语法检查器为 `Au3Check.exe`，用法见 [`development.md`](development.md) 第七节。

## 相关工具（非本项目依赖）

| 链接 | 说明 |
| --- | --- |
| <https://github.com/mario-andreschak/mcp-windows-desktop-automation> | Windows 桌面自动化的 MCP 服务。**与本项目无直接关系**，仅作同类方案参考 |

## 本项目的自检工具

| 命令 | 说明 |
| --- | --- |
| `python tools/check_syntax.py` | 语法检查（调 AutoIt 官方 `Au3Check.exe`，含单文件检查） |
| `python tools/check_au3.py` | AutoIt 源码文本级静态自检（6 项） |
| `python tools/check_docs.py` | 文档与代码一致性检查（4 项） |
| `AutoIt3_x64.exe tools\precheck_smoke.au3` | 前置检查只读探针冒烟测试（不修改系统） |

详见 [`development.md`](development.md) 第七节。
