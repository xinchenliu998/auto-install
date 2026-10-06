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
; ==============================================================================

#include-once

#include <FileConstants.au3>
#include <GuiRichEdit.au3>

#include "Constants.au3"
#include "Common.au3"

Global $g_sLogFile    = ""
Global $g_hLogConsole = 0

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
    ; 【坑】_GUICtrlRichEdit_GetTextLength() 默认返回的是**字节数**（$bChars=False
    ; 走的是 GTL_NUMBYTES），而 SetSel 用的是**字符位置** —— 不传 $bChars=True 的话
    ; 偏移会翻倍，选择落到文本末尾之外被钳制，等于什么都没选中。
    If $g_hLogConsole <> 0 Then
        Local $iStart = _GUICtrlRichEdit_GetTextLength($g_hLogConsole, True, True)

        _GUICtrlRichEdit_AppendText($g_hLogConsole, $sLine & @CRLF)

        _GUICtrlRichEdit_SetSel($g_hLogConsole, $iStart, -1)    ; -1 = 到文本末尾
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
