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
        ├── Include/Logger.au3       日志（文件 + 界面）
        ├── Include/Config.au3       配置读写 + 安装包目录扫描
        ├── Include/Installer.au3    安装调度 + 通用安装流程 + 安装辅助（含等待心跳）
        ├── Include/Gui/             界面层（内部按职责拆分）
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
- `Include/Install/*.au3` 是最外层的具体实现，只关心单个软件怎么装。
- `Include/Gui/` 是界面层，只负责界面与交互，不写安装逻辑；
  内部再按「入口 / 布局 / 状态 / 列表控件」拆开，避免单文件过长。

### 运行流程

1. `Main()` 解析命令行，`Config_Init()` 初始化配置对象。
2. 配置界面模式：`Config_Load()` → `GuiConfig_Show()`；用户点「开始安装」时校验并 `Config_Save()`。
3. `Main_Execute()` 取出勾选项 → 初始化日志 → 检查权限（必要时提权重启）。
4. `GuiInstall_Run()` 调用 `Installer_RunAll()` 逐项执行，实时刷新进度、日志与等待心跳。
5. 有失败项时以退出码 `1` 结束。

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
│   ├── check_au3.py        #   AutoIt 源码静态自检（见第七节）
│   └── check_docs.py       #   文档与代码一致性检查（见第七节）
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
│   ├── Logger.au3          #   日志（文件 + 界面）
│   ├── Config.au3          #   配置读写（config.ini）+ 安装包目录扫描
│   ├── Installer.au3       #   安装调度 + 通用安装流程 + 安装辅助（含等待心跳）
│   ├── Gui/                #   界面层，按职责拆分（见下方说明）
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
│       └── dbx.au3
└── packages/               # 各软件的安装包 —— 整个目录不入库（见 .gitignore）
    ├── 7zip/               # 每个目录下：安装包 + package.ini（界面显示名）
    ├── SQLite3/            # 克隆仓库后需自行创建本目录，或在配置界面指向别处
    ├── Sublime Text/
    ├── everything/
    ├── wps/
    ├── HslCommunicationDemo/
    ├── DBX/
    └── halcon/             # 安装包待放入，安装脚本待补
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
| `packages/` | 软件安装包（默认位置） | 按「软件名」建子目录。**目录可配置、可指向仓库之外，且整个目录不入库** |

### 框架模块职责

| 模块 | 职责 | 主要对外函数 |
| --- | --- | --- |
| `Constants.au3` | 全局常量 | —（只声明常量） |
| `Common.au3` | 无业务的基础工具 | `Common_RunWait()`、`Common_JoinPath()`、`Common_IsElevated()`、`Common_Which()`、`Common_Find7Zip()` |
| `Logger.au3` | 日志双写（文件 + 界面） | `Logger_Init()`、`Logger_Info()`、`Logger_Warn()`、`Logger_Err()`、`Logger_Ok()`、`Logger_Step()` |
| `Config.au3` | 配置对象与读写 | `Config_Load()`、`Config_Save()`、`Config_GetSelected()`、`Config_RescanPackages()`、`Config_InstallRootReal()`、`Config_PackagesDirReal()`、`Config_CopySourceReal()`、`Config_CopyDestReal()` |
| `Installer.au3` | 注册表、调度、**通用安装流程**、安装辅助（解压 / 写 PATH / 等待心跳） | `Installer_Register()`、`Installer_RunAll()`、`Installer_InstallSilent()`、`Installer_InstallGreen()`、`Installer_RunWaitBeat()`、`Installer_SetWaitNotify()`、`Installer_FindInstalled()`、`Installer_ExtractZip()`、`Installer_AddToSystemPath()` |
| `Gui/Config.au3` | 配置界面入口、消息循环；控件 ID 与状态在此声明 | `GuiConfig_Show()` |
| `Gui/ConfigLayout.au3` | 配置界面构建（把控件摆出来） | `GuiConfigLayout_CreateHeader()`、`GuiConfigLayout_CreateBasicGroup()`、`GuiConfigLayout_CreatePackageGroup()`、`GuiConfigLayout_CreateBottomBar()` |
| `Gui/ConfigState.au3` | 配置界面状态同步与校验回写 | `GuiConfigState_SyncHint()`、`GuiConfigState_ReloadPackages()`、`GuiConfigState_Apply()` |
| `Gui/PackageList.au3` | 软件列表控件（带复选框的 ListView） | `GuiPackageList_Create()`、`GuiPackageList_Fill()`、`GuiPackageList_WriteToConfig()` |
| `Gui/Install.au3` | 执行界面 | `GuiInstall_Run()` |

> **`Include/Gui/` 为什么拆成 5 个文件**：一个配置窗口同时要管界面构建、交互、状态同步、
> 配置读写、列表控件，全塞一个文件会到 480 行以上。按职责拆开后每个文件 100~200 行：
> 入口只跑消息循环，布局只管摆控件，状态只管界面与配置对象的搬运，
> 列表控件把 ListView 的细节封起来。
>
> 约定：**控件 ID 与界面状态变量统一在 `Gui/Config.au3` 里声明**，同目录其他文件直接使用；
> 子模块通过 `#include` 挂在 `Gui/Config.au3` 里（放在全局声明之后）。

---

## 三、新增一个软件

### 1. 放入安装包

在**安装包目录**（默认 `packages/`，可在配置界面改，见 `Config_PackagesDirReal()`）下
新建以**软件名**命名的目录，放入安装包（优先使用官方原版），并在同目录放一份 `package.ini`：

```ini
[Package]
DisplayName=WPS Office
```

> **整个安装包目录都不纳入版本管理**（见根目录 `.gitignore`）：安装包体积过大，
> 而且该目录本身可配置、可以放在仓库之外。所以安装包与 `package.ini` 都跟随安装包一起管理，
> 不随仓库分发 —— 克隆仓库后需自行创建该目录，或在配置界面把「安装包目录」指到别处。
>
> 内容保持 ASCII，**不要写 BOM**，否则 `IniRead` 可能读不到第一段。

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

### 关键约定

| 项 | 约定 |
| --- | --- |
| 注册目录名 | `Installer_Register()` 的第一个参数必须与**安装包目录**下的目录名**完全一致**，否则永远不会被调用 |
| 取安装包路径 | 一律用 `Installer_PackagePath()`，它走的是配置里的安装包目录，不要自己拼 `@ScriptDir\packages` |
| 函数签名 | `Func Install_XXX($sInstallRoot)`，成功返回 `True`，失败返回 `False` |
| **禁止重复实现流程** | 「已安装检测 / 执行 / 超时 / 结果校验 / 日志」一律走 `Installer_InstallSilent()` 或 `Installer_InstallGreen()`，安装脚本里只填参数 |
| 安装根目录 | 安装包类软件装到各自的官方默认路径（多数在 Program Files，也有落在用户目录的，如 DBX）；**绿色软件**才解压到 `$sInstallRoot` |
| 幂等性 | 通用流程已保证：已安装时直接返回 `True`，不会重复安装 |
| 已安装检测 | 通用流程内部用 `Installer_FindInstalled()`：先查预期路径、**再查整个系统 PATH** —— 软件可能装在别的盘，或绿色版已经挂在 PATH 上 |
| 结果校验 | 通用流程内部做：不只看退出码，还会再确认主程序能找到 |
| 找依赖工具 | 同样要覆盖 PATH。**凡是「定位某个外部程序」的逻辑，一律「常见位置 → 系统 PATH」两级查找**，只查固定目录会漏判（参考 `Common_Find7Zip()`） |
| 执行顺序 | 由安装包目录的扫描顺序（目录名排序）决定，与 `#include` 的先后无关 |

> 未写安装脚本的软件**不会报错中断**，只会在日志中标记为「跳过」，并提示需要补充的模块名。

---

## 四、新增一类操作

对于非安装的重复性操作（系统设置、文件拷贝、环境配置、清理等）：

1. 在 `Include/` 下封装为独立函数，命名以 `Action_` 开头（如 `Action_CleanTemp()`）；
2. 若会被多个软件复用，放进 `Installer.au3` 或新建独立模块；
3. 在 `docs/` 中记录其用途、执行时机与前置条件。

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
| `Installer_InstallSilent($sDisplay, $sSetup, $sArgs, $sExeName, $vExpected, $iTimeoutMs)` | **静默安装全流程**：安装包存在性 → 已安装检测 → 执行安装 → 超时处理 → 结果校验 → 日志。返回 `True` / `False` |
| `Installer_InstallGreen($sDisplay, $sZip, $sDest, $sExeName)` | **绿色解压全流程**：已安装检测 → 解压 → 结果校验 → 日志。成功返回主程序完整路径，失败返回 `""` |
| `Installer_RunCopy()` | **资源拷贝**：把「拷贝源目录」整体拷到「拷贝目标目录」下的同名子目录（robocopy `/E`，覆盖式）。未配置源目录时直接返回 `True` |

**底层工具** —— 需要时再单独调用：

| 函数 | 用途 |
| --- | --- |
| `Common_RunWait($sCmd, $sWorkDir, $iTimeoutMs)` | 执行外部命令并等待，**等待期间界面不假死**；返回退出码，失败返回 `$RUN_ERR_START` / `$RUN_ERR_TIMEOUT`。**通常不直接用，改用下面的 `Installer_RunWaitBeat()`** |
| `Installer_RunWaitBeat($sLabel, $sCmd, $sWorkDir, $iTimeoutMs)` | 同 `Common_RunWait()`，额外**持续输出等待心跳**（界面每秒刷新「已等待 X 分 Y 秒」+ 定期写日志）。安装 / 解压 / 拷贝都走它，避免长时间无输出被误认为卡死 |
| `Installer_ExtractZip($sZip, $sDest)` | 解压 zip，自动在 7-Zip 命令行与 PowerShell `Expand-Archive` 之间回退 |
| `Installer_AddToSystemPath($sDir)` | 把目录写入系统 PATH（去重 + 广播 `WM_SETTINGCHANGE`） |
| `Installer_FindInstalled($vExpected, $sExeName)` | 已安装检测：先查预期路径（字符串或候选数组），再查整个系统 PATH |
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
| `$PKG_` / `$REG_` | 数组列索引 | `$PKG_COL_ENABLED`、`$REG_COL_FUNC` |
| `$LOG_` | 日志级别与格式 | `$LOG_LEVEL_WARN`、`$LOG_LEVEL_WIDTH` |
| `$RUN_` | 外部命令返回码、超时与等待心跳 | `$RUN_ERR_TIMEOUT`、`$TIMEOUT_INSTALL`、`$RUN_HEARTBEAT_LOG_SEC` |
| `$SILENT_` | 安装器静默参数 | `$SILENT_NSIS`、`$SILENT_INNO` |
| `$MB_` / `$EXIT_` / `$CLI_` / `$MUTEX_` | 消息框、退出码、命令行开关、互斥体 | `$MB_YESNO_WARN`、`$CLI_RUN` |
| `$UI_` | 界面布局、字体、颜色 | `$UI_CFG_W`、`$UI_COLOR_HINT` |

> **例外**：与单个软件强相关的常量（安装包文件名、安装目录名等）留在各自的
> `Include/Install/<软件>.au3` 顶部，前缀取软件名（如 `$ZIP7_`、`$SQLITE_`、`$WPS_`），
> 避免 `Constants.au3` 随软件数量无限膨胀。

---

## 七、提交前自检

本机通常没有 AutoIt 环境，无法编译验证，因此项目提供了两个静态自检脚本：

```bash
python tools/check_au3.py     # 源码
python tools/check_docs.py    # 文档
```

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

> 两个脚本都会跳过模板占位符（`$XXX_*`、`<软件名>`）与外部程序名（`7z.exe`），不会误报。

> **注意**：这只是静态检查。语法错误、AutoIt API 用法、界面布局仍需在装有 AutoIt 的机器上
> 编译并实测，两者不能互相替代。

---

## 八、AutoIt 编码注意事项

| 事项 | 说明 |
| --- | --- |
| **文件编码** | `.au3` 源码**必须带 UTF-8 BOM**。否则含中文的字符串字面量在编译后会乱码。 |
| **反斜杠** | AutoIt 字符串里反斜杠**不是转义符**，只有双引号需要写成 `""`。但路径拼接仍统一用 `Common_JoinPath()`，取目录用 `Common_FileDir()`，避免歧义。 |
| **数组长度为 0** | `Local $a[0]` / `ReDim $a[0]` 会报错。返回数组的函数统一保证至少 1 行，实际条数用返回值单独传（见 `Config_GetSelected()`）。 |
| **界面不假死 / 长任务可见** | 等待外部命令统一走 `Installer_RunWaitBeat()` —— 内部 `Common_RunWait()` 用 Adlib 消息泵维持响应，并持续输出等待心跳。AutoIt 的 `Sleep` 期间消息队列仍会被处理、Adlib 照常触发，但 `MsgBox` / `WinWait` 等阻塞函数会暂停 Adlib，不要在等待期间弹窗。 |
| **编译目标** | 编译为 **x64**，否则 `@ProgramFilesDir` 指向 `Program Files (x86)`。 |
| **静默参数实测** | 不同渠道 / 版本的安装包静默参数可能不同，批量使用前必须在目标系统实测。 |
