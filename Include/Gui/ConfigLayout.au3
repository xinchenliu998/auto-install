; ==============================================================================
; Gui\ConfigLayout.au3 —— 配置窗口的界面构建
; ------------------------------------------------------------------------------
; 只负责「把控件摆出来」，不处理交互、不做状态同步、不写配置。
;
; 布局全部取自 Constants.au3 的静态常量，尺寸固定，不做任何动态计算。
; 控件 ID 写进 Gui\Config.au3 里声明的全局变量，供消息循环与状态同步使用。
; ==============================================================================

#include-once

#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include <ButtonConstants.au3>

#include "..\Constants.au3"
#include "..\Common.au3"
#include "..\Config.au3"
#include "PackageList.au3"

; ------------------------------------------------------------------------------
; 标题区
; ------------------------------------------------------------------------------
Func GuiConfigLayout_CreateHeader()
    Local $idTitle = GUICtrlCreateLabel($APP_TITLE, 22, 16, 420, 26)
    GUICtrlSetFont($idTitle, $UI_FONT_SIZE_H, 700, 0, $UI_FONT_UI)

    Local $idSub = GUICtrlCreateLabel("工控机出厂自动化工具集  ·  v" & $APP_VERSION, 24, 44, 420, 18)
    GUICtrlSetColor($idSub, $UI_COLOR_SUBTEXT)
EndFunc

; ------------------------------------------------------------------------------
; 基本配置组：5 行输入 + 4 行灰色提示
; ------------------------------------------------------------------------------
Func GuiConfigLayout_CreateBasicGroup()
    Local $iGrpW = $UI_CFG_W - 2 * $UI_CFG_MARGIN
    Local $iRowY

    GUICtrlCreateGroup(" 基本配置 ", $UI_CFG_MARGIN, $UI_CFG_GRP1_Y, $iGrpW, $UI_CFG_GRP1_H)

    ; ---- 行 0：软件名称 ----
    $iRowY = $UI_CFG_GRP1_Y + $UI_CFG_ROW_TOP
    GuiConfigLayout_MakeLabel("软件名称", $iRowY)
    $g_idName = GuiConfigLayout_MakeInput(Config_SoftwareName(), $iRowY)
    GUICtrlSetTip($g_idName, "用于生成默认安装根目录，同时作为日志与状态标识")

    ; ---- 行 1：安装根目录 ----
    $iRowY += $UI_CFG_ROW_PITCH
    GuiConfigLayout_MakeLabel("安装根目录", $iRowY)
    $g_idRoot = GuiConfigLayout_MakeInput(Config_InstallRoot(), $iRowY)
    GUICtrlSetTip($g_idRoot, "支持 " & $ENV_INSTALL_BASE & " 等环境变量；安装文件与日志将写入该目录")

    $g_idBrowse = GuiConfigLayout_MakeSmallButton("浏览...", $UI_CFG_BTN_X, $iRowY)
    $g_idRootDefault = GuiConfigLayout_MakeSmallButton("默认", $UI_CFG_BTN_X2, $iRowY)
    GUICtrlSetTip($g_idRootDefault, "恢复为默认路径（" & $ENV_INSTALL_BASE & " 下 " & $APP_COMPANY & _
            " 目录中的软件名子目录），并重新跟随软件名称变化")

    ; ---- 行 2：安装包目录 ----
    $iRowY += $UI_CFG_ROW_PITCH
    GuiConfigLayout_MakeLabel("安装包目录", $iRowY)
    $g_idPkgDir = GuiConfigLayout_MakeInput(Config_PackagesDir(), $iRowY)
    GUICtrlSetTip($g_idPkgDir, "安装包所在目录。可填相对路径（相对本程序，即「启动程序同级」）" & _
            "或绝对路径。" & @CRLF & "改完点右侧「刷新」重新扫描软件列表。")

    $g_idPkgBrowse = GuiConfigLayout_MakeSmallButton("浏览...", $UI_CFG_BTN_X, $iRowY)
    $g_idPkgReload = GuiConfigLayout_MakeSmallButton("刷新", $UI_CFG_BTN_X2, $iRowY)
    GUICtrlSetTip($g_idPkgReload, "按当前的安装包目录重新扫描软件列表（已勾选的软件会尽量保留）")

    ; ---- 行 3：拷贝源目录 ----
    $iRowY += $UI_CFG_ROW_PITCH
    GuiConfigLayout_MakeLabel("拷贝源目录", $iRowY)
    $g_idCopySrc = GuiConfigLayout_MakeInput(Config_CopySource(), $iRowY)
    GUICtrlSetTip($g_idCopySrc, "要部署到目标机器的资源文件夹（如出厂文档、驱动）。" & @CRLF & _
            "留空则不执行拷贝。")

    $g_idCopySrcBrowse = GuiConfigLayout_MakeSmallButton("浏览...", $UI_CFG_BTN_X, $iRowY)

    ; ---- 行 4：拷贝目标目录 ----
    $iRowY += $UI_CFG_ROW_PITCH
    GuiConfigLayout_MakeLabel("拷贝目标目录", $iRowY)
    $g_idCopyDst = GuiConfigLayout_MakeInput(Config_CopyDest(), $iRowY)
    GUICtrlSetTip($g_idCopyDst, "拷贝源目录会被整体拷贝到该目录下的同名子目录。" & @CRLF & _
            "留空则使用安装根目录。")

    $g_idCopyDstBrowse = GuiConfigLayout_MakeSmallButton("浏览...", $UI_CFG_BTN_X, $iRowY)

    ; ---- 灰色提示 ----
    $g_idRootHint = GUICtrlCreateLabel("", $UI_CFG_INPUT_X, _
            $UI_CFG_GRP1_Y + $UI_CFG_HINT_TOP, 468, $UI_CFG_HINT_H)
    GUICtrlSetColor($g_idRootHint, $UI_COLOR_HINT)

    $g_idPkgHint = GUICtrlCreateLabel("", $UI_CFG_PAD, _
            $UI_CFG_GRP1_Y + $UI_CFG_HINT_TOP + $UI_CFG_HINT_PITCH, 548, $UI_CFG_HINT_H)
    GUICtrlSetColor($g_idPkgHint, $UI_COLOR_HINT)

    $g_idLogHint = GUICtrlCreateLabel("", $UI_CFG_PAD, _
            $UI_CFG_GRP1_Y + $UI_CFG_HINT_TOP + 2 * $UI_CFG_HINT_PITCH, 548, $UI_CFG_HINT_H)
    GUICtrlSetColor($g_idLogHint, $UI_COLOR_HINT)

    $g_idConfigHint = GUICtrlCreateLabel("配置文件：" & Config_File(), $UI_CFG_PAD, _
            $UI_CFG_GRP1_Y + $UI_CFG_HINT_TOP + 3 * $UI_CFG_HINT_PITCH, 548, $UI_CFG_HINT_H)
    GUICtrlSetColor($g_idConfigHint, $UI_COLOR_HINT)
    GUICtrlSetTip($g_idConfigHint, "配置保存位置：" & Config_File())

    GUICtrlCreateGroup("", -99, -99, 1, 1)
EndFunc

; ------------------------------------------------------------------------------
; 软件选择组：工具条 + 固定高度的复选框列表
; ------------------------------------------------------------------------------
Func GuiConfigLayout_CreatePackageGroup()
    Local $iGrpW = $UI_CFG_W - 2 * $UI_CFG_MARGIN

    $g_idGrp2 = GUICtrlCreateGroup(" 选择要安装的软件 ", $UI_CFG_MARGIN, $UI_CFG_GRP2_Y, _
            $iGrpW, $UI_CFG_GRP2_H)

    ; ---- 工具条 ----
    Local $iBarY = $UI_CFG_GRP2_Y + 26
    $g_idSelectAll    = GUICtrlCreateButton("全选", $UI_CFG_PAD, $iBarY, 64, 26)
    $g_idSelectNone   = GUICtrlCreateButton("全不选", $UI_CFG_PAD + 70, $iBarY, 64, 26)
    $g_idSelectInvert = GUICtrlCreateButton("反选", $UI_CFG_PAD + 140, $iBarY, 64, 26)

    $g_idCount = GUICtrlCreateLabel("", 364, $iBarY + 4, 220, 20, $SS_RIGHT)
    GUICtrlSetColor($g_idCount, $UI_COLOR_TEXT)

    ; ---- 列表（固定高度，软件多了由列表自带滚动条）----
    $g_idPkgList = GuiPackageList_Create($UI_CFG_PAD, $UI_CFG_GRP2_Y + $UI_CFG_GRP2_BAR, _
            $iGrpW - 2 * $UI_CFG_INNER_PAD, $UI_CFG_LIST_H)

    GUICtrlCreateGroup("", -99, -99, 1, 1)
EndFunc

; ------------------------------------------------------------------------------
; 底部操作栏
; ------------------------------------------------------------------------------
Func GuiConfigLayout_CreateBottomBar()
    $g_idStatus = GUICtrlCreateLabel("", 22, $UI_CFG_BOTTOM_Y + 8, 260, 20)
    GUICtrlSetColor($g_idStatus, $UI_COLOR_TEXT)

    $g_idStart = GUICtrlCreateButton("开始安装", 296, $UI_CFG_BOTTOM_Y, 100, $UI_CFG_BTN_H)
    GUICtrlSetFont($g_idStart, $UI_FONT_SIZE, 700)
    $g_idSave = GUICtrlCreateButton("保存配置", 402, $UI_CFG_BOTTOM_Y, 96, $UI_CFG_BTN_H)
    $g_idExit = GUICtrlCreateButton("退出", 504, $UI_CFG_BOTTOM_Y, 96, $UI_CFG_BTN_H)
EndFunc

; ------------------------------------------------------------------------------
; 组内小控件
; ------------------------------------------------------------------------------
Func GuiConfigLayout_MakeLabel($sText, $iRowY)
    Return GUICtrlCreateLabel($sText, $UI_CFG_PAD, $iRowY + 3, $UI_CFG_LABEL_W, 22)
EndFunc

Func GuiConfigLayout_MakeInput($sText, $iRowY)
    Return GUICtrlCreateInput($sText, $UI_CFG_INPUT_X, $iRowY, $UI_CFG_INPUT_W, $UI_CFG_INPUT_H)
EndFunc

Func GuiConfigLayout_MakeSmallButton($sText, $iX, $iRowY)
    Return GUICtrlCreateButton($sText, $iX, $iRowY - 1, 62, $UI_CFG_BTN_SM_H)
EndFunc
