; ==============================================================================
; Logger.au3 —— 日志模块
; ------------------------------------------------------------------------------
; 日志同时写入两个位置：
;   1. 日志文件（UTF-8，追加写），路径由 Logger_Init() 指定；
;   2. GUI 日志框（可选），通过 Logger_SetConsole() 绑定一个 Edit 控件。
; ==============================================================================

#include-once

#include <FileConstants.au3>
#include <GuiEdit.au3>

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

; 绑定 GUI 日志框控件（传 0 解绑）
Func Logger_SetConsole($hEdit)
    $g_hLogConsole = $hEdit
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

    If $g_hLogConsole <> 0 Then _GUICtrlEdit_AppendText($g_hLogConsole, $sLine & @CRLF)
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
