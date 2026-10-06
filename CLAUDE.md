# CLAUDE.md

> **开始改动本项目前，请先完整阅读 [`AGENTS.md`](AGENTS.md)。**
> 那里有本项目的全部开发约定、分层结构、新增软件的完整流程和踩坑清单。
> 本文件只摘出最容易出错、必须记住的几条，以及 Claude 侧的补充说明。

---

## 项目一句话

基于 **AutoIt v3** 的工控机出厂装机工具集：一个带配置界面的总入口脚本，
按勾选项依次安装软件、部署文档、执行重复性操作。无构建系统、无包管理器、无测试框架。

---

## 必须记住的硬约束

1. **`.au3` 文件必须带 UTF-8 BOM**（前 3 字节 `EF BB BF`）。
   缺了会让中文字符串字面量在编译后乱码。用工具生成/覆盖 `.au3` 后务必补上。

2. **本机装了 AutoIt（`D:\Program Files (x86)\AutoIt3`），语法要真查一遍。**
   跑 `python tools/check_syntax.py`（调官方 `Au3Check.exe`）。
   但不要声称「已编译通过」「已实测通过」—— 行为和界面仍需在目标机验证。

3. **AutoIt 字符串里反斜杠不是转义符。**
   路径拼接统一用 `Common_JoinPath()`，取目录用 `Common_FileDir()`，不要手写 `\` 拼接。

4. **数组长度不能为 0**（`Local $a[0]` / `ReDim $a[0]` 会报错）。
   返回数组的函数保证至少 1 行，条数用返回值单独传。

5. **新增安装模块时，`Installer_Register()` 的目录名必须与安装包目录下的实际目录完全一致**，
   否则该模块永远不会被调用。自检脚本会按默认的 `packages/` 核对这一项。

6. **常量集中在 `Include/Constants.au3`**，不要在业务文件里硬编码。
   例外：单软件相关的常量（安装包名、安装目录名）留在 `Include/Install/<软件>.au3` 顶部。

7. **取安装包路径一律用 `Installer_PackagePath()`** —— 它走的是配置里的「安装包目录」
   （可在界面改、可指向仓库之外），不要自己拼 `@ScriptDir\packages`。

8. **`Include/Gui/` 的控件 ID 与界面状态变量统一在 `Gui/ConfigShared.au3` 声明**，
   同目录的 Config / Layout / State / PackageList 子模块各自 `#include "ConfigShared.au3"`
   引入，不要各自再声明一份。

9. **等待外部命令统一用 `Installer_RunWaitBeat()`**，不要直接调 `Common_RunWait()` ——
   前者会持续输出「等待心跳」（界面计时 + 定期日志），避免长时间安装看起来像卡死。

10. **每个 `.au3` 都要能「单独打开不报错」。**
    共享的常量 / 变量 / 函数别留在父文件里 —— 整体编译能过（编译时父文件先声明了），
    但在 SciTE 里逐个浏览子模块就是一片红字（`Foo_Bar(): undefined function` /
    `$g_x: undeclared global variable`）。做法是把共享声明抽成独立文件，
    由需要它的每个文件自己 `#include`：`Include/Precheck/Base.au3`、
    `Include/Gui/ConfigShared.au3`、`Include/Config/Shared.au3`。
    `python tools/check_syntax.py` 第 3 项会逐个核对。

11. **配置模块已按配置域拆分，改配置相关代码要对号入座。**
    `Include/Config.au3` 只是入口（只放 `Config_Load()` / `Config_Save()`），
    实体在 `Include/Config/` 下的 4 个子模块：

    | 文件 | 管什么 |
    | --- | --- |
    | `Config/Shared.au3` | 全局状态 `$g_*` + 通用小工具（含 `Config_DefaultRoot()`） |
    | `Config/General.au3` | 安装根目录 / 资源拷贝 / 开机账户 |
    | `Config/Packages.au3` | 安装包目录 + 软件列表（扫描 / 访问器 / 勾选） |
    | `Config/Group.au3` | 分组键 / 顺序 / 中文显示名 +「必须安装」 |

    分层：`Shared` → `General` / `Group` → `Packages` → `Config`（入口）。
    **共享的东西必须放最底层的 `Shared.au3`**，否则单文件检查会报 `undefined function`。
    子模块函数一律沿用 `Config_` 前缀（它们是模块对外 API，被 `Gui/`、`Installer.au3`、
    总入口调用），**拆文件不该顺带改调用方**。

12. **外部命令返回 0 ≠ 状态已生效。**
    设置类操作（密码策略、电源、远程桌面等）**必须回读确认**，不能只看退出码。
    典型：`Set-LocalUser` / `Get-LocalUser` 属 PowerShell 的 **LocalAccounts 模块**，
    精简版 / 老版本工控机上**常常没装**，调用报 `CommandNotFoundException` 且退出码为 `1` ——
    所以「Set-LocalUser 不可用」是**预期情况**，必须有回退路径。判定结果要**真查目标属性**
    （如读 WMI `Win32_UserAccount.PasswordExpires` 确认密码是否真不过期），
    否则会出现「[更改后] 密码会过期」紧跟「[OK] 检查通过」的自相矛盾日志。

13. **RichEdit 有三套字符坐标系，混用会导致日志逐行「串色」。**
    ① `_GUICtrlRichEdit_GetTextLength($h, True, True)` —— 中文每个多算 1；
    ② `StringLen(GetText(...))` —— `@CRLF` 算 2；
    ③ `SetSel` / `GetSel` 的内部坐标 —— `@CRLF` 算 1，**只有这套 SetSel 认**。
    **不要自己算位置**：追加后用 `_GUICtrlRichEdit_GetSel()` 读回真实末尾，
    着色区间取 `[上次末尾, 本次末尾)`。见 `Logger_Write()`。

14. **给 RichEdit 上色的顺序**：必须**先追加文字 → 再选中刚追加的范围 → 最后设色**。
    反过来（先设色再追加）会因为 `SCF_SELECTION` 作用于光标前一个字符而整体错位一行。
    颜色常量是 **COLORREF(BGR)**，与 GUI 函数的 RGB 不同，用 `Logger_RgbToColorRef()` 转换。

---

## 改完必须跑

```bash
python tools/check_syntax.py  # 语法（调 AutoIt 官方 Au3Check.exe）
python tools/check_au3.py     # 源码
python tools/check_docs.py    # 文档
```

- `check_syntax.py`：**真正的语法检查**。从总入口出发，Au3Check 跟进整条 `#include` 链；
  顺带核对有没有 `.au3` 没被任何 `#include` 引用（会漏检）。退出码 2 = 没找到 `Au3Check.exe`，**不算通过**。
- `check_au3.py`：UTF-8 BOM、块级关键字配对（含行继续符 `_`）、`#include` 目标、
  函数与常量定义、安装模块注册目录名。`-v` 列出所有已定义的函数与常量。
- `check_docs.py`：Markdown 相对链接、文档提到的项目函数 / 常量是否存在、
  反引号引用的仓库内路径、`docs/packages/` 索引完整性。

三者退出码 0 为通过。**改了代码或文档后都要跑。**

> 后两个是文本级检查，**查不出语法错误**（例如 `@PID` 这个不存在的宏它们都放行）。
> 语法正确也不等于行为正确：API 用法、界面布局、外部命令参数仍需人工判断或实测。

**改动「解析外部命令输出」的代码后，还要跑一次只读冒烟测试**（不改系统，安全）：

```bash
AutoIt3_x64.exe tools\precheck_smoke.au3    # 结果见 %TEMP%\precheck-smoke.txt
```

它会把前置检查各探针在这台机器上真实读到的值打出来。曾经因为把 `StringRegExp(..., 3)`
的返回值理解错（它返回的是**纯匹配数组，没有计数元素**，个数要用 `UBound()` 取），
电源状态在真机上一直显示「无法读取」，而三项静态检查全部通过。

---

## 文档分工

**根 `README.md` 只放概览，细节一律进 `docs/`。** 新增内容前先想清楚放哪，默认进 `docs/`。

| 文档 | 内容 |
| --- | --- |
| [`AGENTS.md`](AGENTS.md) | 面向 AI 助手的开发约定（**改代码前必读**） |
| [`docs/usage.md`](docs/usage.md) | 使用说明：配置界面、命令行、前置检查、配置文件、日志着色 |
| [`docs/development.md`](docs/development.md) | 开发规范：架构、目录与模块职责、新增软件流程、常量约定 |
| [`docs/packages/`](docs/packages/) | 各软件的安装说明（版本、安装包、静默参数、安装路径） |

---

## Claude 侧补充

- 项目位于 Windows，shell 为 Git Bash；路径用正斜杠或转义后的反斜杠。
- AutoIt 装在 `D:\Program Files (x86)\AutoIt3`，`Au3Check.exe` 就在那里；
  改动 `.au3` 后**先跑 `python tools/check_syntax.py`**，再跑另外两个脚本。
- 改动 `.au3` 后如果用了 Write/Edit 覆盖整个文件，**记得回头确认 BOM 还在**——
  自检脚本第 1 项就是查这个（Write 工具会把 BOM 吃掉，需要补）。
- 回复时把「语法检查通过」「静态自检通过」「实测通过」分清楚，最后一项需要用户在目标机上做。
- 静默安装参数属于建议值，不同渠道/版本的安装包可能不同，必须提示用户实测确认。
