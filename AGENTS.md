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

5. **本机装了 AutoIt（`D:\Program Files (x86)\AutoIt3`），语法必须用 `Au3Check.exe` 真查一遍。**
   `tools/check_syntax.py` 已封装好，改完必跑。
   需要更强的验证时，也可以用 AutoIt 目录下 `Aut2Exe` 里的 `Aut2exe_x64.exe` 真编译一次
   （能同时验证 include 链与 x64 目标）。
   但无论哪种，都**不要**声称「已实测通过」—— 行为、界面布局、外部命令参数仍要在目标机上验证。
   编译产物 `auto-install.exe` 已在 `.gitignore` 里，**不要提交、也不要留在仓库目录**。

6. **每个 `.au3` 都要能「单独打开不报错」。**
   共享的常量 / 变量 / 函数不要留在父文件里 —— 整体编译不报错（编译时父文件先声明了），
   但在 SciTE 里逐个浏览子模块就是一片红字：
   `Foo_Bar(): undefined function` / `$g_x: undeclared global variable`。
   做法：**把共享声明抽成独立文件，由需要它的每个文件自己 `#include`** ——
   参考 `Include\Precheck\Base.au3`、`Include\Gui\ConfigShared.au3`。
   `tools/check_syntax.py` 第 3 项会逐个文件跑 Au3Check 核对这一点。

7. **`.ini` 里不要写中文值（`package.ini` / `config.ini`）。**
   AutoIt 的 `IniRead` 是按 **ANSI 代码页**读无 BOM 文件的。实测三种编码读同一个中文值：

   | 编码 | 结果 |
   | --- | --- |
   | UTF-8 无 BOM | **乱码**（4 个字读成 6 个乱码字） |
   | UTF-8 带 BOM | **整段读不到**，`[Package]` 段都解析不出来，`DisplayName` 回落成目录名 |
   | ANSI / GBK | 正确 |

   所以 `package.ini` 一律保持 ASCII：中文**显示名**放 `Config_CategoryName()`（`Config\Group.au3`），
   键值只用 ASCII（`DisplayName` / `Category` / `Required`）。
   文件里的中文**注释**没问题（注释在 `;` 之后，不参与解析）。

---

## 四、改完必须跑的自检

```bash
python tools/check_syntax.py   # 语法（调 AutoIt 官方 Au3Check.exe）
python tools/check_au3.py      # 源码
python tools/check_docs.py     # 文档
```

**`check_syntax.py`** —— 真正的**语法**检查，调用 AutoIt 官方的 `Au3Check.exe`：

- 从总入口 `auto-install.au3` 出发，Au3Check 会自行跟进整条 `#include` 链，等于查了全部源码；
- 顺带核对「有没有 `.au3` 没被任何 `#include` 引用」—— 这种文件会漏检；
- 用较严的警告档位（`-w 3 -w 4 -w 5 -w 6`，都是 Au3Check 默认关闭的项），当前项目是 0 error / 0 warning；
- 退出码：0 = 通过；1 = 有语法错误或漏检文件；2 = 没找到 `Au3Check.exe`（此时**不算通过**）。

> **这一步不能省。** 下面两个脚本是文本级检查，**查不出语法错误** ——
> 例如 `@PID`（AutoIt 里根本没这个宏，应为 `@AutoItPID`），两个脚本都放行了，
> 只有 Au3Check 会报 `error: undefined macro`。

**`check_au3.py`** —— 检查 6 项：UTF-8 BOM、块级关键字配对（能正确处理行继续符 `_`）、
`#include` 目标存在性、项目内函数与常量是否有定义（能抓出拼写错误）、
安装模块注册的目录名是否与安装包目录（默认 `packages/`）一致。
加 `-v` 可列出所有已定义的函数与常量。

**`check_docs.py`** —— 检查 4 项：Markdown 相对链接、文档里提到的项目函数 / 常量是否真实存在、
反引号引用的仓库内路径是否存在、`docs/packages/` 的索引是否登记完整。

三者退出码 0 表示通过。**改了代码或文档后都要跑。**

### 解析外部命令输出的代码，必须真跑一遍

前置检查里有不少「解析外部命令输出」的逻辑（`powercfg /query`、`netsh ... show rule`、
WMI 查询）。**这类代码静态检查和语法检查都查不出对错** —— 曾经因为把
`StringRegExp(..., 3)` 的返回值理解错，电源状态一直显示「无法读取」，编译却毫无问题。

所以提供了只读冒烟测试（**不开启远程桌面、不改防火墙、不改电源、不建账户**）：

```bash
AutoIt3_x64.exe tools\precheck_smoke.au3
```

跑完看 `%TEMP%\precheck-smoke.txt`，里面是各探针在这台机器上真实读到的值。
新增或改动任何探针函数后，都应该跑一次确认能读到值。

> 语法检查通过 ≠ 行为正确。AutoIt API 用法、界面布局、外部命令参数、以及描述性内容是否过时，
> 仍需人工判断或在目标机上实测。

---

## 五、目录与分层

```
auto-install.au3              总入口（配置界面 + 调度），几乎不用改
Include/
  Constants.au3               全局常量，唯一来源
  Common.au3                  基础工具：权限、路径、环境变量、外部命令
  Logger.au3                  日志（文件 + 界面双写；界面按级别着色）
  Config.au3                  配置模块入口：Config_Load() / Config_Save()
  Config/Shared.au3           配置共享底座：全局状态 + 通用小工具（各子模块各自 include）
  Config/General.au3          通用配置项：安装根目录 / 资源拷贝目录 / 开机账户
  Config/Packages.au3         安装包目录 + 软件列表：扫描、访问器、勾选
  Config/Group.au3            软件分组：分组键 / 顺序 / 显示名 +「必须安装」
  Installer.au3               安装调度 + 通用安装流程 + 安装辅助（解压、写 PATH、等待心跳）
  Precheck.au3                前置检查入口：Precheck_RunAll()
  Precheck/Base.au3           前置检查共享底座：状态 + 辅助（各子模块各自 include）
  Precheck/System.au3         前置检查 1/5：系统版本与内部版本号
  Precheck/Network.au3        前置检查 2/5：ping 与远程桌面
  Precheck/Power.au3          前置检查 3/5：电源（永不睡眠 / 永不休眠）
  Precheck/Driver.au3         前置检查 4/5：设备驱动异常
  Precheck/Account.au3        前置检查 5/5：开机账户
  Gui/ConfigShared.au3        配置界面共享声明：控件 ID + 界面状态（各子模块各自 include）
  Gui/Config.au3              配置界面：入口 + 消息循环
  Gui/ConfigLayout.au3        配置界面：界面构建
  Gui/ConfigState.au3         配置界面：状态同步 + 校验回写
  Gui/PackageList.au3         配置界面：软件列表控件（带复选框的 ListView）
  Gui/Install.au3             执行界面
  Install/All.au3             安装模块汇总：集中 include 各软件安装脚本（新增软件登记在此）
  Install/<软件>.au3          各软件的具体安装脚本（自注册）
packages/<软件>/              安装包（默认位置，可在配置界面改；整个目录不入库）
docs/                         文档（细节都在这里）
tools/check_syntax.py         语法检查（调 AutoIt 官方 Au3Check.exe）
tools/check_au3.py            源码静态自检
tools/check_docs.py           文档一致性检查
tools/precheck_smoke.au3      前置检查只读探针冒烟测试（不修改系统，需 AutoIt 环境）
```

**分层原则**：`Constants` 无依赖 → `Common`/`Logger` 是基础层 → `Installer`/`Precheck` 是业务层 →
`Install/*` 是最外层实现。**基础层不要反过来依赖上层**（曾因为把带日志的解压函数放进
`Common.au3` 而与 `Logger.au3` 形成循环 include，已改到 `Installer.au3`）。

`Config` 模块内部同样分层：`Config/Shared.au3`（底座，只依赖 `Constants`/`Common`）→
`Config/General.au3` / `Config/Group.au3` → `Config/Packages.au3` → `Config.au3`（入口）。
**共享的全局状态与工具函数一律放 `Shared.au3`** —— 放上层会让下层文件单独检查时报
`undefined function`（`Config_DefaultRoot()` 踩过这个坑，见第三节硬约束 6）。

`Precheck.au3` 是「整批前置操作」的范例：一个模块收一类检查，对外只暴露 `Precheck_RunAll()`，
由界面层在安装前调用；**不要在 `Installer_RunAll()` 里堆前置/后置操作**。新增同类模块时照此办理。

`Precheck.au3` 与 `Include\Precheck\` 的分法同 `Include\Gui\`：**共享声明抽成独立文件
（`Precheck\Base.au3` / `Gui\ConfigShared.au3`），由需要它的每个文件自己 `#include`**；
入口只放入口，子模块一个文件一项职责，各自独立函数前缀（`PrecheckSystem_` / `PrecheckNetwork_` /
`PrecheckPower_` / `PrecheckDriver_` / `PrecheckAccount_`）。

> **子模块必须能「单独打开不报错」**（见第三节硬约束 6）——
> 共享声明不要留在父文件里，否则在 SciTE 里逐个浏览每个子模块都是红字。

`Gui/` 是界面层，只负责界面与交互，不写安装逻辑；内部按「共享声明 / 入口 / 布局 / 状态 / 列表控件」拆开。
**控件 ID 与界面状态变量统一在 `Gui/ConfigShared.au3` 里声明**，同目录其他文件各自 include，
不要各自再声明一份。

---

## 六、代码约定

- **常量**：框架级常量一律放 `Include/Constants.au3`，通过 `#include "Constants.au3"` 引用，
  不要在业务文件里硬编码数字与字符串。前缀见 `docs/development.md` 第六节。
  - 例外：与单个软件强相关的常量（安装包文件名、安装目录名）留在该软件的
    `Include/Install/<软件>.au3` 顶部，前缀取软件名（`$ZIP7_` / `$SQLITE_` / `$WPS_`）。
- **命名**：安装类函数 `Install_`，操作类 `Action_`，工具类按功能命名。
  模块内部函数统一加模块名前缀（`Common_` / `Logger_` / `Config_` / `Installer_` /
  `Precheck_` / `PrecheckSystem_` / `PrecheckNetwork_` / `PrecheckPower_` / `PrecheckDriver_` /
  `PrecheckAccount_` / `GuiConfig_` / `GuiConfigLayout_` / `GuiConfigState_` / `GuiPackageList_` /
  `GuiInstall_`）。
- **取安装包路径**一律用 `Installer_PackagePath()` —— 它走的是配置里的「安装包目录」
  （可在界面改、可指向仓库之外），不要自己拼 `@ScriptDir\packages`。
- **每个 `.au3`** 顶部写 `#include-once`，并显式 `#include` 自己用到的模块（含 `Constants.au3`）。
- **错误处理与日志**：所有脚本要有日志输出，用 `Logger_Info()` / `Logger_Warn()` / `Logger_Err()`。
- **执行外部命令**统一用 `Installer_RunWaitBeat()`（内部走 `Common_RunWait()`），
  等待期间界面不会假死，并会输出「等待心跳」避免长任务被误认为卡死。
- **不要弹窗**：自动化流程中避免 `MsgBox` 打断（配置界面交互除外）。

---

## 七、新增一个软件（最常做的改动）

1. 在**安装包目录**（默认 `packages/`，可在配置界面改，见 `Config_PackagesDirReal()`）下
   新建 `<软件名>/`，放入安装包，并放一份 `package.ini` 指定显示名、分组与是否必须安装：

   ```ini
   [Package]
   DisplayName=WPS Office
   Category=office
   Required=0
   ```

   - `Category` 取 `Include\Constants.au3` 的 `$PKG_CAT_ORDER` 里的键
     （`required` / `base` / `dev` / `debug` / `vision` / `office` / `misc`），省略归入「未分组」（`misc`）；
     想在界面上排到别的位置就调 `$PKG_CAT_ORDER` 的顺序。
   - `Required=1` 表示**必须安装**：固定归入「必须安装」组并排最前，界面与 `config.ini`
     都取消不掉它的勾选。分组与勾选的读取/强制逻辑在 `Include\Config\Packages.au3`
     （`Config_ScanPackages()`）与 `Include\Config\Group.au3`
     （`Config_BuildGroups()` / `Config_ApplyRequired()`），
     列表显示在 `Include\Gui\PackageList.au3`。
   - 界面里中文分组名由 `Config_CategoryName()` 映射，`package.ini` 只写 ASCII 键值
     —— 原因见第三节硬约束 7。

   > **整个安装包目录都不纳入版本管理**（见 `.gitignore`）：安装包体积过大，
   > 而且该目录本身可配置、可以放在仓库之外。所以安装包与 `package.ini`
   > 都跟随安装包一起管理，不随仓库分发 —— 克隆仓库后需自行创建该目录，
   > 或在配置界面把「安装包目录」指到别处。
   >
   > `package.ini` 内容保持 ASCII，**不要写 BOM**（硬约束 7：带 BOM 会让 `IniRead`
   > 连 `[Package]` 段都读不到）。

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
   - 需要多候选安装路径时（如 WPS、DBX），把候选数组作为 `$vExpected` 传进去即可；
   - 通用流程内部已经做到：幂等（已装则跳过）、退出码 + 主程序存在性双重校验、
     **检测范围覆盖预期路径与整个系统 PATH**。装好一个模块通常 40 行以内。

3. 在 `Include/Install/All.au3` 的「安装模块列表」追加一行 `#include "<软件名>.au3"`。
   总入口 `auto-install.au3` 只 `#include` 这个汇总文件，**无需改动**。

4. `docs/packages/<软件名>.md` 按模板补文档，并在 `docs/packages/README.md` 索引表登记一行。

5. 跑 `python tools/check_syntax.py`（语法）与 `python tools/check_au3.py`（源码自检）。

**安装位置约定**：安装包类软件装到各自的官方默认路径（多数在 Program Files，也有落在用户目录的，如 DBX）；
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
| 界面在安装时假死 | 用 `Installer_RunWaitBeat()`；内部靠 Adlib 消息泵维持响应 |
| 长时间安装「看起来像卡死」 | 等待统一走 `Installer_RunWaitBeat()`，它会持续输出等待心跳（界面计时 + 定期日志） |
| 在等待期间弹 `MsgBox` | 会暂停 Adlib 导致界面卡死，改记日志 |
| 写回系统 PATH 破坏了 `%SystemRoot%` 简写 | 见 `Installer_AddToSystemPath()` 的注释；不能接受就把调用方开关改 `False` |
| 只判断固定安装路径就认定「未安装」 | 用 `Installer_FindInstalled()`，它会连带查整个系统 PATH |
| 找依赖工具（如解压用的 7-Zip）只查固定目录 | 用 `Common_Find7Zip()` / `Common_Which()`，同样要覆盖 PATH |
| 在安装脚本里又抄一遍「检测 / 执行 / 校验」 | 用 `Installer_InstallSilent()` / `Installer_InstallGreen()`，脚本里只填参数 |
| 改了 `.au3` 却不跑语法检查 | 跑 `python tools/check_syntax.py`（Au3Check）；文本级脚本查不出语法错误 |
| 共享声明留在父文件里 | 整体编译能过，但子模块单独打开全是红字。抽成独立文件让子模块各自 `#include` |
| 共享函数放错层（如 `Config_DefaultRoot()` 放 `General.au3` 而 `Shared.au3` 要调它） | 整体编译能过，**单文件 Au3Check 报 `undefined function`**（`check_syntax.py` 第 3 项）。共享的东西一律放各自最底层那个文件 |
| 往 `package.ini` / `config.ini` 里写中文值 | `IniRead` 按 ANSI 读，UTF-8 中文读成乱码、带 BOM 整段读不到。ini 只写 ASCII，中文映射放 `Config\Group.au3` 的 `Config_CategoryName()` |
| 「必须安装」的勾选被绕过 | 读取（`Config_ScanPackages`）、重扫（`Config_RescanPackages`）、写入（`Config_SetPackageEnabled`）、界面（`GuiPackageList_EnforceRequired`）四处都要强制，少一处就能被点掉 |
| 用了不存在的宏（如 `@PID`，应为 `@AutoItPID`） | 只有 Au3Check 能抓到，必须跑语法检查 |
| 解析外部命令输出的代码只靠静态检查 | 必须真跑 `tools\precheck_smoke.au3` 冒烟测试（只读，不改系统） |
| 改系统设置的代码「只看退出码就报成功」 | 外部命令返回 0 只代表**命令被接受**，不代表**状态已生效**。设置类操作（密码策略、电源、远程桌面）必须**回读确认**；`PowerShell` 的 `Set-*` 在缺模块时还会「报错但退出码骗人」 |
| 以为 `Set-LocalUser` / `Get-LocalUser` 在 Win10 上一定有 | 它们属 PowerShell 的 **LocalAccounts 模块**，精简版 / 老版本工控机上**常常没有**，调用报 `CommandNotFoundException`、退出码 1。必须准备回退路径（如 `net accounts /maxpwage:unlimited`） |
| 用 WMI `Win32_UserAccount.PasswordExpires` 判断「密码会不会过期」时把空值当 `False` | AutoIt 里**空值经布尔判断会变成 `False`**，于是「读不出来」被误判成「不会过期」。要用 `IsKeyword($v) = $KEYWORD_NULL` 显式区分；读不出来按「会过期」处理（`$KEYWORD_NULL` 需 `#include <AutoItConstants.au3>`，本项目已在 `Common.au3` 里引入） |
| 最终校验只查「对象是否存在」就报 OK | 前置检查的目的是「能用确定凭据登进去」，账户存在 ≠ 密码不过期。校验必须覆盖**真正关心的那项属性**，否则会出现「…密码会过期」紧跟「[OK] 检查通过」的自相矛盾日志 |
| 把 `StringRegExp(..., 3)` 的返回值当成「带计数的数组」 | flag 3 返回**纯匹配数组（0 基，没有计数元素）**，个数用 `UBound()` 取；`$a[0]` 是第一个匹配值 |
| 在脚本顶层（函数外）用 `Local` 声明变量 | 顶层要用 `Global`，否则 Au3Check 报 `'Local' specifier in global scope` |
| 给 RichEdit 设颜色时「先设色再追加文字」 | 颜色会整体错位一行（`SCF_SELECTION` 作用在光标**前**一个字符）。要**先追加 → 选中新追加的范围 → 再上色** |
| RichEdit 的颜色口径搞错 | 颜色是 **COLORREF(BGR)**，不是 GUI 函数的 RGB（用 `Logger_RgbToColorRef()` 转）。另外 `_GUICtrlRichEdit_GetTextLength()` 的 `$bChars=True` **不是纯字符数** —— 中文每字会多算 1，别拿它当 `SetSel` 的坐标（见下一行） |
| 用 `_GUICtrlRichEdit_GetTextLength()` 算 `SetSel` 的位置（日志串色） | RichEdit 有**三套字符计数**：`GetTextLength($h,True,True)` 中文每字多算 1；`StringLen(GetText)` 把 `@CRLF` 当 2；而 `SetSel`/`GetSel` 的内部坐标把 `@CRLF` 当 1。混用会逐行累积偏移 →「从某行开始串色」。**别自己算位置**：追加后用 `_GUICtrlRichEdit_GetSel()` 读回末尾，着色区间取 `[上次末尾, 本次末尾)`，全程只用 `SetSel` 那套坐标 |
| 声称「已编译通过」「已实测通过」 | 语法检查只能证明语法正确；行为、界面、外部命令参数需在目标机实测 |

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
- 明确区分「语法检查通过」「静态自检通过」与「实测通过」—— 最后一项需要用户在目标机上做。
- 静默安装参数属于**建议值**，不同渠道/版本的安装包可能不同，必须提示用户实测确认。
