; ==============================================================================
; Logger.au3 —— 日志模块
; ------------------------------------------------------------------------------
; 日志同时写入两个位置：
;   1. 日志文件（UTF-8，追加写），路径由 Logger_Init() 指定；
;   2. GUI 日志框（可选），通过 Logger_SetConsole() 绑定一个 **RichEdit 控件句柄**。
;
; 界面上的日志**按级别着色**：RichEdit 控件支持逐段设置文字颜色，
; 级别 → 颜色的映射见 Logger_LevelColor()，颜色常量见 Constants.au3 的 $LOG_COLOR_*。
; 文件里仍是纯文本，不带颜色。
;
; 【着色位置怎么算】不要用 `_GUICtrlRichEdit_GetTextLength()` 去算 SetSel 的位置 ——
; RichEdit 的「字符数」有好几套口径，混用会导致**日志逐行串色**（详见 Logger_Write 内注释）。
; 现在用 `$g_iLogConsoleEnd` 记录末尾位置，每次追加后用 `_GUICtrlRichEdit_GetSel()` 更新，
; 着色区间取 `[上次末尾, 本次末尾)`，与 SetSel 用同一套坐标，中英文混排也不会错位。
; ==============================================================================

#include-once

#include <FileConstants.au3>
#include <GuiRichEdit.au3>

#include "Constants.au3"
#include "Common.au3"

Global $g_sLogFile    = ""
Global $g_hLogConsole = 0
Global $g_iLogConsoleEnd = 0    ; 日志框里文本的**末尾字符位置**（用 RichEdit 自己的坐标系）

; 指定日志文件路径（自动创建所在目录）
Func Logger_Init($sFile)
    $g_sLogFile = $sFile

    If $g_sLogFile <> "" Then
        Local $sDir = Common_FileDir($g_sLogFile)
        If $sDir <> "" Then Common_EnsureDir($sDir)
    EndIf
EndFunc

Func Logger_File()
    Return $g_sLogFile
EndFunc

; 绑定 GUI 日志框（RichEdit 控件句柄，传 0 解绑）
Func Logger_SetConsole($hRichEdit)
    $g_hLogConsole = $hRichEdit

    ; 重新绑定时把「末尾位置」复位到控件当前的真实末尾 ——
    ; 换了控件（或清空过）再继续写时，位置必须重新对齐，否则上色会错位。
    If $hRichEdit <> 0 Then
        Local $aSel = _GUICtrlRichEdit_GetSel($hRichEdit)
        $g_iLogConsoleEnd = $aSel[1]
    Else
        $g_iLogConsoleEnd = 0
    EndIf
EndFunc

; 日志级别 → 界面文字颜色（RGB）
Func Logger_LevelColor($sLevel)
    Switch $sLevel
        Case $LOG_LEVEL_OK
            Return $LOG_COLOR_OK
        Case $LOG_LEVEL_WARN
            Return $LOG_COLOR_WARN
        Case $LOG_LEVEL_ERROR
            Return $LOG_COLOR_ERROR
        Case $LOG_LEVEL_STEP
            Return $LOG_COLOR_STEP
        Case $LOG_LEVEL_INFO
            Return $LOG_COLOR_INFO
        Case Else
            Return $LOG_COLOR_DEFAULT
    EndSwitch
EndFunc

; RGB → COLORREF(BGR)。
; AutoIt 的 GUI 函数（GUICtrlSetColor 等）用 RGB 写法，而 RichEdit / GDI 的
; COLORREF 是 0x00BBGGRR —— _GUICtrlRichEdit_SetCharColor 直接把它塞进
; CHARFORMAT.crTextColor，所以必须先在这里换字节序，否则红蓝会互换。
Func Logger_RgbToColorRef($iRgb)
    Return BitOR(BitShift(BitAND($iRgb, 0xFF0000), 16), _
            BitAND($iRgb, 0x00FF00), _
            BitShift(BitAND($iRgb, 0x0000FF), -16))
EndFunc

Func Logger_Write($sMsg, $sLevel = $LOG_LEVEL_INFO)
    Local $sLine = "[" & Common_NowText() & "] [" & _
            StringFormat("%-" & $LOG_LEVEL_WIDTH & "s", $sLevel) & "] " & $sMsg

    If $g_sLogFile <> "" Then
        Local $hFile = FileOpen($g_sLogFile, BitOR($FO_APPEND, $FO_UTF8_NOBOM))
        If $hFile <> -1 Then
            FileWriteLine($hFile, $sLine)
            FileClose($hFile)
        EndIf
    EndIf

    ; 界面：RichEdit 按级别着色。
    ;
    ; 【顺序很重要】不能「先设色再追加」—— 在折叠光标上用 SCF_SELECTION 设格式时，
    ; RichEdit 作用的是光标**前面**那个字符，结果整片日志的颜色会错位一行。
    ; 正确做法：先追加，再选中刚追加的那一段，然后给它上色。
    ;
    ; 【串色（颜色错位）是怎么来的】—— 这里踩过一个大坑，务必看清：
    ;   RichEdit 有**三套不一样的字符计数**，混用就会逐行累积偏移，表现为「某一行开始串色」：
    ;     ① `_GUICtrlRichEdit_GetTextLength($h, True, True)` —— 它不是纯字符数，
    ;        **每个多字节字符（中文）会多算 1**。实测一行含 3 个中文时报 43，真实长度是 40。
    ;     ② `StringLen(GetText(...))` —— 把行尾的 `@CRLF` 当成 **2** 个字符。
    ;     ③ `SetSel` / `GetSel` 用的**内部坐标** —— 把行尾 `@CRLF` 当成 **1** 个字符、
    ;        中文按 RichEdit 内部编码占位。**只有这一套是 SetSel 认的。**
    ;   老代码用 ① 算起点、交给 ③ 去 SetSel，两套坐标差着「中文个数」，于是
    ;   第 2 行起每行都偏移，越往后偏得越多 —— 这就是「串色」。
    ;
    ;   修法：**不再自己算位置**，改成追加后用 `_GUICtrlRichEdit_GetSel()` 读回真实末尾
    ;   （追加后光标就在末尾），着色区间取 `[上次末尾, 本次末尾)`。
    ;   全程只用 ③ 这一套坐标，天然对齐，中英文混排也不会错位。
    If $g_hLogConsole <> 0 Then
        Local $iStart = $g_iLogConsoleEnd

        _GUICtrlRichEdit_AppendText($g_hLogConsole, $sLine & @CRLF)

        ; 追加后选择末端就在新文本末尾 —— 这就是本次追加的结束位置
        Local $aSel = _GUICtrlRichEdit_GetSel($g_hLogConsole)
        Local $iEnd = $aSel[1]
        $g_iLogConsoleEnd = $iEnd

        _GUICtrlRichEdit_SetSel($g_hLogConsole, $iStart, $iEnd)
        _GUICtrlRichEdit_SetCharColor($g_hLogConsole, Logger_RgbToColorRef(Logger_LevelColor($sLevel)))
        _GUICtrlRichEdit_Deselect($g_hLogConsole)
        _GUICtrlRichEdit_ScrollToCaret($g_hLogConsole)
    EndIf
EndFunc

Func Logger_Info($sMsg)
    Logger_Write($sMsg, $LOG_LEVEL_INFO)
EndFunc

Func Logger_Ok($sMsg)
    Logger_Write($sMsg, $LOG_LEVEL_OK)
EndFunc

Func Logger_Warn($sMsg)
    Logger_Write($sMsg, $LOG_LEVEL_WARN)
EndFunc

Func Logger_Err($sMsg)
    Logger_Write($sMsg, $LOG_LEVEL_ERROR)
EndFunc

Func Logger_Step($sMsg)
    Logger_Write($sMsg, $LOG_LEVEL_STEP)
EndFunc
