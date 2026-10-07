; ==============================================================================
; Install\halcon.au3 —— MVTec HALCON 18.11 Progress
; ------------------------------------------------------------------------------
; 安装类型：**自动操作图形安装向导**（该安装包不支持静默安装）+ 覆盖补丁 DLL
; 安装位置：C:\Program Files\MVTec\HALCON-18.11-Progress（官方默认路径）
; 参数依据：docs/packages/halcon.md
;
; 【为什么不是静默安装】
;   完整版安装包 `halcon-18.11.0.1-windows.exe` **不支持 /S**：
;   实测传 /S 会弹出「Silent installation is only supported by the runtime installer!」
;   官方文档也把 /S 只写在「Silent Installation (runtime version only)」一节下。
;   所以这里改用 AutoIt 驱动安装向导（见 Halcon_RunWizard）。
;
; 【向导页顺序（本安装包实测，英文界面固定）】
;   1 Welcome               -> Next
;   2 License Agreement     -> RichEdit[1000] 按 Ctrl+End 滚到底，
;                              等「I accept ...」[1034] 变可用后点它 -> Next
;   3 Update Information    -> 取消勾选「联网检查维护版本」[1200]（出厂环境不联网）
;   4 Architecture Selection-> 选 x64 [1201]
;   5 Choose Components     -> 用默认组件（只记录，不修改；组件树是自绘控件，无法自动化）
;   6 Additional Information-> 纯说明页 -> Next
;   7 Additional Drivers    -> GigE 滤镜驱动 [1200]，由 $HALCON_GIGE_FILTER 决定
;   8 Documentation Language-> 选英文文档 [1200]
;   9 Choose Install Location-> 填目标目录 [1019]，按钮此时是 [1] &Install
;   点 Install 后进入安装进度，完成后**还有安装后向导页**（实测 15:20）：
;   10 License file         -> 「Do not install a license file.」[1205] 默认已选中，
;                              核对后 Next（Back 是禁用的；绝不替用户装许可）
;   11 Additional 3rd party software -> 按钮直接是 [1] &Finish -> 点掉
;                              （Finish 页可能有「打开 Readme」复选框，见勾就点掉）
;   点 Finish 后还弹「是否重启」询问 -> 一律点【否】
;
; 【安装过程中的弹框一律自动点掉】
;   安装期间会弹各种框，都按确认处理（OK / 确定 / Yes / 是 / Close / 关闭）：
;     · 写环境变量时 PATH 太长 -> 「可能超出最大长度」警告框
;     · 组件里的 VS 扩展装完（成败都会）-> VSIX 安装器的提示框
;   **唯一例外**：问「要不要重启」的框一律点【否】—— 无人值守装机不能替用户重启机器。
;   注意 VSIX 安装器是安装器的**子进程**，PID 对不上，只能靠标题关键字认（$HALCON_DLG_TITLES）。
;
; 【版本隔离 —— 只认 18.11，绝不碰别的版本（血泪教训）】
;   同一台机器上可能并存多个 HALCON 版本（实测机器上就有 HALCON-26.05-Progress，
;   而且它的 bin\x64-win64 还挂在系统 PATH 上、HALCONROOT 也指向它）。
;   「找得到 halcon.dll」根本区分不了版本 —— 曾经因此把 18 的补丁 DLL
;   覆盖到了 26.05 的 bin\x64-win64 上，**直接破坏了那个版本的安装**。
;   三层防护：
;     1. 候选路径只列带 $HALCON_VERKEY（HALCON-18.11）字样的目录；
;        HALCONROOT 只在**确实指向 18.11** 时才采信；
;     2. 不查系统 PATH —— Installer_FindInstalled() 传 $bSearchPath = False；
;     3. 覆盖前用 Halcon_VerifyTarget() 复核：目标目录路径必须含 HALCON-18.11，
;        且目标 halcon.dll 的版本资源必须以 18.11 开头。
;   原则：**宁可报错不装，也绝不把补丁打到别的版本上。**
;
; 【控件 ID 的可靠性】
;   向导是 NSIS 2.46 + InstallOptions，控件 ID 由插件按页递增分配（1200/1201…），
;   换安装包版本**必须重新核对**（改完跑一次，日志里每页都会打印，未知页会 Dump 全部控件）。
; ==============================================================================

#include-once

#include "..\Constants.au3"
#include "..\Common.au3"
#include "..\Logger.au3"
#include "..\Config.au3"
#include "..\Installer.au3"

; ------------------------------------------------------------------------------
; 本软件相关常量
; ------------------------------------------------------------------------------
Global Const $HALCON_DIR      = "halcon"                        ; packages 下的目录名
Global Const $HALCON_SETUP    = "halcon-18.11.0.1-windows.exe"  ; 安装包文件名（NSIS 打包，不支持 /S）
Global Const $HALCON_PATCHDIR = "halcon 18 x64"                 ; 安装包内补丁 DLL 所在目录
Global Const $HALCON_BIN      = "bin"                           ; 安装目录下的二进制目录
Global Const $HALCON_ARCH     = "x64-win64"                     ; bin 下的架构目录
Global Const $HALCON_MAINEXE  = "halcon.dll"                    ; 主程序（DLL），用于结果校验与版本校验

; 版本标识 —— 定位安装目录与覆盖前的复核都用它，换版本时改这两行
Global Const $HALCON_VERKEY   = "HALCON-18.11"                  ; 安装目录路径里必须含这个字样
Global Const $HALCON_VERNUM   = "18.11"                         ; DLL 版本资源必须以它开头
Global Const $HALCON_EDITION  = "Progress"                      ; 官方发行分支（另有 Steady）

; 是否勾选「Install MVTec GigE Vision Streaming Filter」。
; 默认 False（不装）：该滤镜是网络过滤驱动，安装瞬间会**短暂断网**，
; 无人值守装机时风险较大；需要用 GigE Vision 工业相机时改成 True 再装。
Global Const $HALCON_GIGE_FILTER = False

; 维护开关：True = **干跑**。只把向导走到「Choose Install Location」页就点 Cancel 退出，
; 一个文件都不装 —— 用于换安装包版本后核对「页顺序 + 控件 ID」是否还对得上。
; 它是 Global（不是 Const），方便维护/测试脚本在运行时置 True 后复用同一套代码路径。
Global $g_bHalconWizDryRun = False

; 安装器进程 PID（Halcon_RunWizard 里设置），用于识别并自动点掉它弹出的提示框
Global $g_iHalconPid = 0

; 弹框识别的标题关键字：VSIX 安装器是安装器的**子进程**（PID 对不上），
; 只能靠标题认。不要加太宽的词，免得点到别人的对话框。
Global Const $HALCON_DLG_TITLES = "(?i)HALCON|VSIX|Visual Studio|MVTec"

; 向导窗口标题（AutoIt 默认「从标题开头匹配」，兼容「HALCON Setup 」带尾空格的变体）
Global Const $HALCON_WINTITLE   = "HALCON Setup"

; 超时：等首个窗口 / 单页等待 / 整个安装阶段
Global Const $HALCON_WIZ_FIRST_MS  = 300000                     ; 5 分钟（1.8GB 自解压较慢）
Global Const $HALCON_WIZ_STEP_MS   = 180000                     ; 3 分钟
Global Const $HALCON_TIMEOUT       = $TIMEOUT_INSTALL_LONG      ; 30 分钟（安装阶段）
Global Const $HALCON_MAXPAGE       = 40                         ; 页数上限，防死循环

; 向导控件（NSIS InstallOptions 分配，见文件头说明）
Global Const $HALCON_ID_NEXT       = "[ID:1]"                   ; Next / Install / Finish
Global Const $HALCON_ID_CANCEL     = "[ID:2]"
Global Const $HALCON_ID_PAGETITLE  = "[ID:1037]"                ; 当前页标题（Welcome 页没有）
Global Const $HALCON_ID_EULA_TEXT  = "[ID:1000]"                ; License 页的 RichEdit20A
; 【注意】License 页有 2 个 id=1034（窗口固定的 Static 标签 + 「I accept」复选框）——
;   别用 [ID:1034] 定位复选框，点到的只会是 Static；要用 Halcon_FindCtrl() 按类名+文字取句柄。
Global Const $HALCON_ID_MAINTCHK   = "[ID:1200]"                ; Update 页：联网检查维护版本
Global Const $HALCON_ID_ARCH_X64   = "[ID:1201]"                ; Architecture 页：x64
Global Const $HALCON_ID_COMBO      = "[ID:1017]"                ; Components 页：安装类型下拉框
Global Const $HALCON_ID_SPACE      = "[ID:1023]"                ; "Space required: 2.1GB"
Global Const $HALCON_ID_GIGE       = "[ID:1200]"                ; Drivers 页：GigE 滤镜
Global Const $HALCON_ID_DOC_EN     = "[ID:1200]"                ; Doc Language 页：英文
Global Const $HALCON_ID_DEST       = "[ID:1019]"                ; Install Location 页：目标目录输入框
Global Const $HALCON_ID_LICENSE_NO = "[ID:1205]"                ; License file 页：Do not install a license file.

Installer_Register($HALCON_DIR, "Install_halcon")

Func Install_halcon($sInstallRoot)
    #forceref $sInstallRoot      ; 装到 HALCON 官方默认目录，不使用自定义根目录

    ; ---- 第 1 步：确保 HALCON 18.11 已经**完整**装好 ----
    ; 不用 Installer_InstallSilent()：它只能跑静默安装，而这个安装包不支持 /S。
    Local $sRoot = Halcon_IsInstalled()
    If $sRoot <> "" Then
        Logger_Info("已检测到完整的 HALCON " & $HALCON_VERNUM & " 安装，跳过安装步骤：" & $sRoot)
    Else
        If Not Halcon_RunWizard() Then Return False
        $sRoot = Halcon_InstallRootDir()
    EndIf

    ; ---- 第 2 步：用随包的补丁 DLL 覆盖 bin\x64-win64 ----
    Local $sBin = Common_JoinPath(Common_JoinPath($sRoot, $HALCON_BIN), $HALCON_ARCH)
    Return Halcon_ApplyPatch($sBin)
EndFunc

; ------------------------------------------------------------------------------
; 读注册表里的卸载登记，返回它登记的安装目录；没有登记返回空串。
;
; 键名形如 `MVTec HALCON 18.11 Progress`（实测），位置：
;   HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\
;   HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\
; 这里按「键名含 HALCON <版本号>」匹配，不写死完整键名，免得随渠道/版本变。
; ------------------------------------------------------------------------------
Func Halcon_UninstallEntry()
    Local $aRoots[2]
    $aRoots[0] = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $aRoots[1] = "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"

    Local $sToken = "HALCON " & $HALCON_VERNUM      ; 键名里是空格，不是 $HALCON_VERKEY 的连字符
    Local $i, $sKey, $sLoc

    For $r = 0 To UBound($aRoots) - 1
        $i = 1
        While True
            $sKey = RegEnumKey($aRoots[$r], $i)
            If @error <> 0 Then ExitLoop

            If StringInStr($sKey, $sToken) > 0 Then
                $sLoc = RegRead($aRoots[$r] & "\" & $sKey, "InstallLocation")
                If Not @error And $sLoc <> "" Then Return $sLoc
            EndIf

            $i += 1
        WEnd
    Next

    Return ""
EndFunc

; ------------------------------------------------------------------------------
; HALCON 18.11 是否**完整**安装？是则返回安装目录，否则返回空串。
;
; 【为什么不能只看 bin\x64-win64\halcon.dll】
;   实测安装进行到约 40% 时该文件就已经存在了。只看它，会把「上次装到一半」
;   的机器判成「已安装」而跳过安装，留下一个半残的 HALCON —— 而且补丁照打，
;   日志上看起来一切正常。
;   安装器是在**最后一步**才写卸载登记的，所以拿它当「装完整了」的凭据。
;
; 只有目录、没有卸载登记时按「未完成」处理：记 WARN 并重新安装（宁可重装，不可半装）。
; ------------------------------------------------------------------------------
Func Halcon_IsInstalled()
    Local $sLoc = Halcon_UninstallEntry()

    If $sLoc = "" Then
        If Installer_FindInstalled(Halcon_ExpectedDlls(), $HALCON_MAINEXE, False) <> "" Then
            Logger_Warn("找到了 " & $HALCON_VERKEY & " 的安装目录，但注册表里没有它的卸载登记：")
            Logger_Warn("  按「上次安装未完成」处理，重新安装（避免把装了一半的 HALCON 当成装好了）")
        EndIf
        Return ""
    EndIf

    If StringInStr($sLoc, $HALCON_VERKEY) = 0 Then
        Logger_Warn("卸载登记指向的目录不含 " & $HALCON_VERKEY & "，忽略这条登记：" & $sLoc)
        Return ""
    EndIf

    If Not FileExists(Common_JoinPath(Common_JoinPath($sLoc, $HALCON_BIN), $HALCON_ARCH)) Then
        Logger_Warn("卸载登记的目录里没有 " & $HALCON_BIN & "\" & $HALCON_ARCH & "，按未完成处理：" & $sLoc)
        Return ""
    EndIf

    Return $sLoc
EndFunc


; ------------------------------------------------------------------------------
; 预期安装位置（<安装目录>\bin\x64-win64\halcon.dll）的候选列表。
;
; 返回值保证至少 1 行 —— AutoIt 不允许长度为 0 的数组；空串项由
; Installer_FindInstalled() 自行跳过。
;
; 只列**版本明确**的位置：官方默认目录（Progress / Steady）与更早的目录布局，
; 以及 **32 位安装器的默认位置** `Program Files (x86)`（本安装包是 32 位 NSIS，
; 手动安装不填目录时默认落在那里 —— 实测）。自定义目录只能靠 HALCONROOT，
; 而它可能指向别的版本 —— 所以先做版本校验，不合格直接丢弃（返回空串），
; 绝不当成候选。
; ------------------------------------------------------------------------------
Func Halcon_ExpectedDlls()
    Local $sPf86 = EnvGet("ProgramFiles(x86)")
    If $sPf86 = "" Then $sPf86 = StringReplace(@ProgramFilesDir, "Program Files", "Program Files (x86)")

    Local $aRoot[6]
    $aRoot[0] = Common_JoinPath(Common_JoinPath(@ProgramFilesDir, "MVTec"), _
            $HALCON_VERKEY & "-" & $HALCON_EDITION)
    $aRoot[1] = Common_JoinPath(Common_JoinPath(@ProgramFilesDir, "MVTec"), _
            $HALCON_VERKEY & "-Steady")
    $aRoot[2] = Common_JoinPath(@ProgramFilesDir, "MVTec " & $HALCON_VERKEY)
    $aRoot[3] = Common_JoinPath(Common_JoinPath($sPf86, "MVTec"), _
            $HALCON_VERKEY & "-" & $HALCON_EDITION)
    $aRoot[4] = Common_JoinPath(Common_JoinPath($sPf86, "MVTec"), _
            $HALCON_VERKEY & "-Steady")
    $aRoot[5] = Halcon_EnvRoot()

    Local $aDll[6]
    For $i = 0 To UBound($aRoot) - 1
        If $aRoot[$i] = "" Then
            $aDll[$i] = ""
        Else
            $aDll[$i] = Common_JoinPath( _
                    Common_JoinPath(Common_JoinPath($aRoot[$i], $HALCON_BIN), $HALCON_ARCH), _
                    $HALCON_MAINEXE)
        EndIf
    Next

    Return $aDll
EndFunc

; 目标安装根目录（与候选列表第 1 项一致），用于在向导里回填「安装位置」。
Func Halcon_InstallRootDir()
    Return Common_JoinPath(Common_JoinPath(@ProgramFilesDir, "MVTec"), _
            $HALCON_VERKEY & "-" & $HALCON_EDITION)
EndFunc

; ------------------------------------------------------------------------------
; 读 %HALCONROOT% 并**做版本校验**：不是 $HALCON_VERKEY 的目录一律丢弃。
;
; 这台机器上曾经同时装着 HALCON 26.05，HALCONROOT 指向的就是 26.05 的目录 ——
; 不做校验就会把 18 的补丁 DLL 打到 26.05 上（实际发生过）。
; ------------------------------------------------------------------------------
Func Halcon_EnvRoot()
    Local $sRoot = EnvGet("HALCONROOT")
    If $sRoot = "" Then Return ""

    If StringInStr($sRoot, $HALCON_VERKEY) = 0 Then
        Logger_Warn("已忽略 HALCONROOT（" & $sRoot & "）：不是 " & $HALCON_VERKEY & " 的目录")
        Return ""
    EndIf

    Return $sRoot
EndFunc

; ==============================================================================
; 安装向导自动化
; ==============================================================================

; 驱动 HALCON 安装向导走完全程。成功返回 True。
Func Halcon_RunWizard()
    Local $sSetup = Installer_PackagePath($HALCON_DIR, $HALCON_SETUP)
    If Not FileExists($sSetup) Then
        Logger_Err("安装包不存在：" & $sSetup)
        Return False
    EndIf

    Logger_Step("HALCON " & $HALCON_VERNUM & " 图形化安装")
    Logger_Info("  该安装包不支持 /S 静默安装（完整版只在 runtime 版支持），改为自动操作安装向导")
    Logger_Info("  安装包：" & $sSetup)

    Local $iPid = Run('"' & $sSetup & '"', @ScriptDir)
    If $iPid = 0 Then
        Logger_Err("安装程序启动失败")
        Return False
    EndIf
    $g_iHalconPid = $iPid
    Logger_Info("  进程 PID：" & $iPid & "，等待向导窗口（最多 " & $HALCON_WIZ_FIRST_MS / 1000 & " 秒）…")

    Local $hWin = WinWait($HALCON_WINTITLE, "", $HALCON_WIZ_FIRST_MS / 1000)
    If $hWin = 0 Then
        Logger_Err("等不到安装向导窗口，放弃")
        Return False
    EndIf
    Logger_Info("  向导已出现：" & WinGetTitle($hWin))

    Local $sDest   = Halcon_InstallRootDir()
    Local $iPage   = 0
    Local $bFinish = False

    While $iPage < $HALCON_MAXPAGE
        $iPage += 1

        ; 安装器可能弹提示框 —— 不点掉就会一直等（详见 Halcon_DismissDialogs）
        Halcon_DismissDialogs($hWin)

        Local $sPage = ControlGetText($hWin, "", $HALCON_ID_PAGETITLE)
        Logger_Info("向导第 " & $iPage & " 页：[" & $sPage & "]")

        ; ---- License 页：滚到底 + 接受 ----
        If $sPage = "License Agreement" Then
            If Not Halcon_AcceptLicense($hWin) Then
                Halcon_AbortWizard($hWin)
                Return False
            EndIf

        ; ---- 更新检查页：取消联网勾选 ----
        ElseIf $sPage = "Update Information" Then
            If Number(ControlCommand($hWin, "", $HALCON_ID_MAINTCHK, "IsChecked", "")) = 1 Then
                Logger_Info("  取消勾选「联网检查维护版本」（出厂环境不联网）")
                ControlClick($hWin, "", $HALCON_ID_MAINTCHK)
                Sleep(500)
            EndIf

        ; ---- 架构页：明确选 x64 ----
        ElseIf $sPage = "Architecture Selection" Then
            Logger_Info("  选择 x64 版本")
            ControlClick($hWin, "", $HALCON_ID_ARCH_X64)
            Sleep(500)

        ; ---- 组件页：用安装器默认组件，只记录，不修改 ----
        ; （用户确认：VS 扩展装不装不管，不做组件勾选自动化 —— 那棵树是自绘控件，
        ;   标准消息与键盘都不可靠，见 docs/packages/halcon.md 的说明）
        ElseIf $sPage = "Choose Components" Then
            Logger_Info("  安装类型：" & ControlCommand($hWin, "", $HALCON_ID_COMBO, "GetCurrentSelection", ""))
            Logger_Info("  占用空间：" & ControlGetText($hWin, "", $HALCON_ID_SPACE))
            Logger_Info("  （使用安装器默认组件；如需调整请在向导可见时人工操作）")

        ; ---- 附加驱动页：GigE 滤镜按开关处理 ----
        ElseIf $sPage = "Additional Drivers" Then
            Local $iWant = 0
            If $HALCON_GIGE_FILTER Then $iWant = 1
            Local $iNow = Number(ControlCommand($hWin, "", $HALCON_ID_GIGE, "IsChecked", ""))
            Logger_Info("  GigE 滤镜驱动：当前=" & $iNow & "，目标=" & $iWant)
            If $iNow <> $iWant Then
                ControlClick($hWin, "", $HALCON_ID_GIGE)
                Sleep(500)
            EndIf

        ; ---- 文档语言页：英文 ----
        ElseIf $sPage = "Documentation Language" Then
            Logger_Info("  选择英文文档")
            ControlClick($hWin, "", $HALCON_ID_DOC_EN)
            Sleep(500)

        ; ---- 安装位置页：回填目录，然后点 Install（该页按钮文字已是 &Install）----
        ElseIf $sPage = "Choose Install Location" Then
            Logger_Info("  安装目录：" & $sDest)
            ControlSetText($hWin, "", $HALCON_ID_DEST, $sDest)
            Sleep(300)
            Local $sBack = ControlGetText($hWin, "", $HALCON_ID_DEST)
            If Common_NormalizePath($sBack) <> Common_NormalizePath($sDest) Then
                Logger_Warn("  回读到的目录是「" & $sBack & "」，与预期不一致（继续，但请留意）")
            EndIf

            Logger_Info("  点击 Install 开始安装…")

            ; ---- 干跑：到这一页就收手，绝不装 ----
            If $g_bHalconWizDryRun Then
                Logger_Warn("  干跑模式：已走到安装页，按开关要求取消，**未执行安装**")
                Halcon_LogWizardControls($hWin)
                ControlClick($hWin, "", $HALCON_ID_CANCEL)
                Sleep(1500)
                Return False
            EndIf

            ControlClick($hWin, "", $HALCON_ID_NEXT)

            ; ---- 进入安装阶段：挂上等待心跳，等 Finish ----
            $bFinish = Halcon_WaitInstall($hWin)
            ExitLoop

        ; ---- 纯说明页：Welcome（页标题为空）/ Additional Information ----
        ElseIf $sPage = "" Or $sPage = "Welcome" Or $sPage = "Additional Information" Then
            ; 无操作，直接 Next

        ; ---- 其它一律视为未识别页面：Dump 后失败退出，**绝不盲目点 Next** ----
        Else
            Logger_Err("遇到未识别的向导页面「" & $sPage & "」，已中止（不盲目点 Next）")
            Halcon_LogWizardControls($hWin)
            Halcon_AbortWizard($hWin)
            Return False
        EndIf

        ; ---- 点 Next 并等页面变化（安装位置页已在上面 ExitLoop）----
        If Not Halcon_ClickNext($hWin) Then
            Halcon_AbortWizard($hWin)
            Return False
        EndIf
        If Not Halcon_WaitPageChange($hWin, $sPage, $HALCON_WIZ_STEP_MS) Then
            Logger_Err("向导停在页面「" & $sPage & "」没有前进，已中止")
            Halcon_LogWizardControls($hWin)
            Halcon_AbortWizard($hWin)
            Return False
        EndIf
    WEnd

    If Not $bFinish Then
        Logger_Err("向导没有走到收尾（页数超过上限 " & $HALCON_MAXPAGE & "，或安装阶段未完成），已中止")
        Halcon_AbortWizard($hWin)
        Return False
    EndIf

    ; ---- 结果校验：目录与主程序真的在吗 ----
    If Not FileExists(Common_JoinPath(Common_JoinPath($sDest, $HALCON_BIN), $HALCON_ARCH)) Then
        Logger_Err("安装流程结束，但没找到 " & $sDest & "\" & $HALCON_BIN & "\" & $HALCON_ARCH)
        Return False
    EndIf

    Logger_Ok("HALCON " & $HALCON_VERNUM & " 安装完成：" & $sDest)
    Return True
EndFunc

; License 页：把 EULA 滚到底，等「I accept」可用后点它。
;
; 【为什么这里不用 [ID:1034]】
;   实测这一页有**两个 id=1034**：一个是固定在窗口下方的 Static 标签，另一个才是
;   「I accept ...」复选框（NSIS InstallOptions 的页面控件 ID 会和窗口固定控件撞）。
;   `[ID:1034]` 只会命中先枚举到的那个 Static —— 点它毫无作用，Next 永远不可用。
;   所以这里按「类名 Button + 文字含 I accept + 当前可用」找**句柄**来点。
Func Halcon_AcceptLicense($hWin)
    ControlSend($hWin, "", $HALCON_ID_EULA_TEXT, "^{END}")   ; [ID:1000] 是唯一的 RichEdit

    Local $iTick = 0, $hAcc = 0
    While $iTick < 30000
        $hAcc = Halcon_FindCtrl($hWin, "Button", "I accept", True)
        If $hAcc <> 0 Then ExitLoop
        Sleep(500)
        $iTick += 500
    WEnd

    If $hAcc = 0 Then
        Logger_Err("License 页：「I accept」复选框始终不可用，已中止")
        Halcon_LogWizardControls($hWin)
        Return False
    EndIf

    Logger_Info("  已滚到许可协议末尾，勾选接受（hwnd=" & $hAcc & "）")
    ControlClick($hWin, "", $hAcc)
    Sleep(500)
    Return True
EndFunc

; ------------------------------------------------------------------------------
; 按「类名 + 文字子串（+ 可选：必须处于可用状态）」在窗口里找**控件句柄**。
;
; 存在的意义就是上面那个 ID 撞车问题：NSIS InstallOptions 分配出来的页面控件 ID
; 会与窗口固定控件（标题、页脚、按钮）重号，`[ID:n]` 可能命中错的那个。
; 找不到返回 0。
; ------------------------------------------------------------------------------
Global $g_hHcFind      = 0
Global $g_sHcFindCls   = ""
Global $g_sHcFindText  = ""
Global $g_bHcFindEna   = False

Func Halcon_FindProc($h, $l)
    #forceref $l
    If $g_hHcFind <> 0 Then Return 0                       ; 已找到，停止枚举
    If Halcon_CtrlInfo($h, "class") <> $g_sHcFindCls Then Return 1
    If Halcon_CtrlInfo($h, "vis") <> 1 Then Return 1
    If $g_bHcFindEna And Halcon_CtrlInfo($h, "ena") <> 1 Then Return 1
    If StringInStr(Halcon_CtrlInfo($h, "text"), $g_sHcFindText) = 0 Then Return 1
    $g_hHcFind = $h
    Return 0
EndFunc

Func Halcon_FindCtrl($hWin, $sClass, $sTextPart, $bNeedEnabled = False)
    $g_hHcFind    = 0
    $g_sHcFindCls = $sClass
    $g_sHcFindText = $sTextPart
    $g_bHcFindEna = $bNeedEnabled

    Local $hProc = DllCallbackRegister("Halcon_FindProc", "int", "hwnd;lparam")
    DllCall("user32.dll", "bool", "EnumChildWindows", "hwnd", $hWin, _
            "ptr", DllCallbackGetPtr($hProc), "lparam", 0)
    DllCallbackFree($hProc)

    Return $g_hHcFind
EndFunc

; 失败收尾：把向导关掉，别把模态窗口留在桌面上（无人值守时更不该留）
Func Halcon_AbortWizard($hWin)
    If Not WinExists($hWin) Then Return
    Logger_Warn("  已中止向导操作，点 Cancel 关闭安装窗口")
    ControlClick($hWin, "", $HALCON_ID_CANCEL)
    Sleep(1500)
    If WinExists($hWin) Then
        Logger_Warn("  窗口仍在（可能有确认对话框），需要人工处理：" & WinGetTitle($hWin))
    EndIf
EndFunc

; ------------------------------------------------------------------------------
; 自动点掉安装器弹出来的提示框。
;
; 【为什么必须做】
;   安装到最后一步会写环境变量（`HALCONROOT`、把 `bin\x64-win64` 追加到 `PATH`）。
;   如果目标机的 `PATH` 已经很长，安装器会弹一个「环境变量可能超出最大长度」的
;   警告框**等人点确定** —— 没人点就一直卡着，界面上的「已等待」照常跳动，
;   要等满 30 分钟超时才失败，日志上完全看不出是弹了框。
;   （实测本机 `PATH` 已经 2269 字符，里面还留着已卸载版本的目录，很容易触发。）
;
; 【判定规则】
;   可见顶层窗口里，除向导主窗口之外：
;     · 进程就是安装器（$g_iHalconPid），或
;     · 标题含 HALCON 且窗口类是对话框 `#32770`，或
;     · 标题就是「VSIX Installer」（WPF 程序，窗口类不是 #32770，单独放行）
;   就当成提示框：先把整窗控件清单写进日志（留审计），再找确认类按钮点掉。
;   **只点 OK / 确定 / Yes / 是**，绝不点 No / Cancel —— 免得替人做了「取消安装」的决定。
;   【唯一的例外】「VSIX Installer」窗口：VS 扩展装没装成功**都不管**（用户决定），
;   直接点 关闭 / Cancel 把它收掉 —— 取消的正是扩展安装，不是主安装。
;   VSIX 安装器的按钮是 WPF 绘制、读不出文字，找不到按钮时用 WinClose() 关窗口兜底。
; ------------------------------------------------------------------------------
Func Halcon_DismissDialogs($hMain)
    Local $a = WinList()
    Local $h, $sTitle, $iBtn, $bMine

    For $i = 1 To $a[0][0]
        $sTitle = $a[$i][0]
        If $sTitle = "" Then ContinueLoop

        $h = $a[$i][1]
        If $h = $hMain Then ContinueLoop
        If BitAND(WinGetState($h), 2) = 0 Then ContinueLoop          ; 不可见

        $bMine = (WinGetProcess($h) = $g_iHalconPid)
        If Not $bMine Then
            ; 安装器的子进程（VSIX 安装器、驱动安装器等）对话框：靠标题 + 窗口类认。
            ; VSIX 安装器是 WPF 程序，窗口类不是 #32770，标题匹配就放行。
            If Not StringRegExp($sTitle, $HALCON_DLG_TITLES) Then ContinueLoop
            If Halcon_CtrlInfo($h, "class") <> "#32770" _
                    And StringInStr($sTitle, "VSIX Installer") = 0 Then ContinueLoop
        EndIf

        ; ---- VSIX 安装器：扩展装没装成功都不管，直接点 关闭 / 取消 ----
        If StringInStr($sTitle, "VSIX Installer") > 0 Then
            Logger_Warn("VSIX 安装器窗口出现（" & $sTitle & "）—— 按「扩展不管成败」处理，点关闭/取消")
            Halcon_LogWizardControls($h)

            $iBtn = Halcon_FindCtrl($h, "Button", "Close", True)
            If $iBtn = 0 Then $iBtn = Halcon_FindCtrl($h, "Button", "关闭", True)
            If $iBtn = 0 Then $iBtn = Halcon_FindCtrl($h, "Button", "Cancel", True)
            If $iBtn = 0 Then $iBtn = Halcon_FindCtrl($h, "Button", "取消", True)

            If $iBtn <> 0 Then
                ControlClick($h, "", $iBtn)
            Else
                ; WPF 按钮读不出文字 —— 直接给窗口发关闭消息（等同点右上角 X = Cancel）
                Logger_Info("  没找到可读的按钮，用 WinClose 关闭窗口")
                WinClose($h)
            EndIf

            Sleep(800)
            ContinueLoop
        EndIf

        ; 先判断是不是「要不要重启」的询问
        Local $bReboot = (Halcon_FindCtrl($h, "Static", "restarted") <> 0) _
                Or (Halcon_FindCtrl($h, "Static", "reboot") <> 0) _
                Or (Halcon_FindCtrl($h, "Static", "重新启动") <> 0) _
                Or (Halcon_FindCtrl($h, "Static", "重启") <> 0)

        If $bReboot Then
            Logger_Warn("安装器询问是否重启（" & $sTitle & "）—— 无人值守装机不能重启机器，点【否】")
            Halcon_LogWizardControls($h)

            $iBtn = Halcon_FindCtrl($h, "Button", "No", True)
            If $iBtn = 0 Then $iBtn = Halcon_FindCtrl($h, "Button", "否", True)
            If $iBtn = 0 Then $iBtn = Halcon_FindCtrl($h, "Button", "Later", True)
            If $iBtn = 0 Then $iBtn = Halcon_FindCtrl($h, "Button", "稍后", True)

            If $iBtn <> 0 Then
                Logger_Info("  找到否按钮 hwnd=" & $iBtn & "，点击")
                ControlClick($h, "", $iBtn)
            Else
                ; 找不到「否」就不能乱点 —— 点错成「是」会把机器重启掉
                Logger_Err("  没找到否按钮，不处理（请人工在弹框里选「否」，以免机器被重启）")
            EndIf

            Sleep(800)
            ContinueLoop
        EndIf

        Logger_Warn("安装器弹出提示框：「" & $sTitle & "」，自动确认")
        Halcon_LogWizardControls($h)

        $iBtn = Halcon_FindCtrl($h, "Button", "OK", True)
        If $iBtn = 0 Then $iBtn = Halcon_FindCtrl($h, "Button", "确定", True)
        If $iBtn = 0 Then $iBtn = Halcon_FindCtrl($h, "Button", "Yes", True)
        If $iBtn = 0 Then $iBtn = Halcon_FindCtrl($h, "Button", "是", True)
        If $iBtn = 0 Then $iBtn = Halcon_FindCtrl($h, "Button", "Close", True)
        If $iBtn = 0 Then $iBtn = Halcon_FindCtrl($h, "Button", "关闭", True)

        If $iBtn <> 0 Then
            ControlClick($h, "", $iBtn)
        Else
            Logger_Warn("  没找到确认按钮，改为向该窗口发回车")
            WinActivate($h)
            Send("{ENTER}")
        EndIf

        Sleep(800)
    Next

    Return True
EndFunc

; 点当前页的 Next / Install 按钮（都是 [ID:1]）
Func Halcon_ClickNext($hWin)
    If ControlCommand($hWin, "", $HALCON_ID_NEXT, "IsVisible", "") <> 1 Then
        Logger_Err("找不到 Next 按钮，已中止")
        Halcon_LogWizardControls($hWin)
        Return False
    EndIf

    Local $iTick = 0
    While $iTick < 30000
        If Number(ControlCommand($hWin, "", $HALCON_ID_NEXT, "IsEnabled", "")) = 1 Then ExitLoop
        Sleep(500)
        $iTick += 500
    WEnd

    If Number(ControlCommand($hWin, "", $HALCON_ID_NEXT, "IsEnabled", "")) <> 1 Then
        Logger_Err("Next 按钮始终不可用，已中止")
        Halcon_LogWizardControls($hWin)
        Return False
    EndIf

    ControlClick($hWin, "", $HALCON_ID_NEXT)
    Return True
EndFunc

; 等页面标题变化；窗口消失也视为变化（安装器可能自行收尾）
Func Halcon_WaitPageChange($hWin, $sOldPage, $iTimeoutMs)
    Local $iTick = TimerInit()
    While TimerDiff($iTick) < $iTimeoutMs
        Sleep(500)
        If Not WinExists($hWin) Then Return True
        If ControlGetText($hWin, "", $HALCON_ID_PAGETITLE) <> $sOldPage Then Return True
    WEnd
    Return False
EndFunc

; 安装阶段：挂等待心跳，点掉安装后向导页，等 Finish 出现并点掉，
; 最终**等安装器进程退出**（包括点掉最后的「是否重启」询问）。
Func Halcon_WaitInstall($hWin)
    Installer_WaitBegin("HALCON 安装")
    Local $bDone = False
    Local $iTick = TimerInit()

    While TimerDiff($iTick) < $HALCON_TIMEOUT
        ; ---- 终点判定：安装器进程退出 ----
        ; 【不能只盯主窗口】点完 Finish 后主窗口会先关，「是否重启」询问是
        ; 之后才弹的独立窗口 —— 实测两次都因为「窗口没了就当结束」把重启询问
        ; 孤儿化，没人点否。进程退出才是真正的终点。
        If $g_iHalconPid > 0 Then
            If Not ProcessExists($g_iHalconPid) Then
                $bDone = True
                ExitLoop
            EndIf
        ElseIf Not WinExists($hWin) Then
            $bDone = True          ; 拿不到 PID 时退回按窗口判
            ExitLoop
        EndIf

        ; 安装阶段最容易弹提示框：装完文件后要写环境变量（HALCONROOT / PATH），
        ; PATH 一长安装器就会弹「可能超出最大长度」的警告框等人点确定。
        ; 主窗口关掉之后也要继续扫 —— 重启询问就出现在那个阶段。
        Halcon_DismissDialogs($hWin)

        ; 主窗口已关（Finish 已点、只剩重启询问等弹框）：本轮没有页面动作可做
        If Not WinExists($hWin) Then
            Sleep(1000)
            ContinueLoop
        EndIf

        Local $sBtn = ControlGetText($hWin, "", $HALCON_ID_NEXT)

        ; ---- 安装完成后的向导页（实测：License file -> Additional 3rd party software）----
        ; 这几页按钮还是 &Next —— 不点就永远等不到 Finish，会干等满 30 分钟超时。
        ; 注意 Installing 页的按钮文字也是 &Next 但**禁用**，别把进度页当成向导页。
        If StringRegExp($sBtn, "(?i)^\s*&?\s*next\b") _
                And Number(ControlCommand($hWin, "", $HALCON_ID_NEXT, "IsEnabled", "")) = 1 _
                And ControlGetText($hWin, "", $HALCON_ID_PAGETITLE) <> "Installing" Then
            Local $sPage = ControlGetText($hWin, "", $HALCON_ID_PAGETITLE)
            If $sPage = "License file" Then
                Halcon_LicensePageSkip($hWin)
            Else
                Logger_Info("  安装后向导页「" & $sPage & "」，点 Next 继续")
                ControlClick($hWin, "", $HALCON_ID_NEXT)
            EndIf
            Sleep(1200)
            ContinueLoop
        EndIf

        If StringRegExp($sBtn, "(?i)^\s*&?\s*(finish|close)\s*$") Then
            If Number(ControlCommand($hWin, "", $HALCON_ID_NEXT, "IsEnabled", "")) = 1 Then
                Halcon_UncheckReadme($hWin)
                Logger_Info("  安装完成，点击「" & $sBtn & "」收尾")
                ControlClick($hWin, "", $HALCON_ID_NEXT)
                Sleep(1500)
                ; 不在这里结束 —— 循环继续转，直到点掉「是否重启」（选否）、
                ; 安装器进程真正退出为止。
                ContinueLoop
            EndIf
        EndIf

        Sleep(1000)
    WEnd

    Installer_WaitEnd()

    If Not $bDone Then
        If TimerDiff($iTick) >= $HALCON_TIMEOUT Then
            Logger_Err("安装阶段超时（" & $HALCON_TIMEOUT / 60000 & " 分钟）")
        Else
            Logger_Err("安装阶段中断：向导停在非收尾页面")
            Halcon_LogWizardControls($hWin)
        EndIf
    EndIf

    Return $bDone
EndFunc

; 读 Button（复选框/单选框）的勾选状态（BM_GETCHECK，1 = 选中）。
Func Halcon_BmGetCheck($h)
    Local $a = DllCall("user32.dll", "int", "SendMessageW", "hwnd", $h, "uint", 0x00F0, "wparam", 0, "lparam", 0)
    Return $a[0]
EndFunc

; ------------------------------------------------------------------------------
; License file 页（实测：安装完成后出现，Back 是禁用的，只能往前走）。
;
; 「Do not install a license file.」[1205] 默认已选中（实测 BM_GETCHECK=1）。
; 核对无误就点 Next；万一默认选的是「I have a license file」[1206]，点回「不安装」
; —— **绝不反过来替用户装许可**（本项目出厂部署不投放 License 文件）。
; 勾选状态读不出来时不动，留给人工，避免在许可问题上盲点。
; ------------------------------------------------------------------------------
Func Halcon_LicensePageSkip($hWin)
    Local $hNo = ControlGetHandle($hWin, "", $HALCON_ID_LICENSE_NO)
    Local $bReady = False

    If $hNo <> 0 Then
        If Halcon_BmGetCheck($hNo) = 1 Then
            $bReady = True
        Else
            ControlClick($hWin, "", $HALCON_ID_LICENSE_NO)
            Sleep(500)
            $bReady = (Halcon_BmGetCheck(ControlGetHandle($hWin, "", $HALCON_ID_LICENSE_NO)) = 1)
            If $bReady Then Logger_Warn("  License file 页：默认选中的是「安装许可文件」，已改回「不安装」")
        EndIf
    EndIf

    If Not $bReady Then
        Logger_Err("  License file 页：无法确认「Do not install a license file.」被选中，不点 Next（请人工确认后继续）")
        Halcon_LogWizardControls($hWin)
        Return False
    EndIf

    Logger_Info("  License file 页：不安装许可文件，点 Next")
    ControlClick($hWin, "", $HALCON_ID_NEXT)
    Return True
EndFunc

; ------------------------------------------------------------------------------
; Finish 页可能带「安装完成后打开 Readme」之类的复选框 —— 实测点完 Finish 会
; 自动用浏览器打开 HALCON 的 Readme 网页。工厂机器不该自己弹网页：
; 找文字含 eadme 的可见复选框，见勾就点掉。（没有该复选框时什么都不做。）
; ------------------------------------------------------------------------------
Global $g_aHcReadme[4]
Global $g_iHcReadme = 0

Func Halcon_ReadmeProc($h, $l)
    #forceref $l
    If Halcon_CtrlInfo($h, "class") = "Button" And Halcon_CtrlInfo($h, "vis") = 1 Then
        If StringInStr(Halcon_CtrlInfo($h, "text"), "eadme") > 0 _
                And $g_iHcReadme < UBound($g_aHcReadme) Then
            $g_aHcReadme[$g_iHcReadme] = $h
            $g_iHcReadme += 1
        EndIf
    EndIf
    Return 1
EndFunc

Func Halcon_UncheckReadme($hWin)
    $g_iHcReadme = 0
    Local $hProc = DllCallbackRegister("Halcon_ReadmeProc", "int", "hwnd;lparam")
    DllCall("user32.dll", "bool", "EnumChildWindows", "hwnd", $hWin, _
            "ptr", DllCallbackGetPtr($hProc), "lparam", 0)
    DllCallbackFree($hProc)

    For $i = 0 To $g_iHcReadme - 1
        Local $h = $g_aHcReadme[$i]
        Local $iChk = Halcon_BmGetCheck($h)
        Logger_Info("  Finish 页复选框「" & Halcon_CtrlInfo($h, "text") & "」勾选=" & $iChk)
        If $iChk = 1 Then
            ControlClick($hWin, "", $h)
            Sleep(300)
        EndIf
    Next
EndFunc

; ------------------------------------------------------------------------------
; 排障用：把向导窗口及其所有子控件（hwnd / 控件 ID / 类名 / 可见 / 可用 / 文字）
; 写进日志。向导页面变了、按钮文字改了的时候，靠它一次看清全部控件。
; ------------------------------------------------------------------------------
Global $g_sHcDump = ""
Global $g_iHcDump = 0

Func Halcon_CtrlInfo($h, $sItem)
    If $sItem = "text" Then
        Local $tText = DllStructCreate("wchar[1024]")
        DllCall("user32.dll", "int", "GetWindowTextW", "hwnd", $h, "ptr", DllStructGetPtr($tText), "int", 1024)
        Return DllStructGetData($tText, 1)
    EndIf
    If $sItem = "class" Then
        Local $tCls = DllStructCreate("wchar[256]")
        DllCall("user32.dll", "int", "GetClassNameW", "hwnd", $h, "ptr", DllStructGetPtr($tCls), "int", 256)
        Return DllStructGetData($tCls, 1)
    EndIf
    If $sItem = "id" Then Return DllCall("user32.dll", "int", "GetDlgCtrlID", "hwnd", $h)[0]
    If $sItem = "vis" Then Return DllCall("user32.dll", "bool", "IsWindowVisible", "hwnd", $h)[0]
    Return DllCall("user32.dll", "bool", "IsWindowEnabled", "hwnd", $h)[0]
EndFunc

Func Halcon_DumpProc($h, $l)
    #forceref $l
    $g_iHcDump += 1
    $g_sHcDump &= "    [" & StringFormat("%02d", $g_iHcDump) & "] id=" & _
            StringFormat("%-6d", Halcon_CtrlInfo($h, "id")) & _
            " vis=" & Halcon_CtrlInfo($h, "vis") & _
            " ena=" & Halcon_CtrlInfo($h, "ena") & _
            " " & StringFormat("%-20s", Halcon_CtrlInfo($h, "class")) & _
            " [" & Halcon_CtrlInfo($h, "text") & "]" & @CRLF
    Return 1
EndFunc

Func Halcon_LogWizardControls($hWin)
    $g_sHcDump = ""
    $g_iHcDump = 0
    Local $hProc = DllCallbackRegister("Halcon_DumpProc", "int", "hwnd;lparam")
    DllCall("user32.dll", "bool", "EnumChildWindows", "hwnd", $hWin, _
            "ptr", DllCallbackGetPtr($hProc), "lparam", 0)
    DllCallbackFree($hProc)

    Logger_Info("    ---- " & WinGetTitle($hWin) & " 的控件清单（" & $g_iHcDump & " 个）----")
    Logger_Info($g_sHcDump)
EndFunc

; ==============================================================================
; 补丁 DLL 覆盖
; ==============================================================================

; ------------------------------------------------------------------------------
; 把安装包 "halcon 18 x64" 目录**根层**的文件覆盖到 $sBinDir。
;
; 【为什么用 FileCopy 而不是 robocopy】
;   robocopy 会跳过「大小与时间戳都相同」的目标文件（判为 same），
;   实测加了 /IS 也照样跳过 —— 而补丁 DLL 与安装包释放的原文件完全可能
;   大小一致、时间戳也被安装程序设置成同一日期，那时补丁会**悄悄不生效**，
;   退出码还是 2（"只看成功码"根本发现不了）。
;   AutoIt 的 FileCopy($src, $dst, 1) 第三个参数是「强制覆盖」，
;   不参与任何「是否需要复制」的判断，结果确定。
;
;   只覆盖，不清理：目标目录里其他 DLL 必须保留，也不会递归处理子目录
;   （与「替换对应文件」的语义一致）。
;
; 成功返回 True，失败返回 False（含目标版本复核与逐个文件的大小校验）。
; ------------------------------------------------------------------------------
Func Halcon_ApplyPatch($sBinDir)
    ; ---- 先卡版本：这一关不过，绝不碰任何文件 ----
    If Not Halcon_VerifyTarget($sBinDir) Then Return False

    Local $sPatch = Installer_PackagePath($HALCON_DIR, $HALCON_PATCHDIR)
    If Not FileExists($sPatch) Then
        Logger_Err("补丁目录不存在：" & $sPatch)
        Return False
    EndIf

    Logger_Step("覆盖 HALCON 补丁文件")
    Logger_Info("  补丁来源：" & $sPatch)
    Logger_Info("  覆盖目标：" & $sBinDir)

    Local $hFind = FileFindFirstFile(Common_JoinPath($sPatch, "*"))
    If $hFind = -1 Then
        Logger_Err("补丁目录内没有文件：" & $sPatch)
        Return False
    EndIf

    Local $sName, $sSrc, $sDst, $iSize, $iCount = 0
    While True
        $sName = FileFindNextFile($hFind)
        If @error Then ExitLoop
        If @extended Then ContinueLoop          ; 跳过子目录，本步骤只覆盖根层文件

        $sSrc = Common_JoinPath($sPatch, $sName)
        $sDst = Common_JoinPath($sBinDir, $sName)
        $iSize = FileGetSize($sSrc)

        If Not FileCopy($sSrc, $sDst, 1) Then
            FileClose($hFind)
            Logger_Err("覆盖失败：" & $sDst & "（文件被占用时请先关闭 HALCON 相关程序）")
            Return False
        EndIf

        ; 结果校验：不能只看 FileCopy 的返回值，再核对一次大小
        If FileGetSize($sDst) <> $iSize Then
            FileClose($hFind)
            Logger_Err("覆盖后大小不符，可能未生效：" & $sDst)
            Return False
        EndIf

        Logger_Info("  已覆盖：" & $sName & "（" & Round($iSize / 1048576, 1) & " MB）")
        $iCount += 1
    WEnd
    FileClose($hFind)

    If $iCount = 0 Then
        Logger_Err("补丁目录内没有可覆盖的文件：" & $sPatch)
        Return False
    EndIf

    Logger_Ok("HALCON 补丁已覆盖 " & $iCount & " 个文件 -> " & $sBinDir)
    Return True
EndFunc

; ------------------------------------------------------------------------------
; 覆盖前的**目标版本复核** —— 防的就是「补丁打到了别的 HALCON 版本上」。
;
; 两道校验，都过才放行：
;   ① 目标目录路径必须含 $HALCON_VERKEY（HALCON-18.11）——
;      不同版本装在不同目录（HALCON-18.11-Progress / HALCON-26.05-Progress），
;      目录名是最便宜也最可靠的版本信号；
;   ② 目标 halcon.dll 的**版本资源**非空时，必须以 $HALCON_VERNUM 开头 ——
;      实测 26.05 读出来是 26.5.0.0、18.11 是 18.11.0.1，区分得很干净。
;      读不到版本资源时只告警不拦截（① 已经挡住了「跑到别的版本目录」）。
;
; 任一关不过就返回 False，且**不做任何文件改动**。
; ------------------------------------------------------------------------------
Func Halcon_VerifyTarget($sBinDir)
    If StringInStr($sBinDir, $HALCON_VERKEY) = 0 Then
        Logger_Err("拒绝覆盖：目标目录不是 " & $HALCON_VERKEY)
        Logger_Err("  目标目录：" & $sBinDir)
        Logger_Err("  路径里没有「" & $HALCON_VERKEY & "」字样，可能是别的 HALCON 版本；")
        Logger_Err("  覆盖会破坏那个版本的安装，已中止（未做任何改动）。")
        Return False
    EndIf

    If Not FileExists($sBinDir) Then
        Logger_Err("目标目录不存在：" & $sBinDir)
        Return False
    EndIf

    Local $sDll = Common_JoinPath($sBinDir, $HALCON_MAINEXE)
    If Not FileExists($sDll) Then
        Logger_Warn("目标目录里没有 " & $HALCON_MAINEXE & "，仅按目录名判定版本：" & $sBinDir)
        Return True
    EndIf

    Local $sVer = FileGetVersion($sDll)
    If $sVer = "" Then
        Logger_Warn("读不到 " & $HALCON_MAINEXE & " 的版本资源，仅按目录名判定版本：" & $sDll)
        Return True
    EndIf

    If StringLeft($sVer, StringLen($HALCON_VERNUM)) <> $HALCON_VERNUM Then
        Logger_Err("拒绝覆盖：目标版本是 HALCON " & $sVer & "，不是 " & $HALCON_VERNUM)
        Logger_Err("  目标文件：" & $sDll)
        Logger_Err("  已中止覆盖（未做任何改动），请确认 HALCON " & $HALCON_VERNUM & " 装在哪里。")
        Return False
    EndIf

    Logger_Info("  目标版本校验通过：HALCON " & $sVer & " @ " & $sBinDir)
    Return True
EndFunc
