; ==============================================================================
; Config\Group.au3 —— 软件分组（分组键 / 顺序 / 显示名）+「必须安装」
; ------------------------------------------------------------------------------
; 分组信息写在「安装包目录」下各软件的 package.ini 里（Category / Required），
; 本文件负责把它翻译成「界面上按什么顺序摆哪几个分组头」。
;
; 本文件负责的函数段：
;     Config_CategoryName      分组键 -> 界面显示名
;     Config_CategoryKey       归一化分组键（空 -> 兜底分组「未分组」）
;     Config_CategoryOrder     $PKG_CAT_ORDER 拆成数组
;     Config_ApplyRequired     「必须安装」的软件一律勾上
;     Config_BuildGroups       算出分组的显示顺序
;
; 【新增一个分组】三处各补一行：
;   1. Constants.au3 的 $PKG_CAT_ORDER          —— 排在哪个位置
;   2. 本文件的 Config_CategoryName()           —— 中文显示名
;   3. 各软件 package.ini 的 Category            —— 把软件挂过去
;
; 【为什么 package.ini 里写 ASCII 键而不是中文】
;   见 Constants.au3 的软件分组一节：AutoIt 的 IniRead 按 ANSI 代码页读无 BOM 文件，
;   中文值会乱码、带 BOM 则整段读不到。所以中文名统一放在 Config_CategoryName() 里。
;   键不在表里时原样返回，于是 package.ini 也可以直接写中文分组名 ——
;   但那种写法要求该文件存成 ANSI/GBK。
;
; 全局状态在 Config\Shared.au3（本文件自己 #include）。
; ==============================================================================

#include-once

#include "..\Constants.au3"
#include "Shared.au3"

; 分组键 -> 界面显示名。新增分组时这里与 Constants.au3 的 $PKG_CAT_ORDER 各补一处。
;
; 键不在表里时原样返回 —— 于是 package.ini 也可以直接写中文分组名，
; 但那种写法要求该文件存成 ANSI/GBK（写 UTF-8 会读成乱码，见 Constants.au3 的说明）。
Func Config_CategoryName($sKey)
    Switch StringLower(StringStripWS($sKey, 3))
        Case $PKG_CAT_REQUIRED
            Return "必须安装"
        Case "base"
            Return "基础环境"
        Case "dev"
            Return "开发工具"
        Case "debug"
            Return "调试工具"
        Case "vision"
            Return "机器视觉"
        Case "office"
            Return "办公软件"
        Case $PKG_CAT_DEFAULT
            Return "未分组"
        Case Else
            Return StringStripWS($sKey, 3)
    EndSwitch
EndFunc

; 归一化分组键：空 -> 兜底分组（未分组）；命中顺序表（大小写不限）-> 小写键；其它 -> 原样保留
Func Config_CategoryKey($sRaw)
    Local $sKey = StringStripWS($sRaw, 3)
    If $sKey = "" Then Return $PKG_CAT_DEFAULT

    Local $sLower = StringLower($sKey)
    Local $aOrder = Config_CategoryOrder()

    If Config_ArrayFind($aOrder, UBound($aOrder), $sLower) >= 0 Then Return $sLower

    Return $sKey
EndFunc

; $PKG_CAT_ORDER 拆成数组（供本模块内部按顺序比对）
Func Config_CategoryOrder()
    Return StringSplit($PKG_CAT_ORDER, ",", $STR_NOCOUNT)
EndFunc

; 「必须安装」的软件一律勾上 —— package.ini、config.ini、界面都改不动它。
; 扫描与重新扫描（点「刷新」）之后都要调一次。
Func Config_ApplyRequired()
    For $i = 0 To $g_iPackageCount - 1
        If $g_aPackages[$i][$PKG_COL_REQUIRED] = 1 Then $g_aPackages[$i][$PKG_COL_ENABLED] = 1
    Next
EndFunc

; 算出分组显示顺序（界面按这个顺序摆分组头）。
;
;   $aOut   ByRef，2 列数组（至少 1 行）：[i][0]=分组键  [i][1]=是否「必须安装」组
;   返回值  分组个数（无软件时为 0）
;
; 顺序规则：$PKG_CAT_ORDER 决定先后；表里没有的分组按扫描顺序接在后面；
;          「必须安装」组固定排第一。
Func Config_BuildGroups(ByRef $aOut)
    Local $aEmpty[1][2]
    $aOut = $aEmpty

    If $g_iPackageCount = 0 Then Return 0

    ; ---- 1. 收集出现过的分组（去重，保留扫描顺序）----
    Local $aFound[$g_iPackageCount]
    Local $iFound = 0
    Local $i, $sKey

    For $i = 0 To $g_iPackageCount - 1
        $sKey = $g_aPackages[$i][$PKG_COL_CATEGORY]
        If Config_ArrayFind($aFound, $iFound, $sKey) < 0 Then
            $aFound[$iFound] = $sKey
            $iFound += 1
        EndIf
    Next

    ; ---- 2. 按 $PKG_CAT_ORDER 排序，表里没有的接在后面 ----
    Local $aSorted[$iFound]
    Local $iSorted = 0
    Local $aOrder = Config_CategoryOrder()

    For $i = 0 To UBound($aOrder) - 1
        $sKey = StringStripWS($aOrder[$i], 3)
        If $sKey = "" Then ContinueLoop
        If Config_ArrayFind($aFound, $iFound, $sKey) < 0 Then ContinueLoop
        $iSorted = Config_ArrayAppendUnique($aSorted, $iSorted, $sKey)
    Next

    For $i = 0 To $iFound - 1
        $iSorted = Config_ArrayAppendUnique($aSorted, $iSorted, $aFound[$i])
    Next

    ; ---- 3. 输出：「必须安装」组固定第一 ----
    Local $aRet[$iFound + 1][2]
    Local $iRet = 0

    If Config_ArrayFind($aFound, $iFound, $PKG_CAT_REQUIRED) >= 0 Then
        $aRet[$iRet][0] = $PKG_CAT_REQUIRED
        $aRet[$iRet][1] = 1
        $iRet += 1
    EndIf

    For $i = 0 To $iSorted - 1
        If $aSorted[$i] = $PKG_CAT_REQUIRED Then ContinueLoop
        $aRet[$iRet][0] = $aSorted[$i]
        $aRet[$iRet][1] = 0
        $iRet += 1
    Next

    ReDim $aRet[$iRet][2]
    $aOut = $aRet
    Return $iRet
EndFunc
