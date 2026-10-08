# 开发规范

> 本文面向修改本项目的开发者：架构怎么分层、怎么新增一个软件、脚本与常量怎么写。
> 使用者请看 [`usage.md`](usage.md)。

---

## 一、架构总览

```
auto-install.au3                     总入口：解析命令行 → 配置界面 → 保存配置 → 调度执行
        │
        ├── Include/Constants.au3    全局常量（唯一来源）
        ├── Include/Common.au3       通用工具：权限、路径、环境变量、外部命令
        ├── Include/Logger.au3       日志（文件 + 界面；界面按级别着色）
        ├── Include/Config.au3       配置模块入口（Load / Save）
        ├── Include/Config/          配置模块按配置域拆分
        │     ├── Shared.au3         共享底座：全局状态 + 通用小工具
        │     ├── General.au3        通用配置项：安装根目录 / 资源拷贝 / 开机账户
        │     ├── Packages.au3       安装包目录 + 软件列表（扫描 / 访问器 / 勾选）
        │     └── Group.au3          软件分组（键 / 顺序 / 显示名）+「必须安装」
        ├── Include/Installer.au3    安装调度 + 通用安装流程 + 安装辅助（含等待心跳）
        ├── Include/Precheck.au3     前置检查入口：Precheck_RunAll()
        ├── Include/Precheck/        前置检查各项（内部按检查项拆分）
        │     ├── Base.au3           共享底座：状态 + 辅助（各子模块各自 include）
        │     ├── System.au3         系统版本与内部版本号
        │     ├── Network.au3        ping 与远程桌面
        │     ├── Power.au3          电源（永不睡眠 / 永不休眠）
        │     ├── Driver.au3         设备驱动异常
        │     └── Account.au3        开机账户
        ├── Include/Gui/             界面层（内部按职责拆分）
        │     ├── ConfigShared.au3   配置界面：控件 ID + 界面状态（共享声明）
        │     ├── Config.au3         配置界面：入口 + 消息循环
        │     ├── ConfigLayout.au3   配置界面：界面构建
        │     ├── ConfigState.au3    配置界面：状态同步 + 校验回写
        │     ├── PackageList.au3    配置界面：软件列表控件
        │     └── Install.au3        执行界面
        └── Include/Install/*.au3    各软件的具体安装脚本（自注册；All.au3 汇总入口）
```

**分层原则**

- `Constants.au3` 无依赖，是常量的唯一来源。
- `Common.au3` / `Logger.au3` 是基础层，不依赖上层模块。
- `Installer.au3` 是业务层，负责把「软件目录」映射到「安装函数」并调度。
- `Precheck.au3` + `Include/Precheck/` 是业务层：安装前置检查。共享的状态与辅助在
  `Precheck/Base.au3`，入口只做汇总，子模块一项检查一个文件；
  复用 `Installer_RunWaitBeat()` 等辅助，不依赖界面层 ——
  由界面层在安装前调用，靠返回值与日志汇报结果。
- `Include/Install/*.au3` 是最外层的具体实现，只关心单个软件怎么装。
- `Include/Gui/` 是界面层，只负责界面与交互，不写安装逻辑；
  内部再按「共享声明 / 入口 / 布局 / 状态 / 列表控件」拆开，避免单文件过长。

### 运行流程

1. `Main()` 解析命令行，`Config_Init()` 初始化配置对象。
2. 配置界面模式：`Config_Load()` → `GuiConfig_Show()`；用户点「开始安装」时校验并 `Config_Save()`。
3. `Main_Execute()` 取出勾选项（**0 项也不中止**，只记一条警告日志）→ 初始化日志 → 检查权限（必要时提权重启）。
4. `GuiInstall_Run()` 先调用 `Precheck_RunAll()` 做前置检查（交互模式下发现问题会弹窗确认，
   选「否」则中止、不执行任何安装任务），再调用 `Installer_RunAll()` 逐项执行，
   实时刷新进度、日志与等待心跳。
5. 有失败项（含前置检查中止）时以退出码 `1` 结束。

---

## 二、目录结构

```
auto-install/
├── README.md               # 项目说明（概览）
├── AGENTS.md               # 面向 AI 编码助手的开发约定
├── CLAUDE.md               # 同上（Claude 入口，指向 AGENTS.md）
├── auto-install.au3        # 总入口脚本
├── config.ini              # 运行配置（首次运行自动生成）
├── tools/                  # 辅助脚本
│   ├── check_syntax.py     #   语法检查：调 AutoIt 官方 Au3Check.exe（见第七节）
│   ├── check_au3.py        #   AutoIt 源码静态自检（见第七节）
│   ├── check_docs.py       #   文档与代码一致性检查（见第七节）
│   └── precheck_smoke.au3  #   前置检查只读探针冒烟测试（见第七节）
├── docs/                   # 项目文档
│   ├── usage.md            #   使用说明
│   ├── development.md      #   开发规范（本文件）
│   ├── resource.md         #   参考资料
│   └── packages/           #   各软件的安装说明，与 packages/ 一一对应
│       ├── README.md       #     索引 + 文档模板
│       ├── 7zip.md
│       ├── sqlite3.md
│       ├── sublime-text.md
│       ├── everything.md
│       ├── wps.md
│       ├── hsl-communication-demo.md
│       ├── dbx.md
│       └── halcon.md
├── Include/                # AutoIt 脚本：框架模块
│   ├── Constants.au3       #   全局常量集中管理
│   ├── Common.au3          #   通用工具：权限、路径、环境变量、外部命令执行
│   ├── Logger.au3          #   日志（文件 + 界面；界面按级别着色）
│   ├── Config.au3          #   配置模块入口：Config_Load() / Config_Save()
│   ├── Config/             #   配置模块，按配置域拆分
│   │   ├── Shared.au3      #     共享底座：全局状态 + 通用小工具（各子模块各自 include）
│   │   ├── General.au3     #     通用配置项：安装根目录 / 资源拷贝目录 / 开机账户
│   │   ├── Packages.au3    #     安装包目录 + 软件列表：扫描 / 访问器 / 勾选
│   │   └── Group.au3       #     软件分组：分组键 / 顺序 / 显示名 +「必须安装」
│   ├── Installer.au3       #   安装调度 + 通用安装流程 + 安装辅助（含等待心跳）
│   ├── Precheck.au3        #   前置检查入口：Precheck_RunAll()
│   ├── Precheck/           #   前置检查各项，按检查项拆分
│   │   ├── Base.au3        #     共享底座：状态 + 辅助（各子模块各自 include）
│   │   ├── System.au3      #     1/5 系统版本与内部版本号
│   │   ├── Network.au3     #     2/5 ping 与远程桌面
│   │   ├── Power.au3       #     3/5 电源（永不睡眠 / 永不休眠）
│   │   ├── Driver.au3      #     4/5 设备驱动异常
│   │   └── Account.au3     #     5/5 开机账户
│   ├── Gui/                #   界面层，按职责拆分（见下方说明）
│   │   ├── ConfigShared.au3#     配置界面：控件 ID + 界面状态（共享声明）
│   │   ├── Config.au3      #     配置界面：入口 + 消息循环
│   │   ├── ConfigLayout.au3#     配置界面：界面构建
│   │   ├── ConfigState.au3 #     配置界面：状态同步 + 校验回写
│   │   ├── PackageList.au3 #     配置界面：软件列表控件
│   │   └── Install.au3     #     执行界面
│   └── Install/            #   各软件的具体安装脚本，一个软件一个文件
│       ├── All.au3         #     安装模块汇总：集中 include 下列脚本（新增软件登记在此）
│       ├── 7zip.au3
│       ├── sqlite3.au3
│       ├── sublime-text.au3
│       ├── everything.au3
│       ├── wps.au3
│       ├── hsl-communication-demo.au3
│       ├── dbx.au3
│       └── halcon.au3
└── packages/               # 各软件的安装包 —— 整个目录不入库（见 .gitignore）
    ├── 7zip/               # 每个目录下：安装包 + package.ini（显示名 / 分组 / 必须安装）
    ├── SQLite3/            # 克隆仓库后需自行创建本目录，或在配置界面指向别处
    ├── Sublime Text/
    ├── everything/
    ├── wps/
    ├── HslCommunicationDemo/
    ├── DBX/
    └── halcon/             # 主安装包 + 补丁 DLL 目录（halcon 18 x64/）
```

> 根目录另有 `.gitignore`：安装包目录、`config.ini`、编译产物、日志、编辑器与系统垃圾文件均不入库。
> 详细说明见 `.gitignore` 内的注释。

### 各目录职责

| 目录 | 用途 | 说明 |
| --- | --- | --- |
| `auto-install.au3` | 总入口 | 提供配置界面，读取/保存 `config.ini`，按勾选项调度安装任务 |
| `config.ini` | 运行配置 | 记录软件名称、安装根目录、安装包目录、拷贝源/目标目录、各软件是否勾选；首次运行自动生成 |
| `docs/` | 项目文档 | 使用说明、开发规范、参考资料 |
| `docs/packages/` | 软件安装说明 | 与安装包目录一一对应，每个软件一份，记录版本、安装包、静默参数、安装路径等 |
| `Include/` | 框架脚本 | 可复用的 `.au3` 函数库，统一封装安装、解压、日志等通用逻辑 |
| `Include/Gui/` | 界面层 | 配置界面与执行界面，按「入口 / 布局 / 状态 / 列表控件」拆成多个文件 |
| `Include/Install/` | 各软件安装脚本 | 一个软件一个 `.au3`，通过 `Installer_Register()` 自注册；`All.au3` 是集中 include 它们的汇总入口 |
| `packages/` | 软件安装包（默认位置） | 按「软件名」建子目录，目录内放安装包 + `package.ini`（显示名 / 分组 / 必须安装）。**目录可配置、可指向仓库之外，且整个目录不入库** |

### 框架模块职责

| 模块 | 职责 | 主要对外函数 |
| --- | --- | --- |
| `Constants.au3` | 全局常量 | —（只声明常量） |
| `Common.au3` | 无业务的基础工具 | `Common_RunWait()`、`Common_JoinPath()`、`Common_IsElevated()`、`Common_Which()`、`Common_Find7Zip()` |
| `Logger.au3` | 日志双写（文件 + 界面）；**界面按级别着色**（RichEdit） | `Logger_Init()`、`Logger_SetConsole()`、`Logger_Info()`、`Logger_Warn()`、`Logger_Err()`、`Logger_Ok()`、`Logger_Step()`、`Logger_LevelColor()` |
| `Config.au3` | 配置模块**入口**：只做两件跨配置域的整批操作 | `Config_Load()`、`Config_Save()` |
| `Config/Shared.au3` | 配置模块共享底座：全局状态（`$g_*`）与通用小工具 | `Config_Init()`、`Config_File()`、`Config_ParseBool()`、`Config_ArrayFind()`、`Config_ArrayAppendUnique()` |
| `Config/General.au3` | 通用配置项：安装根目录 / 资源拷贝目录 / 开机账户 | `Config_InstallRootReal()`、`Config_CopySourceReal()`、`Config_CopyDestReal()`、`Config_UserName()`、`Config_Password()` |
| `Config/Packages.au3` | 安装包目录 + 软件列表：扫描时一并读出 `package.ini` 的 `Category` / `Required`；**只收已注册安装脚本的目录** | `Config_ScanPackages()`、`Config_RescanPackages()`、`Config_GetSelected()`、`Config_PackageCategory()`、`Config_PackageRequired()`、`Config_PackagesDirReal()` |
| `Config/Group.au3` | 软件分组：键归一化 / 显示顺序 / 中文显示名 +「必须安装」强制勾选 | `Config_BuildGroups()`、`Config_CategoryName()`、`Config_CategoryKey()`、`Config_ApplyRequired()` |
| `Installer.au3` | 注册表、调度、**通用安装流程**、安装辅助（解压 / 写 PATH / 等待心跳） | `Installer_Register()`、`Installer_IsRegistered()`、`Installer_FindFunc()`、`Installer_RunAll()`、`Installer_InstallSilent()`、`Installer_InstallGreen()`、`Installer_RunWaitBeat()`、`Installer_SetWaitNotify()`、`Installer_FindInstalled()`、`Installer_ExtractZip()`、`Installer_AddToSystemPath()` |
| `Precheck.au3` | 前置检查入口：结果汇总与「继续 / 中止」确认 | `Precheck_RunAll()` |
| `Precheck/Base.au3` | 前置检查共享底座：状态（问题列表 / 设备列表 / 家庭版标记）与辅助函数 | `Precheck_AddIssue()`、`Precheck_Capture()`、`Precheck_RunCmd()`、`Precheck_LogBefore()` |
| `Precheck/System.au3` 等 | 前置检查各项：系统版本、ping 与远程桌面、电源、驱动、开机账户 | `PrecheckSystem_Check()`、`PrecheckNetwork_Check()`、`PrecheckPower_Check()`、`PrecheckDriver_Check()`、`PrecheckAccount_Check()` |
| `Gui/ConfigShared.au3` | 配置界面的共享声明：控件 ID 与界面状态（**只声明变量**） | —（无函数） |
| `Gui/Config.au3` | 配置界面入口、消息循环 | `GuiConfig_Show()` |
| `Gui/ConfigLayout.au3` | 配置界面构建（把控件摆出来） | `GuiConfigLayout_CreateHeader()`、`GuiConfigLayout_CreateBasicGroup()`、`GuiConfigLayout_CreatePackageGroup()`、`GuiConfigLayout_CreateBottomBar()` |
| `Gui/ConfigState.au3` | 配置界面状态同步与校验回写 | `GuiConfigState_SyncHint()`、`GuiConfigState_ReloadPackages()`、`GuiConfigState_Apply()` |
| `Gui/PackageList.au3` | 软件列表控件（带复选框的 ListView）；按分组头分组显示，「必须安装」项锁定勾选 | `GuiPackageList_Create()`、`GuiPackageList_Fill()`、`GuiPackageList_WriteToConfig()`、`GuiPackageList_SetAll()`、`GuiPackageList_EnforceRequired()` |
| `Gui/Install.au3` | 执行界面（日志框为 RichEdit，按级别着色） | `GuiInstall_Run()` |

> **`Include/Gui/` 为什么拆成 6 个文件**：一个配置窗口同时要管界面构建、交互、状态同步、
> 配置读写、列表控件，全塞一个文件会到 480 行以上。按职责拆开后每个文件 100~200 行：
> 共享声明只放变量，入口只跑消息循环，布局只管摆控件，状态只管界面与配置对象的搬运，
> 列表控件把 ListView 的细节封起来。
>
> 约定：**控件 ID 与界面状态变量统一在 `Gui/ConfigShared.au3` 里声明**，
> 同目录其他文件各自 `#include "ConfigShared.au3"` 引入，不要各自再声明一份。

> **`Include/Precheck/` 为什么拆开**：5 项检查彼此独立，各自还带一批命令封装与输出解析，
> 全放一个文件会到 550 行以上。拆法同 `Gui/`：共享的状态与辅助抽到 `Precheck/Base.au3`，
> `Precheck.au3` 只做入口（`#include` 各子模块 + `Precheck_RunAll()`）；
> 各子模块用各自的前缀（`PrecheckSystem_` / `PrecheckNetwork_` / `PrecheckPower_` /
> `PrecheckDriver_` / `PrecheckAccount_`），并**各自 `#include "Base.au3"`**。

> **`Include/Config/` 为什么拆开**：配置模块原本是单个 `Config.au3`（550 行以上），
> 把「通用配置项」「安装包扫描」「分组」混在一起。按**配置域**拆成 4 个子模块后
> 每个文件 100~200 行，改哪块容易找。分层是
> `Shared`（底座，只依赖 `Constants` / `Common`）→ `General` / `Group` → `Packages`
> → `Config`（入口），**基础层不反过来依赖上层**。
>
> 子模块的函数**沿用 `Config_` 前缀**，而不是各起一个前缀 —— 与 `Gui/` / `Precheck/`
> 的拆法不同。原因是这些函数是配置模块**对外**的 API（`Gui/`、`Installer.au3`、
> 总入口都在调），拆文件不该顺带改调用方。各文件头部都写明了自己负责哪一段函数。
>
> **踩过的坑**：`Config_DefaultRoot()`（默认安装根目录算法）一度放在 `General.au3`，
> 但 `Config_Init()`（在 `Shared.au3`）要调它 —— 整体编译没问题，
> **单文件 Au3Check 直接报 `undefined function`**（`check_syntax.py` 第 3 项会逐个核对）。
> 已下沉到 `Shared.au3`。结论同上面三处：**共享的东西必须抽到各自最底层那个文件**。

> **共享声明为什么要单独成文件**：放在「父文件」里整体编译是能过的（编译时父文件先声明了），
> 但在 SciTE 里逐个浏览子模块就是一片红字 ——
> `Foo_Bar(): undefined function` / `$g_x: undeclared global variable`。
> 抽成独立文件、由需要它的每个文件自己 `#include`，两个问题一起解决。
> `python tools/check_syntax.py` 的第 3 项会逐个文件跑 Au3Check 核对这一点。

---

## 三、新增一个软件

### 1. 放入安装包

在**安装包目录**（默认 `packages/`，可在配置界面改，见 `Config_PackagesDirReal()`）下
新建以**软件名**命名的目录，放入安装包（优先使用官方原版），并在同目录放一份 `package.ini`：

```ini
[Package]
DisplayName=WPS Office
Category=office
Required=0
```

- `DisplayName`：配置界面里的显示名，省略则用目录名。
- `Category`：分组键，取值见 `Include/Constants.au3` 的 `$PKG_CAT_ORDER`
  （`required` / `base` / `dev` / `debug` / `vision` / `office` / `misc`），省略归入「未分组」（`misc`）。
  换了分组想让它排到别处，就改 `$PKG_CAT_ORDER` 里的顺序。
- `Required`：`1` 表示**必须安装** —— 固定归入「必须安装」组、排在最前，且界面与 `config.ini`
  都**取消不掉**它的勾选（保证出厂必装项漏不了）。省略按 `0`。

> **⚠️ 光把包放进目录还不够 —— 必须在第 2 步用 `Installer_Register()` 注册该目录名，**
> **软件才会出现在配置界面的软件列表里。** `Config_ScanPackages()` 只收「已适配」的目录
> （见下文「软件列表的过滤规则」），目录名与注册名**必须完全一致**（含大小写）。

> **⚠️ `package.ini` 必须保持 ASCII、不要带 BOM。** AutoIt 的 `IniRead` 按 **ANSI 代码页**
> 读无 BOM 的文件：中文值存 UTF-8 会读成乱码，存 UTF-8 **带 BOM** 则连 `[Package]` 段都读不到。
> 中文分组名统一放在 `Include/Config/Group.au3` 的 `Config_CategoryName()` 里映射，
> ini 里只写 ASCII 键值。文件里的中文**注释**不受影响（注释在 `;` 之后，不参与解析）。

> **整个安装包目录都不纳入版本管理**（见根目录 `.gitignore`）：安装包体积过大，
> 而且该目录本身可配置、可以放在仓库之外。所以安装包与 `package.ini` 都跟随安装包一起管理，
> 不随仓库分发 —— 克隆仓库后需自行创建该目录，或在配置界面把「安装包目录」指到别处。

### 2. 编写安装脚本

在 `Include/Install/` 下新建 `<软件名>.au3`（建议与 `docs/packages/*.md` 同名）。可参考两个范例：

- [`Install/7zip.au3`](../Include/Install/7zip.au3) —— **静默安装**类（NSIS / Inno Setup）
- [`Install/sqlite3.au3`](../Include/Install/sqlite3.au3) —— **绿色解压**类（zip 解压 + 可选写 PATH）

**静默安装类**骨架 —— 只声明常量 + 填参数，逻辑全在通用流程里：

```autoit
#include-once

#include "..\Constants.au3"
#include "..\Common.au3"
#include "..\Logger.au3"
#include "..\Config.au3"
#include "..\Installer.au3"

; ---- 本软件相关常量（前缀取软件名）----
Global Const $XXX_DIR     = "安装包目录下的软件目录名"
Global Const $XXX_SETUP   = "安装包文件名"
Global Const $XXX_SILENT  = $SILENT_NSIS        ; 或 $SILENT_INNO
Global Const $XXX_INSTDIR = "Program Files 下的目录名"
Global Const $XXX_MAINEXE = "主程序.exe"         ; 用于结果校验与 PATH 查找

Installer_Register($XXX_DIR, "Install_XXX")     ; 自注册，目录名须与安装包目录下完全一致

Func Install_XXX($sInstallRoot)
    #forceref $sInstallRoot      ; 装到 Program Files 时用不到自定义根目录

    ; Installer_InstallSilent(显示名, 安装包, 静默参数, 主程序名, 预期安装路径[, 超时])
    Return Installer_InstallSilent( _
            "XXX 显示名", _
            Installer_PackagePath($XXX_DIR, $XXX_SETUP), _
            $XXX_SILENT, _
            $XXX_MAINEXE, _
            Installer_ProgramFilesPath($XXX_INSTDIR, $XXX_MAINEXE))
EndFunc
```

**绿色解压类**骨架（参考 [`Install/sqlite3.au3`](../Include/Install/sqlite3.au3)）：

```autoit
Func Install_XXX($sInstallRoot)
    Local $sDest = Common_JoinPath($sInstallRoot, "XXX")   ; 解压到 <安装根目录>\XXX

    ; Installer_InstallGreen(显示名, 压缩包, 解压目标目录, 主程序名)
    Local $sFound = Installer_InstallGreen( _
            "XXX 显示名", _
            Installer_PackagePath($XXX_DIR, $XXX_ZIP), _
            $sDest, _
            $XXX_MAINEXE)
    If $sFound = "" Then Return False

    ; 需要命令可全局调用时，再写系统 PATH
    Return Installer_AddToSystemPath($sDest)
EndFunc
```

> **不要在安装脚本里重复实现「已安装检测 / 执行 / 超时 / 结果校验 / 日志」**——
> 这些都统一在 `Installer_InstallSilent()` 与 `Installer_InstallGreen()` 内完成。
> 安装脚本只负责声明常量和填参数，通常 40 行以内。

**第三类：安装包不支持静默安装 —— 自动操作图形向导**

有些安装包**根本没有静默方式**（实测 HALCON 完整版传 `/S` 会弹
「Silent installation is only supported by the runtime installer!」并中止，
官方文档也只把 `/S` 写在 runtime 版下）。这时硬传 `/S` 只会让安装器弹窗等人点确定，
脚本干等到超时、日志看着像卡死。做法是自动操作向导，范例见
[`Install/halcon.au3`](../Include/Install/halcon.au3)：

- `Run()` 起安装程序 → `WinWait()` 等向导窗口；
- 每步用 `ControlGetText($hWin, "", "[ID:1037]")` 读**当前页标题**，按标题分派该页动作
  （勾选/选单/填路径/点 Next），再等标题变化；
- 长耗时阶段（真正的安装）用 `Installer_WaitBegin()` / `Installer_WaitEnd()`
  挂等待心跳，界面不会看着像卡死；
- 遇到**未识别页面**：把整窗控件清单 Dump 进日志（`Wizard_LogControls()`），
  然后**失败退出，绝不乱点**；
- **安装器弹的提示框要主动点掉**：等待期间扫描属于该进程的窗口，点掉 `OK` / `确定` /
  `Yes` / `是`（**绝不点 `No` / `Cancel`**），并把控件清单写日志；
  否则一个「请点确定」的框就能让脚本卡到超时、日志上还看不出原因；
- **「已安装」的判据要挑对**：别用「某个文件在不在」—— 安装**中途**那文件可能就在了
  （实测 HALCON 装到约 40% 时核心 DLL 已经存在）。用安装器**最后一步**才写的登记
  （卸载项 / `InstallLocation`）当凭据；没有登记就按「未完成」处理、重新安装；
- **等待的终点是「安装器进程退出」，不是「主窗口关闭」**：点完 Finish 主窗口会**先关**，
  「是否重启」等询问是之后才弹的**独立窗口**——只盯窗口就会把弹框孤儿化
  （HALCON 真机连踩 2 次：重启询问挂到超时没人点）。等待循环每轮都扫弹框，
  直到 `ProcessExists(pid)` 为假；
- **「要不要重启」是「只点确认类」的例外**：一律点【否】（实测 `否(&N)` 用
  `ControlClick` + `[TEXT:否(&N)]` 有效），绝不点 Yes——无人值守装机不能替人重启；
  找不到「否」就不动、留给人工；
- **安装完成 ≠ 流程结束**：Finish 之前可能还有独立向导页（HALCON 实测有
  License file、Additional 3rd party software 两页，按钮仍是 `&Next`）。
  注意安装进度页的按钮文字也是 `&Next` 但**禁用**——要按「按钮可用 +
  页标题 ≠ Installing」区分，别把进度页当向导页；
- **子进程可能是 WPF 程序**（HALCON 的 VSIX 安装器）：窗口类不是 `#32770`
  （是 `HwndWrapper[...]`）、按钮读不出 Win32 文字——按标题识别放行，
  找不到按钮就用 `WinClose()` 发关闭消息兜底；
- **32 位安装器（NSIS x86）手动安装默认落 `Program Files (x86)`**：
  「已安装检测」候选要把 (x86) 默认位置也列上，否则会把已装的判成未装；
- 控件 ID 由 NSIS 的 InstallOptions 按页分配（1200/1201…），**换安装包版本必须重新核对**；
  注意**页面控件 ID 会和窗口固定控件撞号**（实测 HALCON 许可页有 2 个 `id=1034`），
  这时 `[ID:n]` 会命中错的那个 —— 要按「类名 + 文字」取句柄。

> 「找到窗口/控件就能点」不等于「流程对」：向导的**页顺序、控件 ID、以及某些页的前置条件**
> （例如 HALCON 的许可协议页必须先滚到底、`I accept` 才从禁用变可用）都只能靠
> **真机跑一遍**摸出来。别照着截图猜。

### 3. 登记到安装模块汇总

在 `Include/Install/All.au3` 的「安装模块列表」追加一行：

```autoit
#include "<软件名>.au3"
```

总入口 `auto-install.au3` 只 `#include` 这个汇总文件，**不需要改动**。

> AutoIt 的 `#include` 是**编译期**指令，不接受通配符或变量，做不到「把 `.au3` 放进目录就自动加载」，
> 因此必须有这份显式清单。把它单独抽成 `All.au3`，是为了让总入口保持稳定 ——
> 新增软件只改汇总文件一处。

### 4. 补充文档

在 `docs/packages/` 下新增一份 `<软件名>.md`，按该目录下 `README.md` 的模板填写，
并在 `docs/packages/README.md` 的索引表里登记一行。

### 5. 跑自检

```bash
python tools/check_syntax.py   # 语法（含单文件检查）
python tools/check_au3.py      # 源码（含注册目录名与 packages/ 的一致性核对）
python tools/check_docs.py     # 文档（含 docs/packages/ 索引完整性）
```

三者都通过才算完成。详见第七节。

### 关键约定

| 项 | 约定 |
| --- | --- |
| 注册目录名 | `Installer_Register()` 的第一个参数必须与**安装包目录**下的目录名**完全一致**，否则永远不会被调用 |
| 取安装包路径 | 一律用 `Installer_PackagePath()`，它走的是配置里的安装包目录，不要自己拼 `@ScriptDir\packages` |
| 函数签名 | `Func Install_XXX($sInstallRoot)`，成功返回 `True`，失败返回 `False` |
| **禁止重复实现流程** | 「已安装检测 / 执行 / 超时 / 结果校验 / 日志」一律走 `Installer_InstallSilent()` 或 `Installer_InstallGreen()`，安装脚本里只填参数。**安装包确实不支持静默时**（先查打包工具与官方文档，别猜）才改走 GUI 自动化，做法见上文「第三类」 |
| **静默安装可行性** | 传 `/S` 之前先确认它真的支持：看 PE 资源里的打包工具（`7z l` 可见 `Built using NSIS xx`）并查官方文档。不支持时安装器会弹窗等人点确定，脚本等到超时、日志像卡死 —— 这是「假死」，不是慢 |
| 安装根目录 | 安装包类软件装到各自的官方默认路径（多数在 Program Files，也有落在用户目录的，如 DBX）；**绿色软件**才解压到 `$sInstallRoot` |
| 幂等性 | 通用流程已保证：已安装时直接返回 `True`，不会重复安装 |
| 已安装检测 | 通用流程内部用 `Installer_FindInstalled()`：先查预期路径、**再查整个系统 PATH** —— 软件可能装在别的盘，或绿色版已经挂在 PATH 上。**但多个版本并存的软件必须关掉 PATH 兜底**（传 `$bSearchPath = False`），否则会认错版本 |
| **多版本并存** | 同一机器上可能装着同一软件的多个版本（如 HALCON 18.11 与 26.05）。此时 **`PATH`、`%XXXROOT%` 这类全局线索都不可信** —— 它们指向的往往是「最后装的那个版本」。预期路径必须**带版本字样**（如 `HALCON-18.11-Progress`），并且在做破坏性操作（覆盖 / 删除）前**再复核一次目标版本**（目录名 + 文件版本资源） |
| 结果校验 | 通用流程内部做：不只看退出码，还会再确认主程序能找到 |
| 找依赖工具 | 同样要覆盖 PATH。**凡是「定位某个外部程序」的逻辑，一律「常见位置 → 系统 PATH」两级查找**，只查固定目录会漏判（参考 `Common_Find7Zip()`） |
| 显示名 / 分组 / 必须安装 | 都写在 `package.ini` 里（见本节第 1 步），界面只读不写；安装脚本不参与 |
| 分组顺序 | 由 `$PKG_CAT_ORDER` 决定：「必须安装」固定第一、「未适配」固定最后，其余按表内先后，表里没有的分组接在最后（按扫描顺序） |
| 执行顺序 | 由安装包目录的扫描顺序（目录名排序）决定，与 `#include` 的先后无关；与列表里的分组显示顺序无关 |

> 未写安装脚本的软件**不会报错中断**，只会在日志中标记为「跳过」，并提示需要补充的模块名。

### 软件列表的过滤规则

`Config_ScanPackages()` 扫描**安装包目录**时**不是列出全部子目录** —— 只保留「已适配」的：

- **已适配** = `Installer_IsRegistered($sFolder)` 为真，即 `Include/Install/` 下已有模块调用
  `Installer_Register()` 注册了该目录名。这些目录照常显示、可勾选、可安装。
- **未适配**（目录在、但没接安装脚本）**默认直接忽略**，不进软件列表 —— 免得列出一堆点了也装不了的东西。
  排障时把 `config.ini` 的 `[General] ShowUnsupported` 设成 `1`，它们会以
  「显示名 (未适配)」出现在最后的「未适配（暂无安装脚本）」组（键 `$PKG_CAT_UNSUPPORTED`）里，
  **固定不勾选**、不参与全选 / 反选，也不会被写进 `config.ini` 的 `[Packages]` 段。

> 注意 `Config\Packages.au3` 为此 `#include` 了 `..\Installer.au3`，
> 而 `Installer.au3` 又 `#include` 了 `Config.au3` —— 二者靠 `#include-once` 打住，
> 不会死循环（生成期只执行一次 `Installer_Register()` 调用，注册表在界面加载前就已就绪）。

---

## 四、新增一类操作

对于非安装的重复性操作（系统设置、文件拷贝、环境配置、清理等）：

1. 在 `Include/` 下封装为独立函数，命名以 `Action_` 开头（如 `Action_CleanTemp()`）；
2. 若会被多个软件复用，放进 `Installer.au3` 或新建独立模块；
3. 在 `docs/` 中记录其用途、执行时机与前置条件。

**整批执行的操作**（在装任何软件之前 / 之后统一做一遍）适合单独建一个模块，
参考 [`Precheck.au3`](../Include/Precheck.au3) 与 `Include/Precheck/`：头文件放入口、共享状态与
辅助函数，子模块一项操作一个文件；对外只暴露 `Precheck_RunAll()`，由界面层在执行安装前调用，
结果写日志、必要时弹窗确认。需要「整批前置 / 后置操作」时按同样的方式新增模块，
不要在 `Installer_RunAll()` 里堆代码。

---

## 五、脚本封装约定

- `Include/` 中的脚本以 **函数库** 形式组织，一个软件或一类功能对应一个 `.au3` 文件。
- 函数命名：安装类 `Install_`，操作类 `Action_`，工具类按功能命名。
  模块内部函数统一加模块名前缀（`Common_` / `Logger_` / `Config_` / `Installer_` /
  `GuiConfig_` / `GuiConfigLayout_` / `GuiConfigState_` / `GuiPackageList_` / `GuiInstall_`）。
- 所有脚本应包含**错误处理与日志输出**，便于批量执行时定位问题。
- 静默安装参数尽量使用官方推荐方式，避免弹窗打断自动化流程。
- 每个 `.au3` 顶部写 `#include-once`，并显式 `#include` 自己用到的模块。

### 现成的通用流程与辅助函数

**通用安装流程** —— 安装脚本主要就用这两个，**不要自己重写流程**：

| 函数 | 用途 |
| --- | --- |
| `Installer_InstallSilent($sDisplay, $sSetup, $sArgs, $sExeName, $vExpected, $iTimeoutMs, $bSearchPath)` | **静默安装全流程**：安装包存在性 → 已安装检测 → 执行安装 → 超时处理 → 结果校验 → 日志。返回 `True` / `False`。`$bSearchPath` 见下 |
| `Installer_InstallGreen($sDisplay, $sZip, $sDest, $sExeName)` | **绿色解压全流程**：已安装检测 → 解压 → 结果校验 → 日志。成功返回主程序完整路径，失败返回 `""` |
| `Installer_RunCopy()` | **资源拷贝**：把「拷贝源目录」整体拷到「拷贝目标目录」下的同名子目录（robocopy `/E`，覆盖式）。未配置源目录时直接返回 `True` |

**底层工具** —— 需要时再单独调用：

| 函数 | 用途 |
| --- | --- |
| `Common_RunWait($sCmd, $sWorkDir, $iTimeoutMs)` | 执行外部命令并等待，**等待期间界面不假死**；返回退出码，失败返回 `$RUN_ERR_START` / `$RUN_ERR_TIMEOUT`。**通常不直接用，改用下面的 `Installer_RunWaitBeat()`** |
| `Installer_RunWaitBeat($sLabel, $sCmd, $sWorkDir, $iTimeoutMs)` | 同 `Common_RunWait()`，额外**持续输出等待心跳**（界面每秒刷新「已等待 X 分 Y 秒」+ 定期写日志）。安装 / 解压 / 拷贝都走它，避免长时间无输出被误认为卡死 |
| `Installer_ExtractZip($sZip, $sDest)` | 解压 zip，自动在 7-Zip 命令行与 PowerShell `Expand-Archive` 之间回退 |
| `Installer_AddToSystemPath($sDir)` | 把目录写入系统 PATH（去重 + 广播 `WM_SETTINGCHANGE`） |
| `Installer_FindInstalled($vExpected, $sExeName, $bSearchPath)` | 已安装检测：先查预期路径（字符串或候选数组），再查整个系统 PATH。`$bSearchPath` 默认 `True`；**同一机器上装了多个版本时必须传 `False`**，否则 PATH / `%XXXROOT%` 指向的**别的版本**会被当成目标 |
| `Common_Find7Zip()` | 定位解压用的 7-Zip：常见安装位置 → 整个系统 PATH |
| `Common_ResolvePath($sPath, $sBase)` | 解析路径：绝对路径（盘符 / UNC）原样返回，相对路径拼到 `$sBase` 下 |
| `Common_FileName($sPath)` | 取路径的最后一段（文件名或文件夹名） |
| `Common_FormatDuration($iSeconds)` | 把秒数格式化成易读时长，如 `95` → `1 分 35 秒`（等待心跳等提示用） |
| `Installer_PackagePath($sSubDir, $sFile)` | 拼出 `<安装包目录>\<目录>\<文件>` 完整路径（走配置，不写死默认目录） |
| `Installer_ProgramFilesPath($sSubDir, $sFile)` | 拼出 `Program Files\<目录>\<文件>` 完整路径 |
| `Common_Which($sExeName)` | 在系统 PATH 中查找可执行文件（类似 `where`），返回完整路径或空串 |

> **等待心跳**：安装 / 解压 / 拷贝执行外部命令时统一走 `Installer_RunWaitBeat()`，
> 它在 `Common_RunWait()` 前后挂一个 Adlib 定时器（`Installer_WaitTick()`）：
> 每 `$RUN_HEARTBEAT_MS` 回调界面刷新「已等待 X 分 Y 秒」，每 `$RUN_HEARTBEAT_LOG_SEC`
> 秒写一条日志。界面回调由 `Installer_SetWaitNotify()` 注册（GUI 层实现为 `GuiInstall_OnWaitTick()`）。
> 原理是 AutoIt 的 `Sleep` 期间 Adlib 照常触发 —— 现有的超时强杀也依赖这一点。
>
> 心跳逻辑放在 `Installer.au3` 而非 `Common.au3`：它要写日志，
> 而 `Common.au3` 是基础层，依赖 `Logger.au3` 会形成循环 include（见第八节）。

---

## 六、常量约定

框架级常量**统一放在 `Include/Constants.au3`**，其他脚本通过 `#include "Constants.au3"` 引用，
不要在各自文件里散落硬编码的数字与字符串。

| 前缀 | 用途 | 示例 |
| --- | --- | --- |
| `$APP_` | 应用信息 | `$APP_NAME`、`$APP_COMPANY` |
| `$ENV_` / `$DIR_` / `$FILE_` | 环境变量、目录名、文件名 | `$ENV_INSTALL_BASE`、`$DIR_LOGS`、`$FILE_CONFIG` |
| `$INI_` | 配置文件段名与键名 | `$INI_SEC_GENERAL`、`$INI_KEY_ROOT` |
| `$PKG_` / `$REG_` | 数组列索引；分组键与分组顺序 | `$PKG_COL_ENABLED`、`$PKG_CAT_ORDER`、`$PKG_CAT_REQUIRED`、`$REG_COL_FUNC` |
| `$LOG_` | 日志级别、格式与界面颜色 | `$LOG_LEVEL_WARN`、`$LOG_LEVEL_WIDTH`、`$LOG_COLOR_ERROR` |
| `$RUN_` | 外部命令返回码、超时与等待心跳 | `$RUN_ERR_TIMEOUT`、`$TIMEOUT_INSTALL`、`$RUN_HEARTBEAT_LOG_SEC` |
| `$PRECHK_` | 前置检查（注册表键、防火墙规则名、内置组名等） | `$PRECHK_RDP_KEY`、`$PRECHK_FW_ICMP`、`$PRECHK_ADMIN_GROUP` |
| `$ACCT_` | 开机账户默认值 | `$ACCT_DEF_USER`、`$ACCT_DEF_PASS` |
| `$SILENT_` | 安装器静默参数 | `$SILENT_NSIS`、`$SILENT_INNO` |
| `$MB_` / `$EXIT_` / `$CLI_` / `$MUTEX_` | 消息框、退出码、命令行开关、互斥体 | `$MB_YESNO_WARN`、`$CLI_RUN` |
| `$UI_` | 界面布局、字体、颜色 | `$UI_CFG_W`、`$UI_COLOR_HINT` |

> **例外**：与单个软件强相关的常量（安装包文件名、安装目录名等）留在各自的
> `Include/Install/<软件>.au3` 顶部，前缀取软件名（如 `$ZIP7_`、`$SQLITE_`、`$WPS_`），
> 避免 `Constants.au3` 随软件数量无限膨胀。

---

## 七、提交前自检

项目提供三个自检脚本，**改完代码或文档都要跑**：

```bash
python tools/check_syntax.py  # 语法（调 AutoIt 官方 Au3Check.exe）
python tools/check_au3.py     # 源码
python tools/check_docs.py    # 文档
```

### check_syntax.py —— 语法检查（调官方 Au3Check.exe）

**这是唯一能查出语法错误的检查，不能省。** 本机 AutoIt 装在 `D:\Program Files (x86)\AutoIt3`，
`Au3Check.exe` 就在那里；脚本会自动在 PATH 与各盘 `Program Files*` 下找它。

| # | 检查项 | 说明 |
| --- | --- | --- |
| 1 | 检查覆盖范围 | 从总入口出发递归解析 `#include`，找出没被任何 `#include` 引用、因而不会被检查到的 `.au3` |
| 2 | 整体语法检查 | 对总入口跑 Au3Check，它会自行跟进整条 `#include` 链（等于查了全部源码） |
| 3 | 单文件语法检查 | 对每个 `.au3` 单独跑一次 Au3Check，模拟「在 SciTE 里直接打开这个文件」 |

第 3 项专门防一类退化：**共享声明（常量 / 变量 / 函数）留在「父文件」里**时，
整体编译不报错（编译时父文件先声明了），但单独打开子模块就会报
`Foo_Bar(): undefined function` / `$g_x: undeclared global variable`。
本项目的做法是把共享声明抽成独立文件（`Include/Precheck/Base.au3`、
`Include/Gui/ConfigShared.au3`），由需要它的每个文件自己 `#include`。

- 用的警告档位是 `-w 3 -w 4 -w 5 -w 6`（重复声明变量 / 全局作用域用局部变量 /
  声明未使用的局部变量 / 使用 `Dim`），这几项 Au3Check 默认是关的，当前项目能做到 0 warning。
- 退出码：`0` 通过；`1` 有语法错误或有漏检文件；`2` **没找到 `Au3Check.exe`（不算通过）**。

> 为什么必须单独有这一步：`check_au3.py` / `check_docs.py` 都是**文本级**检查。
> 例如 `@PID`（AutoIt 里没有这个宏，应为 `@AutoItPID`）两个脚本都会放行，
> 只有 Au3Check 会报 `error: undefined macro`。

### check_au3.py —— 源码检查（6 项）

| # | 检查项 | 能抓出的问题 |
| --- | --- | --- |
| 1 | UTF-8 BOM | 生成的 `.au3` 忘了补 BOM（会导致中文乱码） |
| 2 | 块级关键字配对 | `Func`/`EndFunc`、`If`/`EndIf`、`While`/`WEnd` 等漏写（能正确处理行继续符 `_`） |
| 3 | `#include` 引用 | 引用了不存在或已改名的文件 |
| 4/5 | 函数与常量定义 | 调用了未定义的函数、常量名拼写错误 |
| 6 | 安装模块注册 | `Installer_Register()` 的目录名与 `packages/` 实际目录不一致（脚本按**默认**安装包目录核对） |

退出码 0 表示全部通过；`-v` 可额外列出所有已定义的函数与常量。

### check_docs.py —— 文档一致性检查（4 项）

| # | 检查项 | 能抓出的问题 |
| --- | --- | --- |
| 1 | 相对链接 | Markdown 链接指向了不存在或已改名的文件（自动跳过代码块） |
| 2 | 函数名 | 文档里写的项目函数在代码中不存在 |
| 3 | 文件路径 | 反引号引用的仓库内路径不存在 |
| 4 | `docs/packages` 索引 | 新增了软件文档却忘了在索引表登记 |

> 后两个脚本都会跳过模板占位符（`$XXX_*`、`<软件名>`）与外部程序名（`7z.exe`），不会误报。

### precheck_smoke.au3 —— 前置检查只读冒烟测试

`check_syntax.py` / `check_au3.py` / `check_docs.py` 都只能证明「语法对、名字对」，
**证明不了「能读到值」**。前置检查里大量依赖解析外部命令的输出
（`powercfg /query`、`netsh ... show rule`、WMI 查询），这类逻辑必须真跑一遍：

```bash
AutoIt3_x64.exe tools\precheck_smoke.au3
```

它**只调用不改系统的探针函数**（不开启远程桌面、不改防火墙、不改电源计划、不创建账户），
把各探针在这台机器上读到的真实值写进 `%TEMP%\precheck-smoke.txt`：

```
系统版本　：Windows 11（WIN_11）        内部版本号：26300.9457
ping 规则：已存在      RDP 规则：不存在      远程桌面：已开启
睡眠：交流 从不 / 电池 从不
不存在的账户：账户不存在
当前用户 xxx：账户存在（已启用，在 Administrators 组（系统管理员），密码永不过期）
```

> 这不是可选项：曾经因为把 `StringRegExp(..., 3)` 的返回值理解错，
> 电源状态在真机上一直显示「无法读取」，而三项静态检查全部通过。
> **新增或改动任何探针函数后，都要跑一次确认能读到值。**

> **注意**：语法检查通过 ≠ 行为正确。AutoIt API 用法、界面布局、外部命令参数，
> 以及文档里描述性内容是否过时，仍需人工判断或在目标机上实测。

---

## 八、AutoIt 编码注意事项

| 事项 | 说明 |
| --- | --- |
| **文件编码** | `.au3` 源码**必须带 UTF-8 BOM**。否则含中文的字符串字面量在编译后会乱码。 |
| **反斜杠** | AutoIt 字符串里反斜杠**不是转义符**，只有双引号需要写成 `""`。但路径拼接仍统一用 `Common_JoinPath()`，取目录用 `Common_FileDir()`，避免歧义。 |
| **数组长度为 0** | `Local $a[0]` / `ReDim $a[0]` 会报错。返回数组的函数统一保证至少 1 行，实际条数用返回值单独传（见 `Config_GetSelected()`）。 |
| **界面不假死 / 长任务可见** | 等待外部命令统一走 `Installer_RunWaitBeat()` —— 内部 `Common_RunWait()` 用 Adlib 消息泵维持响应，并持续输出等待心跳。AutoIt 的 `Sleep` 期间消息队列仍会被处理、Adlib 照常触发，但 `MsgBox` / `WinWait` 等阻塞函数会暂停 Adlib，不要在等待期间弹窗。 |
| **编译目标** | 编译为 **x64**，否则 `@ProgramFilesDir` 指向 `Program Files (x86)`。 |
| **`StringRegExp` 的 flag 3** | 返回**纯匹配数组（0 基，没有计数元素）**：`$a[0]` 是第一个匹配值，匹配个数要用 `UBound()` 取。别当成「带计数的数组」。 |
| **顶层代码用 `Global`** | 函数之外（脚本顶层）声明变量要用 `Global`；写 `Local` 会报 `'Local' specifier in global scope`。 |
| **解析外部命令输出** | `powercfg` / `netsh` / `wmic` 的输出格式（含本地化文字）只有真跑才知道。改动后跑 `tools\precheck_smoke.au3` 验证。 |
| **RichEdit 着色** | 执行界面的日志框是 RichEdit，用于按级别着色。坑：① 颜色是 **COLORREF(BGR)**，GUI 函数用的才是 RGB（`Logger_RgbToColorRef()` 负责转换）；② 设色必须**先追加 → 选中新追加的范围 → 再上色**，反过来会整体错位一行；③ **千万别用 `_GUICtrlRichEdit_GetTextLength()` 算 `SetSel` 的位置**（详见下一行「RichEdit 字符坐标系」）；`_GUICtrlRichEdit_GetFirstCharPosOnLine()` 的行号是 **1 基**。 |
| **RichEdit 字符坐标系（串色根因）** | RichEdit 有**三套不同的字符计数**，混用就会逐行累积偏移 → 日志「从某一行开始串色」。① `_GUICtrlRichEdit_GetTextLength($h, True, True)`：**中文等宽字符每个多算 1**（实测一行含 3 个中文时报 43，真实 40）；② `StringLen(GetText(...))`：行尾 `@CRLF` 算 **2** 个；③ `SetSel` / `GetSel` 的**内部坐标**：`@CRLF` 算 **1** 个，**只有这套是 SetSel 认的**。正确做法：**不要自己算位置**，追加后用 `_GUICtrlRichEdit_GetSel()` 读回真实末尾（追加后光标在末尾），着色区间取 `[上次末尾, 本次末尾)`，全程只用第 ③ 套坐标。见 `Logger_Write()`。 |
| **静默参数实测** | 不同渠道 / 版本的安装包静默参数可能不同，批量使用前必须在目标系统实测。 |
