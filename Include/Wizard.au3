; ==============================================================================
; Wizard.au3 —— 安装向导 GUI 自动化的通用助手
; ------------------------------------------------------------------------------
; 谁在用：Include\Install\halcon.au3（MVTec HALCON）。
; 该安装包不支持静默安装，改用「自动操作图形安装向导」。
;
; 本模块只放**与具体软件无关**的动作：
;   · 按「类名 + 文字子串（+ 可用状态）」在窗口里找控件句柄；
;   · 把整窗控件清单 Dump 进日志（换安装包版本后核对页面用）；
;   · 读复选框 / 单选框的勾选状态（BM_GETCHECK）；
;   · 按候选文字找 / 点按钮；
;   · 等页面标题变化。
;
; 【为什么必须按「文字」找控件，而不是 `[ID:n]`】
;   NSIS 的 InstallOptions 插件按页递增分配控件 ID（1200/1201…），会和窗口固定控件
;   （标题、页脚、按钮）**撞号**。实测 HALCON 许可页有**两个 id=1034**：一个是固定的
;   Static 标签，另一个才是「I accept」复选框 —— `[ID:1034]` 只会命中先枚举到的那个
;   Static，点它毫无作用。所以一律用 Wizard_FindCtrl() 按类名 + 文字取句柄。
;
; 【不属于本模块】弹框处理、安装阶段等待、各软件的页面分派 —— 那些带软件特性
;   （HALCON 的 VSIX 窗口），留在各自的 Install 模块里。
;
; 【分层】本模块只依赖 Constants.au3 / Logger.au3（Dump 要写日志），
;   不依赖 Installer / Config —— 避免基础层反向依赖业务层。
; ==============================================================================

#include-once

#include "Constants.au3"
#include "Logger.au3"

; ------------------------------------------------------------------------------
; 读控件属性：text / class / id / vis / ena
;   vis / ena 返回 1 / 0；text / class 返回字符串；id 返回整数。
; ------------------------------------------------------------------------------
Func Wizard_CtrlInfo($h, $sItem)
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

; ------------------------------------------------------------------------------
; 按「类名 + 文字子串（+ 可选：必须处于可用状态）」在窗口里找**控件句柄**。
; 找不到返回 0。$sTextPart 为空串时表示「不限定文字」。
; ------------------------------------------------------------------------------
Global $g_hWzFind     = 0
Global $g_sWzFindCls  = ""
Global $g_sWzFindText = ""
Global $g_bWzFindEna  = False

Func Wizard_FindProc($h, $l)
    #forceref $l
    If $g_hWzFind <> 0 Then Return 0                       ; 已找到，停止枚举
    If Wizard_CtrlInfo($h, "class") <> $g_sWzFindCls Then Return 1
    If Wizard_CtrlInfo($h, "vis") <> 1 Then Return 1
    If $g_bWzFindEna And Wizard_CtrlInfo($h, "ena") <> 1 Then Return 1
    If $g_sWzFindText <> "" And StringInStr(Wizard_CtrlInfo($h, "text"), $g_sWzFindText) = 0 Then Return 1
    $g_hWzFind = $h
    Return 0
EndFunc

Func Wizard_FindCtrl($hWin, $sClass, $sTextPart, $bNeedEnabled = False)
    $g_hWzFind     = 0
    $g_sWzFindCls  = $sClass
    $g_sWzFindText = $sTextPart
    $g_bWzFindEna  = $bNeedEnabled

    Local $hProc = DllCallbackRegister("Wizard_FindProc", "int", "hwnd;lparam")
    DllCall("user32.dll", "bool", "EnumChildWindows", "hwnd", $hWin, _
            "ptr", DllCallbackGetPtr($hProc), "lparam", 0)
    DllCallbackFree($hProc)

    Return $g_hWzFind
EndFunc

; ------------------------------------------------------------------------------
; 排障用：把窗口及其所有子控件（序号 / 控件 ID / 类名 / 可见 / 可用 / 文字）
; 写进日志。向导页面变了、按钮文字改了的时候，靠它一次看清全部控件。
; ------------------------------------------------------------------------------
Global $g_sWzDump = ""
Global $g_iWzDump = 0

Func Wizard_DumpProc($h, $l)
    #forceref $l
    $g_iWzDump += 1
    $g_sWzDump &= "    [" & StringFormat("%02d", $g_iWzDump) & "] id=" & _
            StringFormat("%-6d", Wizard_CtrlInfo($h, "id")) & _
            " vis=" & Wizard_CtrlInfo($h, "vis") & _
            " ena=" & Wizard_CtrlInfo($h, "ena") & _
            " " & StringFormat("%-20s", Wizard_CtrlInfo($h, "class")) & _
            " [" & Wizard_CtrlInfo($h, "text") & "]" & @CRLF
    Return 1
EndFunc

Func Wizard_LogControls($hWin, $sTag = "")
    $g_sWzDump = ""
    $g_iWzDump = 0
    Local $hProc = DllCallbackRegister("Wizard_DumpProc", "int", "hwnd;lparam")
    DllCall("user32.dll", "bool", "EnumChildWindows", "hwnd", $hWin, _
            "ptr", DllCallbackGetPtr($hProc), "lparam", 0)
    DllCallbackFree($hProc)

    Local $sHead = WinGetTitle($hWin)
    If $sTag <> "" Then $sHead = $sTag & "：" & $sHead
    Logger_Info("    ---- " & $sHead & " 的控件清单（" & $g_iWzDump & " 个）----")
    Logger_Info($g_sWzDump)
EndFunc

; ------------------------------------------------------------------------------
; 读 Button（复选框 / 单选框）的勾选状态（BM_GETCHECK，1 = 选中）。
; 注意：只对标准 Win32 按钮有效；自绘控件读出来恒为 0，别拿它当判据。
; ------------------------------------------------------------------------------
Func Wizard_BmGetCheck($h)
    Local $a = DllCall("user32.dll", "int", "SendMessageW", "hwnd", $h, "uint", 0x00F0, "wparam", 0, "lparam", 0)
    Return $a[0]
EndFunc

; ------------------------------------------------------------------------------
; 按候选文字依次找按钮；找到返回句柄，都没有返回 0。
;   $aTexts        候选文字数组（按安装器实际文字写，逐个试）
;   $bNeedEnabled  是否要求按钮可用（默认 True）
; ------------------------------------------------------------------------------
Func Wizard_FindButton($hWin, $aTexts, $bNeedEnabled = True)
    Local $h
    For $i = 0 To UBound($aTexts) - 1
        If $aTexts[$i] = "" Then ContinueLoop
        $h = Wizard_FindCtrl($hWin, "Button", $aTexts[$i], $bNeedEnabled)
        If $h <> 0 Then Return $h
    Next
    Return 0
EndFunc

; 按候选文字依次找按钮并点击；点了返回 True。
Func Wizard_ClickButton($hWin, $aTexts, $bNeedEnabled = True)
    Local $h = Wizard_FindButton($hWin, $aTexts, $bNeedEnabled)
    If $h = 0 Then Return False
    ControlClick($hWin, "", $h)
    Return True
EndFunc

; ------------------------------------------------------------------------------
; 找文字含指定片段的可见按钮（复选框 / 单选框）并勾选；已是勾选状态就不动。
; 找不到返回 False（**不报错**：很多安装器这一页根本没有复选框）。
; ------------------------------------------------------------------------------
Func Wizard_CheckByText($hWin, $sTextPart)
    Local $h = Wizard_FindCtrl($hWin, "Button", $sTextPart, True)
    If $h = 0 Then Return False
    If Wizard_BmGetCheck($h) <> 1 Then
        ControlClick($hWin, "", $h)
        Sleep(300)
    EndIf
    Return True
EndFunc

; ------------------------------------------------------------------------------
; 等「页面标题控件」的文字变化；窗口消失也视为变化（安装器可能自行收尾）。
; ------------------------------------------------------------------------------
Func Wizard_WaitPageChange($hWin, $sCtrlId, $sOldPage, $iTimeoutMs)
    Local $iTick = TimerInit()
    While TimerDiff($iTick) < $iTimeoutMs
        Sleep(500)
        If Not WinExists($hWin) Then Return True
        If ControlGetText($hWin, "", $sCtrlId) <> $sOldPage Then Return True
    WEnd
    Return False
EndFunc
