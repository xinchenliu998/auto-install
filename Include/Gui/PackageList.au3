; ==============================================================================
; Gui\PackageList.au3 —— 软件列表控件
; ------------------------------------------------------------------------------
; 封装「选择要安装的软件」那个带复选框的 ListView：
;   · 创建：固定高度，软件多了由列表自带滚动条，不涉及任何布局调整；
;   · 按当前配置重填内容，并按 package.ini 里的分组打上分组头；
;   · 勾选状态读写、全选 / 全不选 / 反选、已选计数；
;   · 「必须安装」的软件锁定为已勾选，不参与全不选 / 反选。
;
; 【只有已适配的软件才进列表】
;   列表内容由 Config_ScanPackages() 决定：安装包目录下没有对应安装脚本
;   （Installer_Register 未注册）的目录默认不出现；排障时把 config.ini 的
;   [General] ShowUnsupported 设成 1，它们才会以「(未适配)」显示在最后，
;   且勾选框始终不可勾（本模块负责把它按回去）。
;   一个已适配的都没有时，列表保持**空白**，不放占位行（占位行带复选框，会被当成可勾选项）。
;
; 控件 ID 存在 $g_idPkgList / $g_idCount（在 Gui\Config.au3 里声明），
; 本模块只负责操作它们，不创建窗口、不碰布局。
;
; 【分组显示】
;   优先用 ListView 自带的分组视图（分组头 + 组内条目），由 ComCtl32 v6 提供，
;   AutoIt 的界面默认就是 v6；万一某台机器上不可用，自动退化成给每行加
;   「【分组名】显示名」前缀 —— 不报错、也不影响勾选。
;   需要分组头是中文时，标题自己按 wchar 写入（见 GuiPackageList_InsertGroup）。
;
; 【列表序号 = 配置数组下标】
;   第 i 行的下标必须与 Config_PackageCount() 的第 i 个软件一致，
;   勾选状态才能按 GUICtrlListView 的下标正确写回配置。
; ==============================================================================

#include-once

#include <GuiListView.au3>
#include <ListViewConstants.au3>
#include <WindowsConstants.au3>

#include "..\Constants.au3"
#include "..\Common.au3"
#include "..\Config.au3"
#include "ConfigShared.au3"

; 已选计数缓存。ListView 的勾选变化不便直接收消息（要处理 WM_NOTIFY），
; 因此改由空闲轮询驱动刷新，用缓存避免每次都写标签。
Global $g_iSelCount = -1
Global $g_iSelTotal = -1

; 分组视图是否可用：懒判断一次后缓存（判断要发消息，不必每次重填都问一遍）
Global $g_bPkgGroupsTried = False
Global $g_bPkgGroupsOn    = False

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
    GuiPackageList_ClearGroups()

    ; 安装包目录下没有已适配的软件时，列表**保持空白**，不放任何占位行 ——
    ; 占位行也带复选框，看起来像是「有一个能勾选的东西」，容易误解成可安装项。
    Local $iCount = Config_PackageCount()
    If $iCount = 0 Then
        $g_iSelCount = -1
        $g_iSelTotal = -1
        GUICtrlSetData($g_idCount, "已选 0 / 0")
        Return
    EndIf

    ; ---- 分组：先摆分组头，再把每个软件挂到自己的组里 ----
    Local $aGroups[1][2]
    Local $iGroups = Config_BuildGroups($aGroups)
    Local $bGrouped = GuiPackageList_UseGroups()

    If $bGrouped Then
        For $g = 0 To $iGroups - 1
            GuiPackageList_InsertGroup($g, Config_CategoryName($aGroups[$g][0]))
        Next
    EndIf

    Local $sKey, $sText

    For $i = 0 To $iCount - 1
        $sKey  = Config_PackageCategory($i)
        $sText = Config_PackageDisplay($i)

        ; 分组视图不可用时，用文字前缀代替分组头
        If Not $bGrouped Then $sText = "【" & Config_CategoryName($sKey) & "】" & $sText

        _GUICtrlListView_AddItem($g_idPkgList, $sText, -1, $i)

        If $bGrouped Then
            _GUICtrlListView_SetItemGroupID($g_idPkgList, $i, _
                    GuiPackageList_GroupIndex($aGroups, $iGroups, $sKey))
        EndIf

        If Config_PackageEnabled($i) Then _GUICtrlListView_SetItemChecked($g_idPkgList, $i, True)
    Next

    GuiPackageList_EnforceRequired()

    $g_iSelCount = -1                   ; 强制刷新一次计数
    $g_iSelTotal = -1
    GuiPackageList_UpdateCount()
EndFunc

; 分组键在分组表里的下标；正常必然命中，落空时退回第 0 组（不至于漏掉这一行）
Func GuiPackageList_GroupIndex($aGroups, $iGroups, $sKey)
    For $g = 0 To $iGroups - 1
        If $aGroups[$g][0] = $sKey Then Return $g
    Next
    Return 0
EndFunc

; ------------------------------------------------------------------------------
; 分组视图
; ------------------------------------------------------------------------------

; 原生分组视图是否可用。只判断一次；不可用时由调用方退化成文字前缀。
Func GuiPackageList_UseGroups()
    If $g_idPkgList = 0 Then Return False

    If Not $g_bPkgGroupsTried Then
        $g_bPkgGroupsTried = True
        _GUICtrlListView_EnableGroupView($g_idPkgList, True)
        $g_bPkgGroupsOn = _GUICtrlListView_GetGroupViewEnabled($g_idPkgList)
    EndIf

    Return $g_bPkgGroupsOn
EndFunc

; 插入一个分组头。
;
; 这里自己拼 LVGROUP、用 wchar 缓冲写标题，没有用 _GUICtrlListView_InsertGroup() ——
; 那个 UDF 会把标题经 MultiByteToWideChar 按当前 ANSI 代码页转一道，
; 在非中文区域设置的系统上中文分组名会变成问号。
Func GuiPackageList_InsertGroup($iGroupID, $sHeader)
    Local $tGroup = DllStructCreate($tagLVGROUP)
    Local $tText  = DllStructCreate("wchar[" & (StringLen($sHeader) + 1) & "]")
    DllStructSetData($tText, 1, $sHeader)

    DllStructSetData($tGroup, "Size", DllStructGetSize($tGroup))
    DllStructSetData($tGroup, "Mask", BitOR($LVGF_HEADER, $LVGF_ALIGN, $LVGF_GROUPID))
    DllStructSetData($tGroup, "Header", DllStructGetPtr($tText))
    DllStructSetData($tGroup, "GroupID", $iGroupID)
    DllStructSetData($tGroup, "Align", $LVGA_HEADER_LEFT)

    Return GUICtrlSendMsg($g_idPkgList, $LVM_INSERTGROUP, -1, DllStructGetPtr($tGroup))
EndFunc

Func GuiPackageList_ClearGroups()
    If $g_idPkgList = 0 Then Return
    _GUICtrlListView_RemoveAllGroups($g_idPkgList)
EndFunc

; ------------------------------------------------------------------------------
; 勾选
; ------------------------------------------------------------------------------

; 「必须安装」的软件锁定为已勾选。用户点掉它的复选框后，由空闲轮询（约 60ms）补回来。
; 「未适配」的软件反向锁定：没有安装脚本，勾上也没用，一律保持不勾。
Func GuiPackageList_EnforceRequired()
    For $i = 0 To Config_PackageCount() - 1
        If GuiPackageList_IsUnsupported($i) Then
            If _GUICtrlListView_GetItemChecked($g_idPkgList, $i) Then
                _GUICtrlListView_SetItemChecked($g_idPkgList, $i, False)
            EndIf
        ElseIf Config_PackageRequired($i) And Not _GUICtrlListView_GetItemChecked($g_idPkgList, $i) Then
            _GUICtrlListView_SetItemChecked($g_idPkgList, $i, True)
        EndIf
    Next
EndFunc

; 该条目是否属于「未适配」组（没有安装脚本，仅排障时显示）
Func GuiPackageList_IsUnsupported($i)
    Return (Config_PackageCategory($i) = $PKG_CAT_UNSUPPORTED)
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

    GuiPackageList_EnforceRequired()    ; 锁定项被点掉时立刻补回来

    Local $iTotal = Config_PackageCount()
    Local $iSel = GuiPackageList_CountSelected()

    If $iSel = $g_iSelCount And $iTotal = $g_iSelTotal Then Return

    $g_iSelCount = $iSel
    $g_iSelTotal = $iTotal
    GUICtrlSetData($g_idCount, "已选 " & $iSel & " / " & $iTotal)
EndFunc

Func GuiPackageList_SetAll($bChecked)
    For $i = 0 To Config_PackageCount() - 1
        ; 「必须安装」的软件不参与「全不选」；「未适配」的怎么都不勾
        If GuiPackageList_IsUnsupported($i) Then ContinueLoop
        If $bChecked Or Not Config_PackageRequired($i) Then
            _GUICtrlListView_SetItemChecked($g_idPkgList, $i, $bChecked)
        EndIf
    Next
    GuiPackageList_UpdateCount()
EndFunc

Func GuiPackageList_Invert()
    For $i = 0 To Config_PackageCount() - 1
        If Config_PackageRequired($i) Then ContinueLoop    ; 锁定项不参与反选
        If GuiPackageList_IsUnsupported($i) Then ContinueLoop
        _GUICtrlListView_SetItemChecked($g_idPkgList, $i, _
                Not _GUICtrlListView_GetItemChecked($g_idPkgList, $i))
    Next
    GuiPackageList_UpdateCount()
EndFunc

; 把列表里的勾选状态写回配置对象（未适配的不写，它本来也不参与）
Func GuiPackageList_WriteToConfig()
    For $i = 0 To Config_PackageCount() - 1
        If GuiPackageList_IsUnsupported($i) Then ContinueLoop
        Config_SetPackageEnabled($i, _GUICtrlListView_GetItemChecked($g_idPkgList, $i))
    Next
EndFunc
