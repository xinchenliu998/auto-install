; ==============================================================================
; Installer.au3 —— 安装调度与安装辅助模块
; ------------------------------------------------------------------------------
; 职责：
;   1. 把「软件目录」映射到「安装函数」，并按顺序调度执行；
;   2. 提供装机过程中反复用到的辅助操作：解压绿色包、写入系统 PATH、等待心跳。
;
; 【如何接入一个新软件】
;   1. 在 Include\Install\ 下新建 <软件名>.au3；
;   2. 文件顶部 #include 本模块，并调用 Installer_Register("<packages 下的目录名>", "Install_XXX")；
;   3. 实现 Func Install_XXX($sInstallRoot)，成功返回 True，失败返回 False；
;      · 执行外部命令请使用 Installer_RunWaitBeat()：安装期间界面不会假死，
;        并持续输出等待心跳，长时间任务不会看起来像卡死；
;      · 过程信息用 Logger_Info / Logger_Warn / Logger_Err 输出，会自动落盘；
;   4. 在 Include\Install\All.au3 的「安装模块列表」登记一行 #include 该文件。
;
; 参考实现见 Install\7zip.au3（静默安装）与 Install\sqlite3.au3（绿色解压）。
; ==============================================================================

#include-once

#include "Constants.au3"
#include "Common.au3"
#include "Logger.au3"
#include "Config.au3"

; ------------------------------------------------------------------------------
; 注册表：[i][$REG_COL_*]
; ------------------------------------------------------------------------------
Global $g_aRegistry[1][$REG_COL_COUNT]
Global $g_iRegistry = 0

; 进度回调（由 GUI 层注册）
Global $g_sNotifyFunc = ""

Func Installer_SetNotify($sFunc)
    $g_sNotifyFunc = $sFunc
EndFunc

; 由各 Install_*.au3 在加载时调用，完成自注册
Func Installer_Register($sFolder, $sFunc)
    For $i = 0 To $g_iRegistry - 1
        If $g_aRegistry[$i][$REG_COL_FOLDER] = $sFolder Then
            $g_aRegistry[$i][$REG_COL_FUNC] = $sFunc
            Return True
        EndIf
    Next

    ReDim $g_aRegistry[$g_iRegistry + 1][$REG_COL_COUNT]
    $g_aRegistry[$g_iRegistry][$REG_COL_FOLDER] = $sFolder
    $g_aRegistry[$g_iRegistry][$REG_COL_FUNC]   = $sFunc
    $g_iRegistry += 1

    Return True
EndFunc

Func Installer_FindFunc($sFolder)
    For $i = 0 To $g_iRegistry - 1
        If $g_aRegistry[$i][$REG_COL_FOLDER] = $sFolder Then Return $g_aRegistry[$i][$REG_COL_FUNC]
    Next
    Return ""
EndFunc

; 该目录名是否已有对应的安装脚本（即「已适配」）。
; 配置界面用它把安装包目录里「未适配」的子目录挡在软件列表之外。
Func Installer_IsRegistered($sFolder)
    Return (Installer_FindFunc($sFolder) <> "")
EndFunc

; ==============================================================================
; 安装辅助操作
; ==============================================================================

; ------------------------------------------------------------------------------
; 等待心跳
; ------------------------------------------------------------------------------
; 安装 / 解压 / 拷贝可能持续几分钟甚至半小时。这段时间界面虽然不假死（消息泵在跑），
; 但日志里不会出现任何新内容，用户很容易以为程序卡住了。
;
; 做法：在执行外部命令的等待期间挂一个 Adlib 定时器（AutoIt 的 Sleep 期间 Adlib 照常触发，
; 现有的超时强杀就是这么实现的）：
;   · 每 $RUN_HEARTBEAT_MS 回调界面刷新「已等待 X 分 Y 秒」——最直观的「还在干活」信号；
;   · 每 $RUN_HEARTBEAT_LOG_SEC 秒写一条日志，事后也能看出当时是「在跑」还是「真卡住」。
;
; 放在本模块而不是 Common.au3：心跳要写日志，而 Common.au3 是基础层，
; 依赖 Logger 会形成循环 include（见 AGENTS.md 的踩坑记录）。
; ------------------------------------------------------------------------------

Global $g_sWaitLabel   = ""     ; 当前等待项的名称（空串 = 没有在等待）
Global $g_hWaitStart   = 0      ; 本次等待的起始时刻
Global $g_iWaitNextLog = 0      ; 下一条心跳日志的时间点（秒）
Global $g_sWaitNotify  = ""     ; 界面回调（由 GUI 层通过 Installer_SetWaitNotify 注册）

; 由 GUI 层注册，用于把「已等待」实时显示到界面上
Func Installer_SetWaitNotify($sFunc)
    $g_sWaitNotify = $sFunc
EndFunc

; 执行外部命令并等待，期间持续输出心跳。参数与 Common_RunWait() 完全一致。
Func Installer_RunWaitBeat($sLabel, $sCmd, $sWorkDir = "", $iTimeoutMs = 0)
    Installer_WaitBegin($sLabel)
    Local $iRet = Common_RunWait($sCmd, $sWorkDir, $iTimeoutMs)
    Installer_WaitEnd()
    Return $iRet
EndFunc

Func Installer_WaitBegin($sLabel)
    $g_sWaitLabel   = $sLabel
    $g_hWaitStart   = TimerInit()
    $g_iWaitNextLog = $RUN_HEARTBEAT_LOG_SEC
    AdlibRegister("Installer_WaitTick", $RUN_HEARTBEAT_MS)
EndFunc

Func Installer_WaitEnd()
    AdlibUnRegister("Installer_WaitTick")
    $g_sWaitLabel = ""
EndFunc

; Adlib 回调：在 Common_RunWait() 的等待期间照常触发
Func Installer_WaitTick()
    If $g_sWaitLabel = "" Then Return

    Local $iSec = Int(TimerDiff($g_hWaitStart) / 1000)

    ; 界面实时计时 —— 「没卡死」最直观的信号
    If $g_sWaitNotify <> "" Then Call($g_sWaitNotify, $g_sWaitLabel, $iSec)

    ; 定期落一条日志，便于事后判断当时是否仍在工作
    If $iSec >= $g_iWaitNextLog Then
        Logger_Info($g_sWaitLabel & " 仍在进行，已等待 " & Common_FormatDuration($iSec))
        $g_iWaitNextLog += $RUN_HEARTBEAT_LOG_SEC
    EndIf
EndFunc

; 拼出 <安装包目录>\<目录>\<文件> 的完整路径。
;
; 注意：这里必须走 Config_PackagesDirReal()（配置里可改），
; 不能写死 @ScriptDir\packages —— 否则用户切换安装包目录后，安装脚本仍会去默认目录找安装包。
Func Installer_PackagePath($sSubDir, $sFile)
    Return Common_JoinPath(Common_JoinPath(Config_PackagesDirReal(), $sSubDir), $sFile)
EndFunc

; 拼出 Program Files\<子目录>\<文件> 的完整路径（第三方安装包的常见落点）
Func Installer_ProgramFilesPath($sSubDir, $sFile)
    Return Common_JoinPath(Common_JoinPath(@ProgramFilesDir, $sSubDir), $sFile)
EndFunc

; 查找某个软件已安装的位置，返回找到的路径；未找到返回空串。
;
;   $vExpected  预期路径，可以是：
;                 · 字符串 —— 单个预期路径（如 C:\Program Files\7-Zip\7z.exe）
;                 · 数组   —— 多个候选（文件或目录均可），逐个判断
;                 · ""     —— 跳过预期路径，直接查 PATH
;   $sExeName   主程序文件名，用于在系统 PATH 中查找
;
; 查找顺序：预期路径 -> 整个系统 PATH。
; 查 PATH 是为了覆盖「装在别的盘 / 目录」或「绿色版已挂在 PATH 上」的情况。
Func Installer_FindInstalled($vExpected, $sExeName)
    If IsArray($vExpected) Then
        For $i = 0 To UBound($vExpected) - 1
            If $vExpected[$i] <> "" And FileExists($vExpected[$i]) Then Return $vExpected[$i]
        Next
    ElseIf $vExpected <> "" Then
        If FileExists($vExpected) Then Return $vExpected
    EndIf

    Return Common_Which($sExeName)
EndFunc

; 解压 zip 到指定目录，成功返回 True。
; 依次尝试：7-Zip 命令行 -> PowerShell Expand-Archive（Win10 及以上自带）
Func Installer_ExtractZip($sZip, $sDest)
    If Not FileExists($sZip) Then
        Logger_Err("压缩包不存在：" & $sZip)
        Return False
    EndIf

    If Not Common_EnsureDir($sDest) Then
        Logger_Err("无法创建目标目录：" & $sDest)
        Return False
    EndIf

    ; ---- 方案一：7-Zip 命令行 ----
    ; 额外把「安装包目录」也纳入查找范围，那里可能放着一份绿色版 7z.exe
    Local $s7z = Common_Find7Zip(Config_PackagesDirReal())
    If $s7z <> "" Then
        Logger_Info("使用 7-Zip 解压：" & $s7z)
        Local $iRet = Installer_RunWaitBeat("解压 " & Common_FileName($sZip), _
                '"' & $s7z & '" x "' & $sZip & '" -o"' & $sDest & '" -y', _
                @ScriptDir, $TIMEOUT_UNZIP)
        If $iRet = 0 Then Return True

        Logger_Warn("7-Zip 解压失败（返回 " & $iRet & "），改用 PowerShell 重试")
    Else
        Logger_Info("未找到 7-Zip，改用 PowerShell 解压")
    EndIf

    ; ---- 方案二：PowerShell Expand-Archive ----
    Local $sCmd = "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command " & _
            '"Expand-Archive -LiteralPath ' & Common_PsQuote($sZip) & _
            " -DestinationPath " & Common_PsQuote($sDest) & ' -Force"'

    Local $iRet2 = Installer_RunWaitBeat("解压 " & Common_FileName($sZip), _
            $sCmd, @ScriptDir, $TIMEOUT_UNZIP)
    If $iRet2 = 0 Then Return True

    Logger_Err("PowerShell 解压失败（返回 " & $iRet2 & "）")
    Return False
EndFunc

; 把目录追加到系统 PATH（HKLM，需管理员权限），已存在则不重复添加。
;
; 注意：系统 PATH 通常是 REG_EXPAND_SZ。AutoIt 的 RegRead 可能已把其中的
;       %SystemRoot% 之类展开，写回后功能不受影响，但会失去变量形式的简写。
;       若不能接受，请把调用方（如 Install_sqlite3）的开关改为 False。
Func Installer_AddToSystemPath($sDir)
    Local $sTarget = Common_NormalizePath($sDir)
    If $sTarget = "" Then Return False

    Local $sKey = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
    Local $sOld = RegRead($sKey, "Path")
    If @error Then
        Logger_Err("读取系统 PATH 失败（@error=" & @error & "），请以管理员身份运行")
        Return False
    EndIf

    If Common_PathListHas($sOld, $sTarget) Then
        Logger_Info("系统 PATH 中已存在，无需添加：" & $sTarget)
        Return True
    EndIf

    Local $sNew = $sOld
    If StringRight($sNew, 1) <> ";" Then $sNew &= ";"
    $sNew &= $sTarget

    If RegWrite($sKey, "Path", "REG_EXPAND_SZ", $sNew) = 0 Then
        Logger_Err("写入系统 PATH 失败（@error=" & @error & "），请以管理员身份运行")
        Return False
    EndIf

    ; 广播 WM_SETTINGCHANGE，让新启动的进程立即读到新 PATH
    DllCall("user32.dll", "lresult", "SendMessageTimeoutW", _
            "hwnd", 0xFFFF, "uint", 0x001A, "wparam", 0, "lparam", "wstr", "Environment", _
            "uint", 0x0002, "uint", 5000, "dword*", 0)

    Logger_Info("已加入系统 PATH：" & $sTarget)
    Return True
EndFunc

; ==============================================================================
; 通用安装流程
; ------------------------------------------------------------------------------
; 各 Install 模块只需填参数调用下面两个函数，不要再各自重写「检测 -> 执行 -> 校验」。
; ==============================================================================

; 通用「静默安装」流程：
;   安装包存在性 -> 已安装检测 -> 执行安装 -> 结果校验
;
;   $sDisplay    软件显示名（仅用于日志），如 "7-Zip"
;   $sSetup      安装包完整路径
;   $sArgs       静默参数，如 $SILENT_NSIS / $SILENT_INNO
;   $sExeName    安装后主程序文件名，用于在系统 PATH 中查找
;   $vExpected   预期安装路径（字符串 / 数组 / ""），见 Installer_FindInstalled()
;   $iTimeoutMs  安装超时（毫秒），默认 $TIMEOUT_INSTALL
;
; 返回 True / False。
Func Installer_InstallSilent($sDisplay, $sSetup, $sArgs, $sExeName, _
        $vExpected = "", $iTimeoutMs = $TIMEOUT_INSTALL)

    If Not FileExists($sSetup) Then
        Logger_Err($sDisplay & "：安装包不存在 " & $sSetup)
        Return False
    EndIf

    ; ---- 已安装检测 ----
    Local $sFound = Installer_FindInstalled($vExpected, $sExeName)
    If $sFound <> "" Then
        Logger_Info("已检测到 " & $sDisplay & "，跳过安装：" & $sFound)
        Return True
    EndIf

    ; ---- 执行安装 ----
    Logger_Info($sDisplay & " 静默安装：" & $sSetup & " " & $sArgs)
    Local $iRet = Installer_RunWaitBeat($sDisplay & " 安装", _
            '"' & $sSetup & '" ' & $sArgs, @ScriptDir, $iTimeoutMs)

    If $iRet = $RUN_ERR_START Then
        Logger_Err($sDisplay & "：安装程序启动失败")
        Return False
    EndIf

    If $iRet = $RUN_ERR_TIMEOUT Then
        Logger_Err($sDisplay & "：安装超时（" & $iTimeoutMs / 60000 & " 分钟），已强制结束")
        Return False
    EndIf

    ; ---- 结果校验：不能只看退出码，还要能找到主程序 ----
    $sFound = Installer_FindInstalled($vExpected, $sExeName)
    If $sFound <> "" Then
        Logger_Info("退出码 " & $iRet & "，已确认 " & $sDisplay & " 安装结果：" & $sFound)
        Return True
    EndIf

    Logger_Err($sDisplay & "：退出码 " & $iRet & "，但在预期路径与系统 PATH 中均未找到 " & $sExeName)
    Return False
EndFunc

; 通用「绿色解压」流程：
;   已安装检测 -> 解压 -> 结果校验
;
;   $sDisplay    软件显示名（仅用于日志）
;   $sZip        压缩包完整路径
;   $sDest       解压目标目录
;   $sExeName    解压后主程序文件名，用于结果校验与 PATH 查找
;
; 成功返回找到的主程序完整路径；失败返回空串。
Func Installer_InstallGreen($sDisplay, $sZip, $sDest, $sExeName)
    Local $sTarget = Common_JoinPath($sDest, $sExeName)

    ; ---- 已安装检测 ----
    Local $sFound = Installer_FindInstalled($sTarget, $sExeName)
    If $sFound <> "" Then
        Logger_Info("已检测到 " & $sDisplay & "，跳过解压：" & $sFound)
        Return $sFound
    EndIf

    ; ---- 解压 ----
    Logger_Info($sDisplay & " 解压目标目录：" & $sDest)
    If Not Installer_ExtractZip($sZip, $sDest) Then Return ""

    ; ---- 结果校验 ----
    $sFound = Installer_FindInstalled($sTarget, $sExeName)
    If $sFound = "" Then
        Logger_Err($sDisplay & "：解压后在预期目录与系统 PATH 中均未找到 " & $sExeName)
        Return ""
    EndIf

    Logger_Info("已确认 " & $sDisplay & " 可用：" & $sFound)
    Return $sFound
EndFunc

; 资源拷贝：把拷贝源目录**整体**拷贝到「拷贝目标目录」下的同名子目录。
;
;   <CopySourceDir>  ->  <CopyDestDir>\<源文件夹名>\
;
; 目标目录留空时默认用安装根目录。用 robocopy 实现，等待期间界面不假死。
Func Installer_RunCopy()
    Local $sSrc  = Config_CopySourceReal()
    Local $sDest = Config_CopyDestReal()

    If $sSrc = "" Then Return True

    If Not FileExists($sSrc) Then
        Logger_Err("拷贝源目录不存在：" & $sSrc)
        Return False
    EndIf

    Local $sName   = Common_FileName($sSrc)
    Local $sTarget = Common_JoinPath($sDest, $sName)

    Logger_Step("拷贝资源：" & $sName)
    Logger_Info("  源目录：" & $sSrc)
    Logger_Info("  目标目录：" & $sTarget)

    If Not Common_EnsureDir($sDest) Then
        Logger_Err("无法创建拷贝目标目录：" & $sDest)
        Return False
    EndIf

    ; /E 含子目录（含空目录）；/NFL /NDL /NJH /NJS /NP 精简输出；/R:1 /W:1 失败只重试一次
    Local $sCmd = 'robocopy "' & $sSrc & '" "' & $sTarget & _
            '" /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1'

    Local $iRet = Installer_RunWaitBeat("拷贝 " & $sName, $sCmd, @ScriptDir, $TIMEOUT_COPY)

    If $iRet = $RUN_ERR_START Then
        Logger_Err("无法启动 robocopy")
        Return False
    EndIf

    If $iRet = $RUN_ERR_TIMEOUT Then
        Logger_Err("拷贝超时（" & $TIMEOUT_COPY / 60000 & " 分钟），已强制结束")
        Return False
    EndIf

    ; robocopy 的退出码 0~7 都表示成功（0 = 无需拷贝，1 = 有文件被拷贝…），8 及以上才是错误
    If $iRet > $ROBOCOPY_OK_MAX Then
        Logger_Err("拷贝失败，robocopy 退出码 " & $iRet)
        Return False
    EndIf

    Logger_Ok("资源拷贝完成：" & $sTarget)
    Return True
EndFunc

; ==============================================================================
; 调度执行
; ==============================================================================
; 入参：$aSelected / $iCount 来自 Config_GetSelected()
; 返回：3 元素数组 [成功数, 跳过数, 失败数]
;
; 顺序：先按勾选依次安装软件，最后执行资源拷贝（若有配置）。
Func Installer_RunAll($aSelected, $iCount)
    Local $iOk = 0, $iSkip = 0, $iFail = 0
    Local $sRoot = Config_InstallRootReal()

    If Not Common_EnsureDir($sRoot) Then
        Logger_Err("无法创建安装根目录：" & $sRoot)
    EndIf

    ; 资源拷贝算作额外一项任务，计入进度总数
    Local $bCopy  = Config_CopyEnabled()
    Local $iTotal = $iCount
    If $bCopy Then $iTotal += 1

    Local $sFolder, $sDisplay, $sPath, $sFunc, $bOk, $sHint

    For $i = 0 To $iCount - 1
        $sFolder  = $aSelected[$i][$PKG_COL_FOLDER]
        $sDisplay = $aSelected[$i][$PKG_COL_DISPLAY]
        $sPath    = $aSelected[$i][$PKG_COL_PATH]

        If $g_sNotifyFunc <> "" Then Call($g_sNotifyFunc, $i, $iTotal, $sDisplay)

        $sFunc = Installer_FindFunc($sFolder)

        If $sFunc = "" Then
            Logger_Warn("跳过「" & $sDisplay & "」：尚未实现安装脚本")
            $sHint = '请在 Include\Install\ 下新增模块，在其中调用 Installer_Register("' & _
                    $sFolder & '", "Install_XXX")，并在 All.au3 的模块列表中登记'
            Logger_Warn("        " & $sHint)
            $iSkip += 1
            ContinueLoop
        EndIf

        If Not FileExists($sPath) Then
            Logger_Err("跳过「" & $sDisplay & "」：安装包目录不存在 " & $sPath)
            $iFail += 1
            ContinueLoop
        EndIf

        Logger_Step("开始安装「" & $sDisplay & "」")

        $bOk = Call($sFunc, $sRoot)

        If $bOk Then
            Logger_Ok("「" & $sDisplay & "」处理完成")
            $iOk += 1
        Else
            Logger_Err("「" & $sDisplay & "」处理失败，请查看上方日志")
            $iFail += 1
        EndIf
    Next

    ; ---- 资源拷贝（文档、驱动等）----
    If $bCopy Then
        If $g_sNotifyFunc <> "" Then Call($g_sNotifyFunc, $iCount, $iTotal, "拷贝资源")

        If Installer_RunCopy() Then
            $iOk += 1
        Else
            $iFail += 1
        EndIf
    EndIf

    Local $aStat[3]
    $aStat[0] = $iOk
    $aStat[1] = $iSkip
    $aStat[2] = $iFail
    Return $aStat
EndFunc
