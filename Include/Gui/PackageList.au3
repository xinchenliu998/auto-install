; ==============================================================================
; Gui\PackageList.au3 —— 软件列表控件
; ------------------------------------------------------------------------------
; 封装「选择要安装的软件」那个带复选框的 ListView：
;   · 创建：固定高度，软件多了由列表自带滚动条，不涉及任何布局调整；
;   · 按当前配置重填内容；
;   · 勾选状态读写、全选 / 全不选 / 反选、已选计数。
;
; 控件 ID 存在 $g_idPkgList / $g_idCount（在 Gui\Config.au3 里声明），
; 本模块只负责操作它们，不创建窗口、不碰布局。
; ==============================================================================

#include-once

#include <GuiListView.au3>
#include <ListViewConstants.au3>
#include <WindowsConstants.au3>

#include "..\Constants.au3"
#include "..\Common.au3"
#include "..\Config.au3"

; 已选计数缓存。ListView 的勾选变化不便直接收消息（要处理 WM_NOTIFY），
; 因此改由空闲轮询驱动刷新，用缓存避免每次都写标签。
Global $g_iSelCount = -1
Global $g_iSelTotal = -1

; 创建列表控件，返回控件 ID
Func GuiPackageList_Create($iX, $iY, $iW, $iH)
    Local $id = GUICtrlCreateListView("软件", $iX, $iY, $iW, $iH, _
            BitOR($LVS_REPORT, $LVS_SINGLESEL, $LVS_SHOWSELALWAYS, $LVS_NOCOLUMNHEADER, $WS_TABSTOP))
    GUICtrlSetFont($id, $UI_FONT_SIZE, 400, 0, $UI_FONT_UI)

    _GUICtrlListView_SetExtendedListViewStyle($id, BitOR($LVS_EX_CHECKBOXES, $LVS_EX_FULLROWSELECT))

    ; 列宽留出复选框与竖向滚动条的位置，避免出现横向滚动条
    _GUICtrlListView_SetColumnWidth($id, 0, $iW - 45)

    Return $id
EndFunc

; 按当前配置里的软件列表重填内容（不做任何布局调整）
Func GuiPackageList_Fill()
    If $g_idPkgList = 0 Then Return

    _GUICtrlListView_DeleteAllItems($g_idPkgList)

    Local $iCount = Config_PackageCount()
    If $iCount = 0 Then
        _GUICtrlListView_AddItem($g_idPkgList, "（未在安装包目录下发现任何软件子目录）")
        $g_iSelCount = -1
        $g_iSelTotal = -1
        GUICtrlSetData($g_idCount, "已选 0 / 0")
        Return
    EndIf

    For $i = 0 To $iCount - 1
        _GUICtrlListView_AddItem($g_idPkgList, Config_PackageDisplay($i), -1, $i)
        If Config_PackageEnabled($i) Then _GUICtrlListView_SetItemChecked($g_idPkgList, $i, True)
    Next

    $g_iSelCount = -1                   ; 强制刷新一次计数
    $g_iSelTotal = -1
    GuiPackageList_UpdateCount()
EndFunc

Func GuiPackageList_CountSelected()
    Local $iSel = 0
    For $i = 0 To Config_PackageCount() - 1
        If _GUICtrlListView_GetItemChecked($g_idPkgList, $i) Then $iSel += 1
    Next
    Return $iSel
EndFunc

; 刷新「已选 N / M」；由空闲轮询调用
Func GuiPackageList_UpdateCount()
    If $g_idPkgList = 0 Then Return

    Local $iTotal = Config_PackageCount()
    Local $iSel = GuiPackageList_CountSelected()

    If $iSel = $g_iSelCount And $iTotal = $g_iSelTotal Then Return

    $g_iSelCount = $iSel
    $g_iSelTotal = $iTotal
    GUICtrlSetData($g_idCount, "已选 " & $iSel & " / " & $iTotal)
EndFunc

Func GuiPackageList_SetAll($bChecked)
    For $i = 0 To Config_PackageCount() - 1
        _GUICtrlListView_SetItemChecked($g_idPkgList, $i, $bChecked)
    Next
    GuiPackageList_UpdateCount()
EndFunc

Func GuiPackageList_Invert()
    For $i = 0 To Config_PackageCount() - 1
        _GUICtrlListView_SetItemChecked($g_idPkgList, $i, _
                Not _GUICtrlListView_GetItemChecked($g_idPkgList, $i))
    Next
    GuiPackageList_UpdateCount()
EndFunc

; 把列表里的勾选状态写回配置对象
Func GuiPackageList_WriteToConfig()
    For $i = 0 To Config_PackageCount() - 1
        Config_SetPackageEnabled($i, _GUICtrlListView_GetItemChecked($g_idPkgList, $i))
    Next
EndFunc
