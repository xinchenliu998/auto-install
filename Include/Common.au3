; ==============================================================================
; Common.au3 —— 通用工具函数库
; ------------------------------------------------------------------------------
; 提供：权限判断、环境变量展开、路径处理、外部命令执行（带消息泵）。
; 常量一律取自 Constants.au3；本文件不含业务逻辑，可被其他模块安全 #include。
; ==============================================================================

#include-once

#include <AutoItConstants.au3>
#include <FileConstants.au3>
#include <StringConstants.au3>

#include "Constants.au3"

; ------------------------------------------------------------------------------
; 消息泵回调函数名（由 GUI 层通过 Common_SetPump() 注册）
; 作用：执行耗时外部命令期间持续处理窗口消息，保证界面不假死。
; ------------------------------------------------------------------------------
Global $g_sPumpFunc = ""

Func Common_SetPump($sFunc)
    $g_sPumpFunc = $sFunc
EndFunc

; ==============================================================================
; 权限
; ==============================================================================

; 判断当前进程是否已获得管理员权限（UAC 提升后为 True）
Func Common_IsElevated()
    Local $aProc = DllCall("kernel32.dll", "handle", "GetCurrentProcess")
    If @error Then Return False

    Local $aTok = DllCall("advapi32.dll", "bool", "OpenProcessToken", _
            "handle", $aProc[0], "dword", 0x0008, "ptr*", 0)
    If @error Or Not $aTok[0] Then Return False

    Local $hToken = $aTok[3]
    Local $tElev = DllStructCreate("dword TokenIsElevated")
    Local $aRet = DllCall("advapi32.dll", "bool", "GetTokenInformation", _
            "handle", $hToken, "int", 20, _
            "ptr", DllStructGetPtr($tElev), _
            "dword", DllStructGetSize($tElev), "dword*", 0)

    Local $bElevated = False
    If Not @error And $aRet[0] Then
        $bElevated = (DllStructGetData($tElev, "TokenIsElevated") <> 0)
    EndIf

    DllCall("kernel32.dll", "bool", "CloseHandle", "handle", $hToken)
    Return $bElevated
EndFunc

; ==============================================================================
; 路径
; ==============================================================================

; 展开路径中的 %VAR% 环境变量（如 %LOCALAPPDATA%）
Func Common_ExpandEnv($sPath)
    If $sPath = "" Then Return ""

    Local $tBuf = DllStructCreate("wchar[4096]")
    Local $aRet = DllCall("kernel32.dll", "dword", "ExpandEnvironmentStringsW", _
            "wstr", $sPath, "ptr", DllStructGetPtr($tBuf), "dword", 4096)
    If @error Or $aRet[0] = 0 Then Return $sPath

    Return DllStructGetData($tBuf, 1)
EndFunc

; 拼接目录与子项，自动处理分隔符
Func Common_JoinPath($sDir, $sChild)
    If $sDir = "" Then Return $sChild
    If $sChild = "" Then Return $sDir

    Local $sEnd = StringRight($sDir, 1)
    If $sEnd = "\" Or $sEnd = "/" Then Return $sDir & $sChild
    Return $sDir & "\" & $sChild
EndFunc

; 规范化路径：去首尾空白、统一分隔符、展开环境变量、去掉末尾多余的 "\"
Func Common_NormalizePath($sPath)
    Local $s = StringStripWS($sPath, 3)
    If $s = "" Then Return ""

    $s = StringReplace($s, "/", "\")
    $s = Common_ExpandEnv($s)

    While StringLen($s) > 3 And StringRight($s, 1) = "\"
        $s = StringLeft($s, StringLen($s) - 1)
    WEnd

    Return $s
EndFunc

; 目录不存在时创建
Func Common_EnsureDir($sDir)
    If $sDir = "" Then Return False
    If FileExists($sDir) Then Return True
    Return DirCreate($sDir)
EndFunc

; 解析路径：先展开 %VAR% 环境变量，再判断绝对 / 相对。
;   绝对路径（含盘符 C:\ 或 UNC \\server\share）—— 原样返回；
;   相对路径 —— 拼到 $sBase 下。
; 用于让配置里的目录既能填绝对路径，也能填「相对本程序」的相对路径。
Func Common_ResolvePath($sPath, $sBase)
    Local $s = StringStripWS($sPath, 3)
    If $s = "" Then Return ""

    $s = Common_ExpandEnv($s)

    If StringRegExp($s, "^[A-Za-z]:") Then Return Common_NormalizePath($s)   ; 盘符
    If StringLeft($s, 2) = "\\" Then Return Common_NormalizePath($s)         ; UNC

    Return Common_NormalizePath(Common_JoinPath($sBase, $s))
EndFunc

; 取文件所在目录（Chr(92) 即 "\"，避免字符串转义歧义）
Func Common_FileDir($sFile)
    Local $iPos = StringInStr($sFile, Chr(92), 0, -1)
    If $iPos > 1 Then Return StringLeft($sFile, $iPos - 1)
    Return ""
EndFunc

; 取路径的最后一段（文件名或文件夹名）
Func Common_FileName($sPath)
    Local $s = Common_NormalizePath($sPath)
    If $s = "" Then Return ""

    Local $iPos = StringInStr($s, Chr(92), 0, -1)
    If $iPos > 0 Then Return StringRight($s, StringLen($s) - $iPos)
    Return $s
EndFunc

; 在系统 PATH 中查找可执行文件（类似命令行的 where / which）。
; 传入的若本身就是完整路径，则直接判断该文件是否存在。
; 返回找到的完整路径；未找到返回空串。
Func Common_Which($sExeName)
    If $sExeName = "" Then Return ""

    If FileExists($sExeName) Then Return $sExeName

    Local $aDirs = StringSplit(EnvGet("PATH"), ";", $STR_ENTIRESPLIT)
    If Not IsArray($aDirs) Then Return ""

    Local $sDir, $sFull

    For $i = 1 To $aDirs[0]
        $sDir = StringStripWS($aDirs[$i], 3)
        $sDir = StringReplace($sDir, '"', "")       ; PATH 里可能有带引号的项
        If $sDir = "" Then ContinueLoop

        $sFull = Common_JoinPath($sDir, $sExeName)
        If FileExists($sFull) Then Return $sFull
    Next

    Return ""
EndFunc

; 判断目录是否已在某个以分号分隔的路径列表中（比较时忽略末尾分隔符与大小写）
Func Common_PathListHas($sList, $sDir)
    Local $sTarget = StringLower(Common_NormalizePath($sDir))
    If $sTarget = "" Then Return False

    Local $aItems = StringSplit($sList, ";", 1)
    For $i = 1 To $aItems[0]
        If StringLower(Common_NormalizePath($aItems[$i])) = $sTarget Then Return True
    Next
    Return False
EndFunc

; ==============================================================================
; 时间
; ==============================================================================

Func Common_DateStamp()
    Return @YEAR & @MON & @MDAY
EndFunc

Func Common_TimeStamp()
    Return @YEAR & @MON & @MDAY & "_" & @HOUR & @MIN & @SEC
EndFunc

Func Common_NowText()
    Return @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC
EndFunc

; 把秒数格式化成易读的时长，如 95 -> "1 分 35 秒"（用于等待心跳等提示）
Func Common_FormatDuration($iSeconds)
    If $iSeconds < 0 Then $iSeconds = 0

    Local $iMin = Int($iSeconds / 60)
    Local $iSec = Mod($iSeconds, 60)

    If $iMin = 0 Then Return $iSec & " 秒"
    Return $iMin & " 分 " & $iSec & " 秒"
EndFunc

; ==============================================================================
; 压缩包
; ==============================================================================

; 定位可用的 7-Zip 命令行程序（解压绿色版软件包时作为依赖使用）。
;
;   $sExtraDir  可选：额外在该目录下的 7zip\ 子目录里找一份绿色版 7z.exe。
;               调用方传「安装包目录」，因为它是可配置的，本模块不便直接读配置。
;
; 查找顺序与「已安装检测」保持一致：先查常见安装位置，再查整个系统 PATH ——
; 7-Zip 安装时可选择加入 PATH，也可能是绿色版直接挂在 PATH 上；
; 只查固定目录会漏判，白白退回到更慢的 PowerShell 解压。
Func Common_Find7Zip($sExtraDir = "")
    Local $sX86 = Common_ExpandEnv("%ProgramFiles(x86)%")

    Local $aCand[3]
    $aCand[0] = Common_JoinPath(Common_JoinPath(@ProgramFilesDir, "7-Zip"), $FILE_7ZIP_EXE)

    $aCand[1] = ""
    If $sX86 <> "" Then $aCand[1] = Common_JoinPath(Common_JoinPath($sX86, "7-Zip"), $FILE_7ZIP_EXE)

    $aCand[2] = ""
    If $sExtraDir <> "" Then
        $aCand[2] = Common_JoinPath(Common_JoinPath($sExtraDir, "7zip"), $FILE_7ZIP_EXE)
    EndIf

    For $i = 0 To UBound($aCand) - 1
        If $aCand[$i] <> "" And FileExists($aCand[$i]) Then Return $aCand[$i]
    Next

    ; 兜底：系统 PATH
    Return Common_Which($FILE_7ZIP_EXE)
EndFunc

; 把文本包装成 PowerShell 单引号字面量（内部的单引号需写成两个）
Func Common_PsQuote($sText)
    Return "'" & StringReplace($sText, "'", "''") & "'"
EndFunc

; ==============================================================================
; 外部命令
; ==============================================================================

; 当前正在等待的进程信息（供 Adlib 消息泵与超时控制使用）
Global $g_iRunPid     = 0
Global $g_iRunTimeout = 0
Global $g_hRunTimer   = 0

; 执行外部命令并等待其结束，等待期间保持界面响应。
;
; 原理：AutoIt 的 Sleep 期间消息队列仍会被处理，Adlib 函数照常触发；
;       ProcessWaitClose() 内部按 250ms 轮询并 Sleep，因此等待期间界面不会假死。
;
; 返回值：
;    >= 0               进程退出码
;    $RUN_ERR_START     命令启动失败
;    $RUN_ERR_TIMEOUT   等待超时，进程已被强制结束
Func Common_RunWait($sCmd, $sWorkDir = "", $iTimeoutMs = 0, $iShowFlag = @SW_HIDE)
    Local $iPid = Run($sCmd, $sWorkDir, $iShowFlag)
    If $iPid = 0 Then Return $RUN_ERR_START

    $g_iRunPid     = $iPid
    $g_iRunTimeout = $iTimeoutMs
    $g_hRunTimer   = TimerInit()
    AdlibRegister("Common_RunWait_Tick", $RUN_PUMP_MS)

    Local $iCode    = $RUN_ERR_TIMEOUT
    Local $bGotCode = False
    Local $iRet

    While True
        $iRet = ProcessWaitClose($iPid, $RUN_POLL_MS / 1000)
        If $iRet = 1 Then
            $iCode    = @extended
            $bGotCode = True
            ExitLoop
        EndIf

        If $g_sPumpFunc <> "" Then Call($g_sPumpFunc)   ; 再主动泵一次

        If $g_iRunPid = 0 Then ExitLoop                 ; 已因超时被结束
    WEnd

    AdlibUnRegister("Common_RunWait_Tick")
    $g_iRunPid = 0

    If Not $bGotCode Then Return $RUN_ERR_TIMEOUT
    If $iCode = $RUN_EXITED_BEFORE Then Return 0        ; 进程在等待前已退出
    Return $iCode
EndFunc

; Adlib 回调：维持界面响应 + 超时强杀
Func Common_RunWait_Tick()
    If $g_sPumpFunc <> "" Then Call($g_sPumpFunc)

    If $g_iRunTimeout > 0 And $g_iRunPid <> 0 Then
        If TimerDiff($g_hRunTimer) > $g_iRunTimeout Then
            ProcessClose($g_iRunPid)
            $g_iRunPid = 0
        EndIf
    EndIf
EndFunc
