; ==============================================================================
; Gui\Install.au3 —— 执行界面
; ------------------------------------------------------------------------------
; 职责：
;   · 先跑一遍前置检查（Precheck_RunAll），有问题时由操作员决定是否继续；
;   · 再逐项执行 Installer_RunAll()，实时显示进度条与日志；
;   · 通过 Common_SetPump() 注册消息泵，安装期间界面保持响应；
;   · 结束后给出「成功 / 跳过 / 失败」汇总。
;
; 日志框用 **RichEdit** 控件（不是普通 Edit），这样日志可以**按级别着色** ——
; 级别到颜色的映射在 Logger_LevelColor()，颜色常量是 Constants.au3 的 $LOG_COLOR_*。
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
#include <GuiRichEdit.au3>

#include "..\Constants.au3"
#include "..\Common.au3"
#include "..\Logger.au3"
#include "..\Config.au3"
#include "..\Installer.au3"
#include "..\Precheck.au3"

Global $g_hGuiRun       = 0
Global $g_idRunProgress = 0
Global $g_idRunInfo     = 0
Global $g_hRunLog       = 0         ; RichEdit 控件的**句柄**（不是 GUICtrl 的 ID）
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

; ------------------------------------------------------------------------------
; 等待心跳回调：由 Installer_WaitTick() 每秒调用一次
; 把「已等待 X 分 Y 秒」实时显示在信息标签上，让用户直观看到程序仍在工作。
; ------------------------------------------------------------------------------
Func GuiInstall_OnWaitTick($sLabel, $iSec)
    If $g_hGuiRun = 0 Then Return

    GUICtrlSetData($g_idRunInfo, $sLabel & "，已等待 " & Common_FormatDuration($iSec) & " ...")
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

    ; 日志框用 RichEdit（而不是普通 Edit）—— 只有 RichEdit 能逐段设置文字颜色，
    ; 从而让不同日志级别显示成不同颜色（颜色映射见 Logger_LevelColor()）。
    ; $iExStyle 用默认值（WS_EX_CLIENTEDGE），保持和普通编辑框一样的外观。
    $g_hRunLog = _GUICtrlRichEdit_Create($hGui, "", $UI_RUN_PAD, $UI_RUN_LOG_Y, $iWide, $UI_RUN_LOG_H, _
            BitOR($ES_MULTILINE, $ES_READONLY, $WS_VSCROLL, $ES_AUTOVSCROLL))
    _GUICtrlRichEdit_SetFont($g_hRunLog, $UI_FONT_SIZE, $UI_FONT_MONO)
    _GUICtrlRichEdit_SetReadOnly($g_hRunLog, True)

    $g_idRunOpenLog = GUICtrlCreateButton("打开日志目录", $UI_RUN_PAD, $UI_RUN_BTN_Y, _
            $UI_RUN_BTN_W, $UI_RUN_BTN_H)
    $g_idRunClose   = GUICtrlCreateButton("关闭", $UI_RUN_W - $UI_RUN_PAD - $UI_RUN_BTN_W, _
            $UI_RUN_BTN_Y, $UI_RUN_BTN_W, $UI_RUN_BTN_H)
    GUICtrlSetState($g_idRunClose, $GUI_DISABLE)

    GUISetState(@SW_SHOW, $hGui)

    ; 绑定日志输出与回调
    Logger_SetConsole($g_hRunLog)
    Common_SetPump("GuiInstall_Pump")
    Installer_SetNotify("GuiInstall_OnProgress")
    Installer_SetWaitNotify("GuiInstall_OnWaitTick")

    Logger_Write("==================== 开始执行 ====================")
    Logger_Info("软件名称：" & Config_SoftwareName())
    Logger_Info("安装根目录：" & Config_InstallRootReal())
    Logger_Info("安装包目录：" & Config_PackagesDirReal())
    Logger_Info("配置文件：" & Config_File())
    Logger_Info("日志文件：" & Logger_File())
    Logger_Info("待执行任务：" & $iCount & " 项")
    Logger_Write("")

    ; ---- 前置检查（交互模式下发现问题会弹窗确认，选择「否」则中止）----
    GUICtrlSetData($g_idRunInfo, "正在进行前置检查...")
    Local $bGo = Precheck_RunAll(Not $g_bRunAutoClose)

    ; ---- 逐项执行 ----
    Local $aStat[3] = [0, 0, 0]
    If $bGo Then $aStat = Installer_RunAll($aSelected, $iCount)

    Logger_Write("")
    Logger_Write("==================== 执行结束 ====================")

    If $bGo Then
        Logger_Write(StringFormat("成功 %d 项  |  跳过 %d 项  |  失败 %d 项", $aStat[0], $aStat[1], $aStat[2]))
    Else
        Logger_Warn("前置检查未通过，安装已中止（未执行任何安装任务）。")
        $aStat[2] = 1                   ; 中止也算失败，便于批处理按退出码判断
    EndIf

    If Not $bGo Then
        GUICtrlSetData($g_idRunProgress, 0)
        GUICtrlSetData($g_idRunInfo, "前置检查未通过，安装已中止")
    ElseIf $aStat[2] > 0 Then
        GUICtrlSetData($g_idRunProgress, 100)
        GUICtrlSetData($g_idRunInfo, "执行结束，存在失败项，请查看日志")
    Else
        GUICtrlSetData($g_idRunProgress, 100)
        GUICtrlSetData($g_idRunInfo, "全部执行完毕")
    EndIf

    Common_SetPump("")
    Installer_SetNotify("")
    Installer_SetWaitNotify("")

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
    _GUICtrlRichEdit_Destroy($g_hRunLog)    ; 释放 RichEdit 的 OLE 回调，再销毁窗口
    GUIDelete($hGui)
    $g_hGuiRun = 0
    $g_hRunLog = 0

    Return $aStat
EndFunc
