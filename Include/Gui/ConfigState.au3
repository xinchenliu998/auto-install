; ==============================================================================
; Gui\ConfigState.au3 —— 配置窗口的状态同步与校验
; ------------------------------------------------------------------------------
; 负责「界面 <-> 配置对象」的来回搬运：
;   · 提示行刷新（实际路径 / 安装包目录 / 日志文件）；
;   · 安装根目录跟随软件名称自动变化；
;   · 状态栏文案；
;   · 切换安装包目录后重新扫描并重填列表；
;   · 把界面内容校验后写回配置对象。
;
; 控件 ID 与状态变量在 Gui\Config.au3 里声明。
; ==============================================================================

#include-once

#include "..\Constants.au3"
#include "..\Common.au3"
#include "..\Logger.au3"
#include "..\Config.au3"
#include "PackageList.au3"

; ------------------------------------------------------------------------------
; 安装根目录跟随软件名称自动变化（用户手动改过就停止跟随）
; ------------------------------------------------------------------------------
Func GuiConfigState_SyncRoot()
    If $g_hGuiCfg = 0 Then Return

    Local $sRoot = GUICtrlRead($g_idRoot)
    Local $sAuto = Config_DefaultRoot(GUICtrlRead($g_idName))

    If Not $g_bRootAuto Then Return

    If $sRoot <> $g_sLastAutoRoot Then
        $g_bRootAuto = False            ; 用户手动修改过，停止跟随
    ElseIf $sRoot <> $sAuto Then
        GUICtrlSetData($g_idRoot, $sAuto)
        $g_sLastAutoRoot = $sAuto
    EndIf
EndFunc

; ------------------------------------------------------------------------------
; 刷新几行灰色提示
; ------------------------------------------------------------------------------
Func GuiConfigState_SyncHint()
    If $g_hGuiCfg = 0 Then Return

    Local $sRoot = Common_NormalizePath(GUICtrlRead($g_idRoot))
    If $sRoot = "" Then $sRoot = Common_NormalizePath(Config_DefaultRoot(GUICtrlRead($g_idName)))

    Local $s1 = "实际路径：" & $sRoot
    If $s1 <> $g_sHintRoot Then
        GUICtrlSetData($g_idRootHint, $s1)
        $g_sHintRoot = $s1
    EndIf

    Local $sPkg = Common_ResolvePath(GUICtrlRead($g_idPkgDir), @ScriptDir)
    Local $s2 = "安装包目录：" & $sPkg
    If $s2 <> $g_sHintPkg Then
        GUICtrlSetData($g_idPkgHint, $s2)
        $g_sHintPkg = $s2
    EndIf

    Local $s3 = "日志文件：" & Common_JoinPath(Common_JoinPath($sRoot, $DIR_LOGS), $g_sLogFileName)
    If $s3 <> $g_sHintLog Then
        GUICtrlSetData($g_idLogHint, $s3)
        $g_sHintLog = $s3
    EndIf
EndFunc

Func GuiConfigState_SetStatus($sText)
    If $sText = $g_sStatusText Then Return
    $g_sStatusText = $sText
    GUICtrlSetData($g_idStatus, $sText)
EndFunc

; ------------------------------------------------------------------------------
; 切换安装包目录后：重扫 -> 重填列表（布局完全不变）
; ------------------------------------------------------------------------------
Func GuiConfigState_ReloadPackages()
    If $g_hGuiCfg = 0 Then Return

    Config_SetPackagesDir(GUICtrlRead($g_idPkgDir))
    Config_RescanPackages()
    GuiPackageList_Fill()
    GuiConfigState_SyncHint()
EndFunc

; ------------------------------------------------------------------------------
; 把界面上的内容校验后写回配置对象；返回 False 表示校验未通过
; ------------------------------------------------------------------------------
Func GuiConfigState_Apply()
    Local $sName = StringStripWS(GUICtrlRead($g_idName), 3)
    If $sName = "" Then
        MsgBox($MB_WARN, $APP_TITLE, "请填写软件名称。")
        GUICtrlSetState($g_idName, $GUI_FOCUS)
        Return False
    EndIf

    If StringInStr($sName, "\") Or StringInStr($sName, "/") Or StringInStr($sName, ":") Then
        MsgBox($MB_WARN, $APP_TITLE, "软件名称不能包含 \ / : 等路径字符。")
        GUICtrlSetState($g_idName, $GUI_FOCUS)
        Return False
    EndIf

    Local $sRoot = StringStripWS(GUICtrlRead($g_idRoot), 3)
    If $sRoot = "" Then
        MsgBox($MB_WARN, $APP_TITLE, "请填写安装根目录。")
        GUICtrlSetState($g_idRoot, $GUI_FOCUS)
        Return False
    EndIf

    Local $sPkgDir = StringStripWS(GUICtrlRead($g_idPkgDir), 3)
    If $sPkgDir = "" Then
        MsgBox($MB_WARN, $APP_TITLE, "请填写安装包目录。")
        GUICtrlSetState($g_idPkgDir, $GUI_FOCUS)
        Return False
    EndIf

    ; 安装包目录被手改过但没点「刷新」时，这里补一次扫描，免得列表与实际目录不符
    If $sPkgDir <> Config_PackagesDir() Then GuiConfigState_ReloadPackages()

    Config_SetSoftwareName($sName)
    Config_SetInstallRoot($sRoot)
    Config_SetPackagesDir($sPkgDir)
    Config_SetCopySource(GUICtrlRead($g_idCopySrc))
    Config_SetCopyDest(GUICtrlRead($g_idCopyDst))

    GuiPackageList_WriteToConfig()

    Return True
EndFunc
