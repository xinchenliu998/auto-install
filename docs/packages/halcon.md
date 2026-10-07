# HALCON

## 基本信息

| 项 | 内容 |
| --- | --- |
| 软件名称 | MVTec HALCON（机器视觉软件） |
| 分组 | 机器视觉（`vision`） |
| 版本 | 18.11 Progress（`18.11.0.1`，x64） |
| 安装包 | `packages/halcon/halcon-18.11.0.1-windows.exe`（主安装包）<br>`packages/halcon/halcon 18 x64/`（替换用 DLL：`halcon.dll`、`halconxl.dll`） |
| 安装脚本 | [`Include/Install/halcon.au3`](../../Include/Install/halcon.au3) |
| 安装类型 | **自动操作图形安装向导** + 安装后覆盖补丁 DLL |
| 用途 | 机器视觉算法开发与运行环境 |

## 安装说明

- **这个安装包不支持静默安装。** 实测给 `halcon-18.11.0.1-windows.exe` 传 `/S`，安装器会弹
  「**Silent installation is only supported by the runtime installer!**」然后中止；
  官方安装指南也把 `/S` 只写在「2.2.1.2 Silent Installation **(runtime version only)**」一节下。
  完整版**没有任何静默安装方式**（安装包 NSIS 2.46，脚本块是压缩的，
  静态也挖不出别的开关），所以装机脚本改为**自动操作图形安装向导**，见下节。
- **打包类型**：NSIS 2.46（PE 资源里 `Comments: Built using NSIS 2.46`、
  `ProductVersion: 18.11 Progress`）。
- **默认安装路径**：`C:\Program Files\MVTec\HALCON-18.11-Progress`
  （Progress 版；同版本另有 Steady 分支为 `HALCON-18.11-Steady`）。
  脚本会在向导里把安装位置**明确回填**成这个目录，保证可预期。
- **主程序位置**：DLL 形态，位于 `<安装目录>\bin\x64-win64\halcon.dll`。
- **「已完整安装」怎么判定**：**不能只看 `bin\x64-win64\halcon.dll` 在不在** ——
  实测安装进行到约 40% 时它就已经写进去了。脚本改为读**卸载登记**
  （`HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\MVTec HALCON 18.11 Progress`
  的 `InstallLocation`），那是安装器**最后一步**才写的。只有目录、没有登记时按
  「上次装到一半」处理并重新安装，免得把半残的 HALCON 当成装好了。
- **安装器弹的提示框会被自动点掉**：装到最后写环境变量（`HALCONROOT`、往 `PATH` 追加
  `bin\x64-win64`）时，如果目标机 `PATH` 已经很长，安装器会弹
  「环境变量可能超出最大长度」的警告框**等人点确定** —— 不点就一直卡到 30 分钟超时，
  日志上只看到「仍在进行」。脚本会扫描安装器自己的窗口把**确认类**按钮点掉
  （只点 `OK` / `确定` / `Yes` / `是` / `Close` / `关闭`），并把整窗控件清单写进日志备查。
- **问「要不要重启」的框一律点【否】**：无人值守装机不能替用户重启机器。
  脚本对弹框先判断是不是重启询问（窗口文字含 `restarted` / `reboot` / `重新启动`），
  是就点 `No` / `否` / `Later` / `稍后`，**绝不点 `Yes`**；找不到「否」就不处理、留给人工。
- **组件里的 VS 扩展（Variable Inspect Visual Studio Extension）装不装不管**：
  组件树是安装器**自绘的控件**——标准 TreeView 消息（`TVM_GETCOUNT` / `TVM_GETITEMSTATE`）
  全部无效，勾选状态读不出来、键盘/消息切换也不可靠，**无法安全自动化**。
  按用户决定：不做组件勾选，扩展装成什么样都不处理。装完安装目录的 `misc\` 下会多两个文件：
  `HALCON1811ProgressVariableInspect.vsix`（约 20MB）与 `VSIXBootstrapper.exe`。
- **「VSIX Installer」窗口出现就直接点掉（关闭/取消）**：扩展装完（成败都会）弹的
  VSIX 安装器窗口是**独立的 WPF 程序**——窗口类不是 `#32770`（是 `HwndWrapper[...]`），
  按标题 `VSIX Installer` 识别；WPF 按钮读不出文字，找不到按钮时用 `WinClose()`
  发关闭消息兜底（等同点右上角 X = 取消扩展安装）。点掉它不影响主安装。
- **卸载方式**：控制面板卸载项，或直接跑 `<安装目录>\misc\x86-win32\uninstall.exe`
  （实测卸载器在这个位置，不在安装根目录）。
- **许可证**：本安装包以替换 `bin\x64-win64` 下同名 DLL 的方式完成部署，装机流程中
  不再单独投放 License 文件。

### 安装包目录需要的内容

安装包目录（默认 `packages/halcon/`）下需要同时具备两个来源：

```
packages/halcon/
├── halcon-18.11.0.1-windows.exe     # 主安装包
├── halcon 18 x64/                   # 补丁目录
│   ├── halcon.dll
│   └── halconxl.dll
└── package.ini
```

> 原始素材是 `HALCON 18.rar`，需先解压到**本目录**后再执行安装脚本；
> 脚本不会自动解压 rar（项目里的解压流程只处理 zip）。

## 向导自动化

向导页顺序与每页要做的事（**本安装包实测**，界面固定英文）：

| # | 页面标题 | 页面标题控件 `[ID:1037]` | 脚本动作 |
| --- | --- | --- | --- |
| 1 | Welcome | *(该页没有此控件)* | 直接 Next |
| 2 | License Agreement | `License Agreement` | RichEdit `[ID:1000]` 发 `Ctrl+End` 滚到底 → 等「I accept …」`[ID:1034]` 由禁用变可用 → 点它 → Next |
| 3 | Update Information | `Update Information` | 取消勾选「联网检查维护版本」`[ID:1200]`（出厂环境不联网） |
| 4 | Architecture Selection | `Architecture Selection` | 明确选 **x64** `[ID:1201]` |
| 5 | Choose Components | `Choose Components` | **用安装器默认组件，只把下拉框与占用空间记进日志**，不修改 |
| 6 | Additional Information | `Additional Information` | 无操作，Next |
| 7 | Additional Drivers | `Additional Drivers` | GigE 滤镜驱动 `[ID:1200]`，由 `$HALCON_GIGE_FILTER` 决定 |
| 8 | Documentation Language | `Documentation Language` | 选英文文档 `[ID:1200]` |
| 9 | Choose Install Location | `Choose Install Location` | 回填目标目录 `[ID:1019]` → 点 `[ID:1]`（此时按钮文字是 `&Install`） |
| 10 | License file | `License file` | **安装完成后出现**。「Do not install a license file.」`[ID:1205]` 默认已选中（`BM_GETCHECK=1`），核对后 Next；万一默认选的是「安装许可文件」，点回「不安装」——**绝不替用户装许可**。该页 Back 是禁用的 |
| 11 | Additional 3rd party software | `Additional 3rd party software` | 按钮直接是 `&Finish` → 点掉；点之前把文字含 `eadme` 的复选框取消勾选（否则装完会自动用浏览器打开 Readme 网页） |
| — | 安装进度 / 收尾 | — | 挂等待心跳；期间**持续扫描并点掉安装器弹出的提示框**；安装完成后的向导页（10/11）也在这段处理；等 `[ID:1]` 变成 `Finish`/`Close` 再点掉 |
| — | 收尾弹框 | — | Finish 之后弹「是否重启」询问（标题仍是 `HALCON Setup`，按钮 `是(&Y)`/`否(&N)`）—— **一律点【否】**，绝不点 `Yes` |
| — | 安装后处理 | — | 组件里的 VS 扩展装不装不管（见「注意事项」）；随后覆盖补丁 DLL |

> **控件 ID 是换版本时最容易失效的东西。** 向导用 NSIS 的 InstallOptions 插件，
> ID 按页递增分配（1200/1201/1202…）。换安装包版本后**必须重新核对**：
> 脚本每一步都会把当前页标题写进日志，遇到**未识别页面**会把整窗控件清单 Dump 出来
> （`Wizard_LogControls()`），照着日志改 ID 即可。
>
> 静态也挖不出开关：`grep -a "only supported by the runtime" 安装包.exe` 无命中，
> `7z x "[NSIS].nsi"` 导出 0 个文件（只有 payload 的 `$_97_\*`）——
> 说明 NSIS 脚本块是压缩的，**想看开关只能在真机上试**。

## 脚本实现

| 项 | 值 |
| --- | --- |
| 脚本常量 | `$HALCON_DIR` / `$HALCON_SETUP` / `$HALCON_PATCHDIR` / `$HALCON_BIN` / `$HALCON_ARCH` / `$HALCON_MAINEXE` / `$HALCON_VERKEY` / `$HALCON_VERNUM` / `$HALCON_EDITION` / `$HALCON_GIGE_FILTER` / `$HALCON_DLG_TITLES` / `$HALCON_WINTITLE` / `$HALCON_WIZ_FIRST_MS` / `$HALCON_WIZ_STEP_MS` / `$HALCON_TIMEOUT` / `$HALCON_MAXPAGE` / `$HALCON_ID_*` |
| 安装位置 | `C:\Program Files\MVTec\HALCON-18.11-Progress`（向导里回填）。已安装检测候选另含 Steady、旧式布局、**32 位安装器默认落点 `Program Files (x86)`**（人工装的机器会落在那，详见「版本隔离」） |
| 安装方式 | `Halcon_RunWizard()` 自动操作向导；**不用** `Installer_InstallSilent()`（该安装包不支持 `/S`） |
| 已安装判定 | `Halcon_IsInstalled()`：读卸载登记 `InstallLocation`（安装器最后一步才写），**不用**「某个文件在不在」 |
| 等待心跳 | 向导操作阶段每页都会写日志；**安装阶段**用 `Installer_WaitBegin()` / `Installer_WaitEnd()` 挂等待心跳（界面每秒刷新「已等待」，每 10 秒写一条日志） |
| 弹框处理 | 向导页与安装阶段都会调 `Halcon_DismissDialogs()`，按 PID（或标题含 HALCON 的 `#32770` 对话框）识别安装器的提示框并点掉确认按钮 |
| 结果校验 | 安装：卸载登记存在 + `<安装目录>\bin\x64-win64` 存在；覆盖：逐个核对补丁文件大小与源文件一致 |
| 覆盖方式 | `FileCopy($src, $dst, 1)`（强制覆盖，逐个文件）。**不用 robocopy**：robocopy 会跳过「大小与时间戳都相同」的目标文件（实测加 `/IS` 也照样跳过），补丁 DLL 与安装程序释放的原文件完全可能满足该条件，那就会「装完补丁却没生效」 |
| 版本复核 | `Halcon_VerifyTarget()`：覆盖前必须过两道关（见下），不过就**一个文件都不动** |
| 维护开关 | `$g_bHalconWizDryRun = True`（Global，供维护/测试脚本在运行时置位）：只把向导走到安装页就 Cancel，**不装任何文件**，用于换版本后核对页顺序与控件 ID |
| 超时 | 等首个向导窗口 5 分钟；单页等待 3 分钟；安装阶段 `$TIMEOUT_INSTALL_LONG`（30 分钟） |

### 版本隔离（重要）

**同一台机器上可能并存多个 HALCON 版本，而补丁 DLL 只能覆盖到 18.11 上。**
曾经因为只判断「能不能找到 `halcon.dll`」，把 18 的补丁 DLL 覆盖到了
另一台机器上的 `HALCON-26.05-Progress\bin\x64-win64`，**直接破坏了那个版本的安装**。
现在做了三道防护：

| # | 防线 | 做法 |
| --- | --- | --- |
| 1 | 候选路径带版本字样 | `Halcon_ExpectedDlls()` 只列含 `HALCON-18.11` 的目录；`%HALCONROOT%` 由 `Halcon_EnvRoot()` 做版本校验，**不是 18.11 的目录直接丢弃** |
| 2 | 不查 PATH | `Installer_FindInstalled()` 传 `$bSearchPath = False`，避免别的版本的 `bin` 目录挂在 PATH 上被误判 |
| 3 | 覆盖前复核 | `Halcon_VerifyTarget()`：① 目标目录路径必须含 `HALCON-18.11`；② 目标 `halcon.dll` 的版本资源必须以 `18.11` 开头 |

> **版本资源是最硬的一手**：实测 `HALCON-26.05-Progress` 的 `halcon.dll` 版本号是
> `26.5.0.0`，18.11 的是 `18.11.0.1`，区分得非常干净。读不到版本资源时只告警不拦截
> （① 那道已经挡住了「跑到别的版本目录」）。
> 原则：**宁可报错不装，也绝不把补丁打到别的版本上。**

**预期安装路径的候选**（`Halcon_ExpectedDlls()`，任取第一个命中的）：

1. `%ProgramFiles%\MVTec\HALCON-18.11-Progress`（官方默认，也是向导里回填的目录）
2. `%ProgramFiles%\MVTec\HALCON-18.11-Steady`
3. `%ProgramFiles%\MVTec HALCON-18.11`（早期不带 `MVTec` 子目录的布局）
4. `%ProgramFiles(x86)%\MVTec\HALCON-18.11-Progress`（**32 位安装器的默认位置**：
   本安装包是 32 位 NSIS，手动安装不填目录时默认落在 `(x86)` —— 实测）
5. `%ProgramFiles(x86)%\MVTec\HALCON-18.11-Steady`
6. `%HALCONROOT%` —— **仅在路径含 `HALCON-18.11` 时才采信**，否则丢弃并记一条 WARN

**刻意不查系统 PATH**：装在非默认目录、又不设 `HALCONROOT` 的情况宁可报错，
也不会去猜 —— 把该目录补进 `Halcon_ExpectedDlls()` 的候选列表即可。

## 注意事项

- **装机时画面会被安装向导占用**：这是 GUI 自动化，安装向导窗口会出现在前台，
  界面上的「已等待」计时与自动点击同时进行。**不要在此期间用鼠标去点那个向导窗口**，
  会打乱自动化流程。
- **默认不装 GigE 滤镜驱动**（`$HALCON_GIGE_FILTER = False`）：它是以太网过滤驱动，
  安装瞬间会**短暂断网**（安装器自己的警告），无人值守装机时风险大。
  需要用 GigE Vision 工业相机时把该常量改成 `True`。
- **组件页用的是安装器默认组件**（实测约 2.1GB）：脚本只把「安装类型下拉框」与
  「Space required」记进日志，不做修改。**首次部署请人工跑一遍**，确认默认组件符合出厂要求；
  要固化别的组合，需要在该页加代码操作组件树 `[ID:1032]`。
- **安装与覆盖都要管理员权限**：目标目录在 `Program Files` 下，
  非管理员运行会在写入阶段失败（主程序本身会提权重启）。
- **覆盖前应关闭 HALCON 相关程序**：`halcon.dll` 被占用时 `FileCopy()` 会失败，
  脚本会报「覆盖失败」并中止（不会留下「以为装好了」的假成功）。
- **补丁目录只取根层文件**：`halcon 18 x64` 下的子目录不会被处理。
  若日后的补丁包带子目录结构，需要同步调整 `Halcon_ApplyPatch()`。
- **日志里出现「拒绝覆盖」时不要慌，那是防护在起作用**：说明脚本找到的目标不是
  HALCON 18.11（版本资源或目录名对不上），此时**一个文件都没动**。
- **安装成功但覆盖失败**时，HALCON 是装上了、补丁没打上；重跑本软件即可
  （第一步会自动跳过安装，只补覆盖）。
- **上次安装被打断过怎么办**：不用手工清目录。脚本靠卸载登记判断「是否装完整」，
  没有登记就重新跑一遍安装；安装器会覆盖式重装（实测重跑正常）。
- **本机 `PATH` 里可能留着已卸载版本的目录**：实测装过 26.05 的机器上，
  `PATH` 里仍有 `...\HALCON-26.05-Progress\bin\x64-win64`（目录已不存在）。
  这类陈旧项不用管，但**正是它曾经让「按 PATH 找 halcon.dll」误判版本**，
  所以脚本一律不查 PATH。
- 更换安装包版本时需同时改：`packages/halcon/` 下的文件、
  `Include/Install/halcon.au3` 顶部的常量（**含 `$HALCON_VERKEY` / `$HALCON_VERNUM` /
  `$HALCON_EDITION` 与全部 `$HALCON_ID_*` 控件 ID**）、以及本文档。
  改完先开 `$g_bHalconWizDryRun` 干跑一遍核对向导页，别直接上真机装。

## 变更记录

| 日期 | 版本 | 说明 |
| --- | --- | --- |
| 2026-10-06 | - | 创建占位文档，待补充 |
| 2026-10-07 | 18.11 Progress | 放入安装包与补丁 DLL，补全安装脚本（静默安装 + 覆盖 `bin\x64-win64`） |
| 2026-10-07 | 18.11 Progress | **修复误覆盖其他版本**：实测因 `%HALCONROOT%` 指向同机上的 HALCON 26.05，补丁被打到了 26.05 上。改为「候选路径带版本字样 + 不查 PATH + 覆盖前复核版本资源」三道防护 |
| 2026-10-07 | 18.11 Progress | **改用向导自动化**：实测完整版安装包传 `/S` 会被拒（只支持 runtime 版），改为自动操作图形向导（9 页，含许可协议滚动、取消联网检查、选 x64、GigE 开关、英文文档、回填安装目录）。真机端到端实测通过（安装 8 分 4 秒，补丁 DLL 与补丁包 md5 一致） |
| 2026-10-07 | 18.11 Progress | 干跑抓出 **`[ID:1034]` 撞号**（许可页的 Static 与「I accept」复选框同 ID，点到了 Static）→ 改用 `Wizard_FindCtrl()` 按类名+文字取句柄。另按用户反馈补两项：**默认不保留 VS 扩展** `misc\*.vsix`；**自动点掉安装器弹的提示框**（环境变量超长警告等）。「已安装」判定改为读**卸载登记**，不再只看 `halcon.dll`（实测装到 40% 该文件就已在） |
| 2026-10-07 | 18.11 Progress | 按「VS 扩展装成什么样都不管」简化：撤掉组件树自动化与 `.vsix` 清理，VSIX Installer 窗口（独立 WPF 程序）出现即点掉；「已安装检测」候选补上 **32 位安装器默认落点 `Program Files (x86)`**。实测发现**安装完成后还有 3 步**：License file 页（默认「不安装许可文件」）、Additional 3rd party software 页（Finish，且会自动用浏览器打开 Readme）、最后弹「是否重启」—— 分别处理为核对默认项后 Next、取消 Readme 勾选再 Finish、**重启一律点【否】** |
| 2026-10-07 | 18.11 Progress | **修复「是否重启」询问没人点**：`Halcon_WaitInstall()` 原来以「主窗口关闭」为结束标志，但点完 Finish 主窗口先关、重启询问是之后才弹的独立窗口——弹框出现时已经没人在扫（真机两次卡住都是这个原因）。改为**以安装器进程退出为终点**，循环持续扫弹框（主窗口关了也扫），「是否重启」由弹框处理的专用分支点【否】 |
