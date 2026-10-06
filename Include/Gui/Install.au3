; ==============================================================================
; Gui\Install.au3 —— 执行界面
; ------------------------------------------------------------------------------
; 职责：
;   · 逐项执行 Installer_RunAll()，实时显示进度条与日志；
;   · 通过 Common_SetPump() 注册消息泵，安装期间界面保持响应；
;   · 结束后给出「成功 / 跳过 / 失败」汇总。
;
; 布局尺寸 / 颜色 / 字体等一律取自 Constants.au3。
; ==============================================================================

#include-once

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ButtonConstants.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include <ProgressConstants.au3>
#include <GuiEdit.au3>

#include "..\Constants.au3"
#include "..\Common.au3"
#include "..\Logger.au3"
#include "..\Config.au3"
#include "..\Installer.au3"

Global $g_hGuiRun       = 0
Global $g_idRunProgress = 0
Global $g_idRunInfo     = 0
Global $g_idRunLog      = 0
Global $g_idRunOpenLog  = 0
Global $g_idRunClose    = 0

; 无人值守模式：执行结束后自动关闭（由主脚本设置）
Global $g_bRunAutoClose = False

; ------------------------------------------------------------------------------
; 消息泵：由 Common_RunWait() 在等待外部命令期间回调
; ------------------------------------------------------------------------------
Func GuiInstall_Pump()
    If $g_hGuiRun = 0 Then Return

    Switch GUIGetMsg()
        Case $g_idRunOpenLog
            GuiInstall_OpenLogDir()
    EndSwitch
EndFunc

; ------------------------------------------------------------------------------
; 进度回调：由 Installer_RunAll() 在每项开始前回调
; ------------------------------------------------------------------------------
Func GuiInstall_OnProgress($iIndex, $iTotal, $sName)
    If $g_hGuiRun = 0 Then Return

    GUICtrlSetData($g_idRunProgress, Int($iIndex * 100 / $iTotal))
    GUICtrlSetData($g_idRunInfo, StringFormat("(%d/%d) %s", $iIndex + 1, $iTotal, $sName))
    GuiInstall_Pump()
EndFunc

Func GuiInstall_OpenLogDir()
    ShellExecute(Common_JoinPath(Config_InstallRootReal(), $DIR_LOGS))
EndFunc

; ==============================================================================
; 入口：执行安装
; ==============================================================================
Func GuiInstall_Run($aSelected, $iCount)
    Local $hGui = GUICreate($APP_TITLE_RUN, $UI_RUN_W, $UI_RUN_H, -1, -1, _
            BitOR($WS_CAPTION, $WS_SYSMENU))
    GUISetFont($UI_FONT_SIZE, 400, 0, $UI_FONT_UI)
    GUISetBkColor($UI_COLOR_BG, $hGui)
    $g_hGuiRun = $hGui

    Local $iWide = $UI_RUN_W - 2 * $UI_RUN_PAD

    Local $idTitle = GUICtrlCreateLabel("正在执行安装任务", $UI_RUN_PAD, 16, 420, 24)
    GUICtrlSetFont($idTitle, $UI_FONT_SIZE_S, 700, 0, $UI_FONT_UI)

    Local $idRoot = GUICtrlCreateLabel("安装根目录：" & Config_InstallRootReal(), $UI_RUN_PAD, 44, $iWide, 18)
    GUICtrlSetColor($idRoot, $UI_COLOR_TEXT)

    $g_idRunProgress = GUICtrlCreateProgress($UI_RUN_PAD, 72, $iWide, $UI_RUN_PROGRESS_H, $PBS_SMOOTH)

    $g_idRunInfo = GUICtrlCreateLabel("准备中...", $UI_RUN_PAD, 96, $iWide, 20)
    GUICtrlSetColor($g_idRunInfo, $UI_COLOR_TEXT)

    $g_idRunLog = GUICtrlCreateEdit("", $UI_RUN_PAD, $UI_RUN_LOG_Y, $iWide, $UI_RUN_LOG_H, _
            BitOR($ES_MULTILINE, $ES_READONLY, $WS_VSCROLL, $ES_AUTOVSCROLL))
    GUICtrlSetFont($g_idRunLog, $UI_FONT_SIZE, 400, 0, $UI_FONT_MONO)

    $g_idRunOpenLog = GUICtrlCreateButton("打开日志目录", $UI_RUN_PAD, $UI_RUN_BTN_Y, _
            $UI_RUN_BTN_W, $UI_RUN_BTN_H)
    $g_idRunClose   = GUICtrlCreateButton("关闭", $UI_RUN_W - $UI_RUN_PAD - $UI_RUN_BTN_W, _
            $UI_RUN_BTN_Y, $UI_RUN_BTN_W, $UI_RUN_BTN_H)
    GUICtrlSetState($g_idRunClose, $GUI_DISABLE)

    GUISetState(@SW_SHOW, $hGui)

    ; 绑定日志输出与回调
    Logger_SetConsole($g_idRunLog)
    Common_SetPump("GuiInstall_Pump")
    Installer_SetNotify("GuiInstall_OnProgress")

    Logger_Write("==================== 开始执行 ====================")
    Logger_Info("软件名称：" & Config_SoftwareName())
    Logger_Info("安装根目录：" & Config_InstallRootReal())
    Logger_Info("安装包目录：" & Config_PackagesDirReal())
    Logger_Info("配置文件：" & Config_File())
    Logger_Info("日志文件：" & Logger_File())
    Logger_Info("待执行任务：" & $iCount & " 项")
    Logger_Write("")

    ; ---- 逐项执行 ----
    Local $aStat = Installer_RunAll($aSelected, $iCount)

    Logger_Write("")
    Logger_Write("==================== 执行结束 ====================")
    Logger_Write(StringFormat("成功 %d 项  |  跳过 %d 项  |  失败 %d 项", $aStat[0], $aStat[1], $aStat[2]))

    GUICtrlSetData($g_idRunProgress, 100)
    If $aStat[2] > 0 Then
        GUICtrlSetData($g_idRunInfo, "执行结束，存在失败项，请查看日志")
    Else
        GUICtrlSetData($g_idRunInfo, "全部执行完毕")
    EndIf

    Common_SetPump("")
    Installer_SetNotify("")

    GUICtrlSetState($g_idRunClose, $GUI_ENABLE)
    GUICtrlSetState($g_idRunClose, $GUI_FOCUS)

    ; ---- 结果窗口消息循环 ----
    If $g_bRunAutoClose Then
        Sleep($UI_RUN_AUTOCLOSE_WAIT)
    Else
        While True
            Switch GUIGetMsg()
                Case $GUI_EVENT_CLOSE, $g_idRunClose
                    ExitLoop
                Case $g_idRunOpenLog
                    GuiInstall_OpenLogDir()
            EndSwitch
            Sleep(20)
        WEnd
    EndIf

    Logger_SetConsole(0)
    GUIDelete($hGui)
    $g_hGuiRun = 0

    Return $aStat
EndFunc
