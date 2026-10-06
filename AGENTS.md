# AGENTS.md

面向 AI 编码助手的项目说明。**开始改动本项目前请完整阅读本文件。**
给人看的文档在 `README.md` 与 `docs/`，本文件只讲「怎么改才不出错」。

---

## 一、项目是什么

基于 **AutoIt v3** 的工控机（IPC）出厂装机工具集。一个带配置界面的总入口脚本，
按勾选项依次为工控机安装软件、部署文档、执行重复性操作。

无构建系统、无包管理器、无测试框架。交付物是一批 `.au3` 源码 + 编译出的 `.exe`。

---

## 二、先读什么

| 你要做的事 | 先读 |
| --- | --- |
| 改任何代码 | [`docs/development.md`](docs/development.md) —— 架构分层、模块职责、约定 |
| 新增一个软件 | 同上 + [`Include/Install/7zip.au3`](Include/Install/7zip.au3)（静默安装范例）、[`Include/Install/sqlite3.au3`](Include/Install/sqlite3.au3)（绿色解压范例） |
| 改界面 / 配置 / 命令行 | [`docs/usage.md`](docs/usage.md) —— 现有行为是什么样的 |
| 改某个软件的安装参数 | [`docs/packages/`](docs/packages/) 下对应的 `<软件>.md` |

---

## 三、硬约束（违反了一定会出问题）

1. **`.au3` 文件必须带 UTF-8 BOM。**
   用工具生成或覆盖 `.au3` 后，务必确认前 3 字节是 `EF BB BF`。
   缺 BOM 时，含中文的字符串字面量在编译后会变成乱码。

2. **AutoIt 字符串里反斜杠不是转义符。**
   只有双引号需要写成 `""`。即便如此，路径拼接仍统一用 `Common_JoinPath()`，
   取目录用 `Common_FileDir()`，不要手写 `\` 拼接。

3. **数组长度不能为 0。**
   `Local $a[0]` 和 `ReDim $a[0]` 都会报错。返回数组的函数统一保证至少 1 行，
   实际条数用返回值单独传（参考 `Config_GetSelected()`）。

4. **编译目标是 x64。**
   否则 `@ProgramFilesDir` 会指向 `Program Files (x86)`，导致安装结果校验全部失败。

5. **本机通常没有 AutoIt，无法编译。**
   不要声称「已编译通过」。改完必须跑第四节的自检脚本，并在回复里说明「未经编译验证」。

---

## 四、改完必须跑的自检

```bash
python tools/check_au3.py     # 源码
python tools/check_docs.py    # 文档
```

**`check_au3.py`** —— 检查 6 项：UTF-8 BOM、块级关键字配对（能正确处理行继续符 `_`）、
`#include` 目标存在性、项目内函数与常量是否有定义（能抓出拼写错误）、
安装模块注册的目录名是否与安装包目录（默认 `packages/`）一致。
加 `-v` 可列出所有已定义的函数与常量。

**`check_docs.py`** —— 检查 4 项：Markdown 相对链接、文档里提到的项目函数 / 常量是否真实存在、
反引号引用的仓库内路径是否存在、`docs/packages/` 的索引是否登记完整。

两者退出码 0 表示通过。**改了代码或文档后都要跑。**

> 这两个脚本**只能**做静态检查。语法错误、API 用法、界面布局、以及描述性内容是否过时，
> 仍需人工判断或在装有 AutoIt 的机器上实测。

---

## 五、目录与分层

```
auto-install.au3              总入口（配置界面 + 调度），几乎不用改
Include/
  Constants.au3               全局常量，唯一来源
  Common.au3                  基础工具：权限、路径、环境变量、外部命令
  Logger.au3                  日志（文件 + 界面双写）
  Config.au3                  配置读写 + 安装包目录扫描
  Installer.au3               安装调度 + 通用安装流程 + 安装辅助（解压、写 PATH）
  Gui/Config.au3              配置界面：入口 + 消息循环（控件 ID 与状态在此声明）
  Gui/ConfigLayout.au3        配置界面：界面构建
  Gui/ConfigState.au3         配置界面：状态同步 + 校验回写
  Gui/PackageList.au3         配置界面：软件列表控件（带复选框的 ListView）
  Gui/Install.au3             执行界面
  Install/<软件>.au3          各软件的具体安装脚本（自注册）
packages/<软件>/              安装包（默认位置，可在配置界面改；整个目录不入库）
docs/                         文档（细节都在这里）
tools/check_au3.py            源码静态自检
tools/check_docs.py           文档一致性检查
```

**分层原则**：`Constants` 无依赖 → `Common`/`Logger` 是基础层 → `Installer` 是业务层 →
`Install/*` 是最外层实现。**基础层不要反过来依赖上层**（曾因为把带日志的解压函数放进
`Common.au3` 而与 `Logger.au3` 形成循环 include，已改到 `Installer.au3`）。

`Gui/` 是界面层，只负责界面与交互，不写安装逻辑；内部按「入口 / 布局 / 状态 / 列表控件」拆开。
**控件 ID 与界面状态变量统一在 `Gui/Config.au3` 里声明**，同目录其他文件直接用，不要各自再声明一份。

---

## 六、代码约定

- **常量**：框架级常量一律放 `Include/Constants.au3`，通过 `#include "Constants.au3"` 引用，
  不要在业务文件里硬编码数字与字符串。前缀见 `docs/development.md` 第六节。
  - 例外：与单个软件强相关的常量（安装包文件名、安装目录名）留在该软件的
    `Include/Install/<软件>.au3` 顶部，前缀取软件名（`$ZIP7_` / `$SQLITE_` / `$WPS_`）。
- **命名**：安装类函数 `Install_`，操作类 `Action_`，工具类按功能命名。
  模块内部函数统一加模块名前缀（`Common_` / `Logger_` / `Config_` / `Installer_` /
  `GuiConfig_` / `GuiConfigLayout_` / `GuiConfigState_` / `GuiPackageList_` / `GuiInstall_`）。
- **取安装包路径**一律用 `Installer_PackagePath()` —— 它走的是配置里的「安装包目录」
  （可在界面改、可指向仓库之外），不要自己拼 `@ScriptDir\packages`。
- **每个 `.au3`** 顶部写 `#include-once`，并显式 `#include` 自己用到的模块（含 `Constants.au3`）。
- **错误处理与日志**：所有脚本要有日志输出，用 `Logger_Info()` / `Logger_Warn()` / `Logger_Err()`。
- **执行外部命令**统一用 `Common_RunWait()`，等待期间界面不会假死。
- **不要弹窗**：自动化流程中避免 `MsgBox` 打断（配置界面交互除外）。

---

## 七、新增一个软件（最常做的改动）

1. 在**安装包目录**（默认 `packages/`，可在配置界面改，见 `Config_PackagesDirReal()`）下
   新建 `<软件名>/`，放入安装包，并放一份 `package.ini` 指定界面显示名：

   ```ini
   [Package]
   DisplayName=WPS Office
   ```

   > **整个安装包目录都不纳入版本管理**（见 `.gitignore`）：安装包体积过大，
   > 而且该目录本身可配置、可以放在仓库之外。所以安装包与 `package.ini`
   > 都跟随安装包一起管理，不随仓库分发 —— 克隆仓库后需自行创建该目录，
   > 或在配置界面把「安装包目录」指到别处。
   >
   > `package.ini` 内容保持 ASCII，**不要写 BOM**，否则 `IniRead` 可能读不到第一段。

2. `Include/Install/<软件名>.au3`（文件名对齐 `docs/packages/*.md`）。**安装脚本只声明常量 + 填参数**，
   流程全部复用现成函数：

   ```autoit
   #include-once
   #include "..\Constants.au3"
   #include "..\Common.au3"
   #include "..\Logger.au3"
   #include "..\Config.au3"
   #include "..\Installer.au3"

   ; 本软件相关常量（前缀取软件名）
   Global Const $XXX_DIR     = "packages 下的目录名"
   Global Const $XXX_SETUP   = "安装包文件名"
   Global Const $XXX_SILENT  = $SILENT_NSIS        ; 或 $SILENT_INNO
   Global Const $XXX_INSTDIR = "Program Files 下的目录名"
   Global Const $XXX_MAINEXE = "主程序.exe"

   Installer_Register($XXX_DIR, "Install_XXX")     ; 自注册

   Func Install_XXX($sInstallRoot)
       #forceref $sInstallRoot      ; 装到 Program Files 时用不到自定义根目录

       ; 参数：显示名, 安装包, 静默参数, 主程序名, 预期安装路径[, 超时]
       Return Installer_InstallSilent( _
               "XXX 显示名", _
               Installer_PackagePath($XXX_DIR, $XXX_SETUP), _
               $XXX_SILENT, _
               $XXX_MAINEXE, _
               Installer_ProgramFilesPath($XXX_INSTDIR, $XXX_MAINEXE))
   EndFunc
   ```

   要点：
   - `#include` 用 `..\Xxx.au3`（比框架模块深一层）；
   - `Installer_Register("<安装包目录下的目录名>", "Install_XXX")` 自注册，
     **目录名必须与安装包目录下的实际目录完全一致**，否则永远不会被调用；
   - 实现 `Func Install_XXX($sInstallRoot)`，成功返回 `True`，失败返回 `False`；
   - **禁止在安装脚本里重复实现**「已安装检测 / 执行 / 超时 / 结果校验 / 日志」——
     静默安装用 `Installer_InstallSilent()`，绿色解压用 `Installer_InstallGreen()`；
   - 需要多候选安装路径时（如 WPS），把候选数组作为 `$vExpected` 传进去即可；
   - 通用流程内部已经做到：幂等（已装则跳过）、退出码 + 主程序存在性双重校验、
     **检测范围覆盖预期路径与整个系统 PATH**。装好一个模块通常 40 行以内。

3. `auto-install.au3` 的「各软件的安装模块」区域追加一行 `#include`。

4. `docs/packages/<软件名>.md` 按模板补文档，并在 `docs/packages/README.md` 索引表登记一行。

5. 跑 `python tools/check_au3.py`。

**安装位置约定**：第三方安装包装到各自官方默认路径（Program Files 等）；
只有**绿色软件**才解压到 `$sInstallRoot`（即 `%LOCALAPPDATA%\BJ\<软件名>`）。
安装根目录在 `%LOCALAPPDATA%` 下（Local，不随域账户漫游），适合放绿色工具与运行产物；
但仍是用户目录，**不适合安装需要写系统目录的常规软件**——那些走 Program Files。

**执行顺序**由安装包目录下的目录名排序决定，与 `#include` 先后无关。

---

## 八、高频踩坑清单

| 坑 | 正确做法 |
| --- | --- |
| 生成 `.au3` 后忘了补 BOM | 写完立刻检查前 3 字节 |
| 注册目录名与安装包目录下的实际目录大小写/拼写不一致 | 跑自检脚本第 6 项，它会核对（按默认 `packages/`） |
| `ReDim $a[0]` 报错 | 保证至少 1 行，条数用返回值传 |
| 界面在安装时假死 | 用 `Common_RunWait()`；它内部靠 Adlib 消息泵维持响应 |
| 在等待期间弹 `MsgBox` | 会暂停 Adlib 导致界面卡死，改记日志 |
| 写回系统 PATH 破坏了 `%SystemRoot%` 简写 | 见 `Installer_AddToSystemPath()` 的注释；不能接受就把调用方开关改 `False` |
| 只判断固定安装路径就认定「未安装」 | 用 `Installer_FindInstalled()`，它会连带查整个系统 PATH |
| 找依赖工具（如解压用的 7-Zip）只查固定目录 | 用 `Common_Find7Zip()` / `Common_Which()`，同样要覆盖 PATH |
| 在安装脚本里又抄一遍「检测 / 执行 / 校验」 | 用 `Installer_InstallSilent()` / `Installer_InstallGreen()`，脚本里只填参数 |
| 声称「已编译通过」 | 本机没 AutoIt，只能静态自检，回复里要说明 |

---

## 九、文档分工（重要）

- **根 `README.md` 只放概览**：项目简介、适用范围、目录结构（仅一级）、环境要求、
  快速开始、文档索引、许可证。约 80 行，**不要往里塞细节**。
- **细节一律进 `docs/`**：
  - `docs/usage.md` —— 使用说明
  - `docs/development.md` —— 开发规范
  - `docs/packages/<软件>.md` —— 单个软件的安装说明
- 新增内容前先想清楚该进 README 还是 `docs/`；默认进 `docs/`。
- 全库 Markdown 相对链接要保持有效（新增/改名文档后检查一遍）。

---

## 十、回复要求

- 改了哪些文件、为什么改，要写清楚。
- 明确区分「静态自检通过」与「编译/实测通过」—— 后者需要用户在自己的机器上做。
- 静默安装参数属于**建议值**，不同渠道/版本的安装包可能不同，必须提示用户实测确认。
