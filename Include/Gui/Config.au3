; ==============================================================================
; Gui\Config.au3 —— 配置窗口（入口 + 消息循环）
; ------------------------------------------------------------------------------
; 本文件是配置界面的「入口」：
;   · 提供入口 GuiConfig_Show()；
;   · 跑消息循环，把事件分派给界面构建 / 状态同步 / 列表控件三个子模块。
;
; 同目录下的子模块分工：
;   Gui\ConfigShared.au3   控件 ID 与界面状态（**只声明变量**，其他文件各自 include）
;   Gui\ConfigLayout.au3   界面构建（把控件摆出来）
;   Gui\ConfigState.au3    状态同步与校验回写
;   Gui\PackageList.au3    软件列表控件（带复选框的 ListView）
;
; 窗口尺寸固定（见 Constants.au3 的 $UI_CFG_WIN_H），软件数量变化不影响布局。
; ==============================================================================

#include-once

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>

#include "..\Constants.au3"
#include "..\Common.au3"
#include "..\Logger.au3"
#include "..\Config.au3"

; ------------------------------------------------------------------------------
; 子模块（共享声明与各子模块都自带 #include-once，顺序无关）
; ------------------------------------------------------------------------------
#include "ConfigShared.au3"
#include "PackageList.au3"
#include "ConfigLayout.au3"
#include "ConfigState.au3"

; ==============================================================================
; 入口：显示配置界面
; 返回 True  —— 用户点击了「开始安装」（配置已保存）
; 返回 False —— 用户关闭窗口 / 点击退出
; ==============================================================================
Func GuiConfig_Show()
    ; ---- 初始「根目录是否自动跟随」状态 ----
    $g_sLastAutoRoot = Config_InstallRoot()
    If $g_sLastAutoRoot = Config_DefaultRoot(Config_SoftwareName()) Then
        $g_bRootAuto = True
    Else
        $g_bRootAuto = False
    EndIf

    ; ---- 创建窗口（尺寸固定，不随软件数量变化）----
    $g_hGuiCfg = GUICreate($APP_TITLE, $UI_CFG_W, $UI_CFG_WIN_H, -1, -1, _
            BitOR($WS_CAPTION, $WS_SYSMENU, $WS_MINIMIZEBOX))
    GUISetFont($UI_FONT_SIZE, 400, 0, $UI_FONT_UI)
    GUISetBkColor($UI_COLOR_BG, $g_hGuiCfg)

    GuiConfigLayout_CreateHeader()
    GuiConfigLayout_CreateBasicGroup()
    GuiConfigLayout_CreatePackageGroup()
    GuiConfigLayout_CreateBottomBar()

    ; ---- 初始值 ----
    GuiPackageList_Fill()
    GuiConfigState_SyncHint()
    GuiConfig_InitStatus()

    GUISetState(@SW_SHOW, $g_hGuiCfg)

    ; ---- 消息循环 ----
    Local $bStart = False
    Local $iIdle = 0
    Local $iMsg, $sDir, $sAuto

    While True
        $iMsg = GUIGetMsg()

        Switch $iMsg
            Case $GUI_EVENT_CLOSE, $g_idExit
                ExitLoop

            Case $g_idBrowse
                $sDir = GuiConfig_SelectFolder("选择安装根目录", GUICtrlRead($g_idRoot))
                If $sDir <> "" Then
                    GUICtrlSetData($g_idRoot, $sDir)
                    $g_bRootAuto = False
                EndIf

            Case $g_idRootDefault
                $sAuto = Config_DefaultRoot(GUICtrlRead($g_idName))
                GUICtrlSetData($g_idRoot, $sAuto)
                $g_bRootAuto = True
                $g_sLastAutoRoot = $sAuto

            Case $g_idPkgBrowse
                $sDir = GuiConfig_SelectFolder("选择安装包目录", GUICtrlRead($g_idPkgDir))
                If $sDir <> "" Then
                    GUICtrlSetData($g_idPkgDir, $sDir)
                    GuiConfigState_ReloadPackages()
                EndIf

            Case $g_idPkgReload
                GuiConfigState_ReloadPackages()

            Case $g_idCopySrcBrowse
                $sDir = GuiConfig_SelectFolder("选择拷贝源目录（文档、驱动等）", GUICtrlRead($g_idCopySrc))
                If $sDir <> "" Then GUICtrlSetData($g_idCopySrc, $sDir)

            Case $g_idCopyDstBrowse
                $sDir = GuiConfig_SelectFolder("选择拷贝目标目录", GUICtrlRead($g_idCopyDst))
                If $sDir <> "" Then GUICtrlSetData($g_idCopyDst, $sDir)

            Case $g_idSelectAll
                GuiPackageList_SetAll(True)

            Case $g_idSelectNone
                GuiPackageList_SetAll(False)

            Case $g_idSelectInvert
                GuiPackageList_Invert()

            Case $g_idSave
                If GuiConfigState_Apply() Then
                    If Config_Save() Then
                        GuiConfigState_SetStatus("配置已保存")
                    Else
                        GuiConfigState_SetStatus("配置保存失败，请检查写入权限。")
                    EndIf
                EndIf

            Case $g_idStart
                If GuiConfigState_Apply() Then
                    If Config_Save() Then
                        $bStart = True
                        ExitLoop
                    Else
                        MsgBox($MB_ERROR, $APP_TITLE, "配置保存失败，无法开始安装。" & @CRLF & Config_File())
                    EndIf
                EndIf
        EndSwitch

        ; 空闲时：同步根目录、刷新提示、刷新勾选计数
        $iIdle += 1
        If $iIdle >= 3 Then
            $iIdle = 0
            GuiConfigState_SyncRoot()
            GuiConfigState_SyncHint()
            GuiPackageList_UpdateCount()
        EndIf

        Sleep(20)
    WEnd

    GUIDelete($g_hGuiCfg)
    $g_hGuiCfg = 0

    Return $bStart
EndFunc

; ==============================================================================
; 内部辅助
; ==============================================================================

; 状态栏宽度有限，只放短状态；完整说明放悬停提示
Func GuiConfig_InitStatus()
    If Common_IsElevated() Then
        GuiConfigState_SetStatus("权限：管理员")
        GUICtrlSetTip($g_idStatus, "当前以管理员权限运行，可直接执行全部安装任务")
    Else
        GuiConfigState_SetStatus("权限：普通用户")
        GUICtrlSetTip($g_idStatus, "点「开始安装」时会询问是否以管理员身份重新启动；" & _
                "选择否将以当前权限执行，部分任务可能失败")
    EndIf
EndFunc

; 选目录；当前值无效时退回脚本所在目录
Func GuiConfig_SelectFolder($sTitle, $sCurrent)
    Local $sStart = Common_NormalizePath($sCurrent)
    If $sStart = "" Or Not FileExists($sStart) Then $sStart = @ScriptDir
    Return FileSelectFolder($sTitle, $sStart, 0)
EndFunc
