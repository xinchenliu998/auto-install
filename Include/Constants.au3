; ==============================================================================
; Constants.au3 —— 全局常量集中管理
; ------------------------------------------------------------------------------
; 本文件是项目**唯一**的框架级常量来源。其他模块统一 #include 本文件，
; 不要在各自脚本里散落硬编码的数字与字符串。
;
; 命名前缀约定：
;   $APP_    应用信息
;   $ENV_    环境变量
;   $DIR_    目录名
;   $FILE_   文件名
;   $INI_    配置文件段名 / 键名
;   $PKG_    软件列表数组列索引
;   $REG_    安装注册表数组列索引
;   $LOG_    日志级别与格式
;   $RUN_    外部命令执行返回码、轮询与超时
;   $MB_     消息框标志与返回值
;   $EXIT_   进程退出码
;   $CLI_    命令行开关
;   $MUTEX_  互斥体名称
;   $UI_     界面布局、字体、颜色
;
; 例外：与单个软件强相关的常量（安装包文件名、安装目录名等）留在各自的
;      Include\Install\*.au3 顶部（前缀取软件名，如 $ZIP7_ / $SQLITE_ / $WPS_），
;      避免本文件随软件数量无限膨胀。
; ==============================================================================

#include-once

; ------------------------------------------------------------------------------
; 应用信息
; ------------------------------------------------------------------------------
Global Const $APP_NAME      = "auto-install"
Global Const $APP_TITLE     = "auto-install 装机工具"
Global Const $APP_TITLE_RUN = "auto-install 装机工具 - 正在执行"
Global Const $APP_VERSION   = "1.0.0"
Global Const $APP_COMPANY   = "BJ"              ; 公司名称，用于生成默认安装根目录

; ------------------------------------------------------------------------------
; 环境变量 / 目录 / 文件名
; ------------------------------------------------------------------------------
; 安装根目录的基准位置。用 Local 而非 Roaming：安装文件不该随域账户漫游同步。
; 改这一行即可整体切换安装根目录的默认位置。
Global Const $ENV_INSTALL_BASE = "%LOCALAPPDATA%"

; 安装包目录的默认值：相对路径，相对本程序所在目录（即「启动程序同级」）。
; 实际值存在 config.ini 的 PackagesDir，可改成绝对路径指向仓库之外。
Global Const $DIR_PACKAGES_DEF = "packages"

Global Const $DIR_LOGS         = "logs"         ; 日志子目录（相对安装根目录）

Global Const $FILE_CONFIG      = "config.ini"   ; 运行配置
Global Const $FILE_PACKAGE_INI = "package.ini"  ; 单个软件的可选清单
Global Const $FILE_LOG_PREFIX  = "install_"     ; 日志文件名前缀
Global Const $FILE_LOG_EXT     = ".log"

; 解压绿色版软件包时依赖的外部工具（Common_Find7Zip() 用）
Global Const $FILE_7ZIP_EXE    = "7z.exe"

; ------------------------------------------------------------------------------
; 配置文件（config.ini）段名与键名
; ------------------------------------------------------------------------------
Global Const $INI_SEC_GENERAL  = "General"
Global Const $INI_SEC_PACKAGES = "Packages"
Global Const $INI_SEC_PACKAGE  = "Package"

Global Const $INI_KEY_NAME     = "SoftwareName"
Global Const $INI_KEY_ROOT     = "InstallRoot"
Global Const $INI_KEY_PKGDIR   = "PackagesDir"    ; 安装包所在目录
Global Const $INI_KEY_COPYSRC  = "CopySourceDir"  ; 资源拷贝源目录
Global Const $INI_KEY_COPYDST  = "CopyDestDir"    ; 资源拷贝目标目录
Global Const $INI_KEY_DISPLAY  = "DisplayName"

Global Const $INI_DEFAULT_ON   = "1"            ; 新扫描到的软件默认勾选

; ------------------------------------------------------------------------------
; 软件列表数组列索引（Config_* 系列函数使用）
; ------------------------------------------------------------------------------
Global Const $PKG_COL_FOLDER  = 0               ; packages 下的目录名
Global Const $PKG_COL_DISPLAY = 1               ; 显示名
Global Const $PKG_COL_ENABLED = 2               ; 是否勾选（1/0）
Global Const $PKG_COL_PATH    = 3               ; 目录完整路径
Global Const $PKG_COL_COUNT   = 4

; ------------------------------------------------------------------------------
; 安装函数注册表数组列索引（Installer_* 系列函数使用）
; ------------------------------------------------------------------------------
Global Const $REG_COL_FOLDER = 0                ; packages 下的目录名
Global Const $REG_COL_FUNC   = 1                ; 安装函数名
Global Const $REG_COL_COUNT  = 2

; ------------------------------------------------------------------------------
; 日志
; ------------------------------------------------------------------------------
Global Const $LOG_LEVEL_INFO  = "INFO"
Global Const $LOG_LEVEL_OK    = "OK"
Global Const $LOG_LEVEL_WARN  = "WARN"
Global Const $LOG_LEVEL_ERROR = "ERROR"
Global Const $LOG_LEVEL_STEP  = "STEP"
Global Const $LOG_LEVEL_WIDTH = 5               ; 级别字段对齐宽度

; ------------------------------------------------------------------------------
; 外部命令执行
; ------------------------------------------------------------------------------
Global Const $RUN_ERR_START      = -1           ; 命令启动失败
Global Const $RUN_ERR_TIMEOUT    = -2           ; 等待超时被强制结束
Global Const $RUN_EXITED_BEFORE  = 0xCCCCCCCC   ; ProcessWaitClose 对已退出进程的 @extended
Global Const $RUN_POLL_MS        = 1000         ; 分片等待步长（毫秒）
Global Const $RUN_PUMP_MS        = 100          ; Adlib 消息泵间隔（毫秒）

; 等待心跳：安装 / 解压 / 拷贝可能持续很久，等待期间定期输出「仍在进行」，
; 避免界面长时间没有新日志而被误认为卡死（实现见 Installer_WaitTick）。
Global Const $RUN_HEARTBEAT_MS      = 1000      ; 界面「已等待」计时刷新间隔（毫秒）
Global Const $RUN_HEARTBEAT_LOG_SEC = 10        ; 写一条心跳日志的间隔（秒）

Global Const $TIMEOUT_INSTALL      = 600000     ; 单个软件安装超时（10 分钟）
Global Const $TIMEOUT_INSTALL_LONG = 1800000    ; 大体积软件安装超时（30 分钟，如 WPS）
Global Const $TIMEOUT_UNZIP        = 600000     ; 解压超时（10 分钟）
Global Const $TIMEOUT_COPY         = 1800000    ; 资源拷贝超时（30 分钟）

; robocopy 退出码：0~7 都表示成功（0=无需拷贝，1=有文件被拷贝…），8 及以上才是错误
Global Const $ROBOCOPY_OK_MAX      = 7

; ------------------------------------------------------------------------------
; 安装器静默参数（按安装包打包工具区分，供各 Install 模块复用）
;   注意：不同渠道 / 版本的安装包参数可能不同，批量使用前务必实测确认。
; ------------------------------------------------------------------------------
Global Const $SILENT_NSIS = "/S"                                            ; NSIS
Global Const $SILENT_INNO = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-" ; Inno Setup

; ------------------------------------------------------------------------------
; 消息框
; ------------------------------------------------------------------------------
Global Const $MB_WARN       = 0x30              ; 警告图标
Global Const $MB_ERROR      = 0x10              ; 错误图标
Global Const $MB_INFO       = 0x40              ; 信息图标
Global Const $MB_YESNO_WARN = 0x134             ; 是/否 + 警告图标 + 默认「否」
Global Const $MB_RET_YES    = 6                 ; 上面对话框点击「是」的返回值

; ------------------------------------------------------------------------------
; 进程退出码
; ------------------------------------------------------------------------------
Global Const $EXIT_OK   = 0
Global Const $EXIT_FAIL = 1

; ------------------------------------------------------------------------------
; 命令行开关
; ------------------------------------------------------------------------------
Global Const $CLI_RUN        = "--run"
Global Const $CLI_AUTO_CLOSE = "--auto-close"
Global Const $CLI_HELP       = "--help"

; ------------------------------------------------------------------------------
; 互斥体名称（单实例保护）
; ------------------------------------------------------------------------------
Global Const $MUTEX_GUI = "auto-install-gui"

; ------------------------------------------------------------------------------
; 界面：通用字体与颜色
; ------------------------------------------------------------------------------
Global Const $UI_FONT_UI      = "Microsoft YaHei"
Global Const $UI_FONT_MONO    = "Consolas"
Global Const $UI_FONT_SIZE    = 9
Global Const $UI_FONT_SIZE_H  = 14              ; 主标题
Global Const $UI_FONT_SIZE_S  = 12              ; 次级标题

Global Const $UI_COLOR_BG      = 0xFFFFFF       ; 窗口背景
Global Const $UI_COLOR_HINT    = 0x9E9E9E       ; 灰色提示文字
Global Const $UI_COLOR_TEXT    = 0x666666       ; 次级文字
Global Const $UI_COLOR_SUBTEXT = 0x8C8C8C       ; 副标题
Global Const $UI_COLOR_ERROR   = 0xC0392B       ; 错误提示

; ------------------------------------------------------------------------------
; 界面：配置窗口布局
; ------------------------------------------------------------------------------
Global Const $UI_CFG_W          = 620
Global Const $UI_CFG_MARGIN     = 16            ; 窗口左右外边距
Global Const $UI_CFG_GRP1_Y     = 72

; 「基本配置」组内的行布局（5 行输入 + 4 行灰色提示）
Global Const $UI_CFG_LABEL_W    = 76            ; 输入框左侧标签宽度
Global Const $UI_CFG_INPUT_X    = 114
Global Const $UI_CFG_INPUT_W    = 346
Global Const $UI_CFG_INPUT_H    = 25
Global Const $UI_CFG_ROW_TOP    = 30            ; 第一行输入相对组顶的偏移
Global Const $UI_CFG_ROW_PITCH  = 34            ; 行间距
Global Const $UI_CFG_BTN_X      = 466           ; 组内小按钮左边缘
Global Const $UI_CFG_BTN_X2     = 532
Global Const $UI_CFG_BTN_SM_H   = 27
Global Const $UI_CFG_HINT_TOP   = 200           ; 第一行灰色提示相对组顶的偏移
Global Const $UI_CFG_HINT_PITCH = 22
Global Const $UI_CFG_HINT_H     = 18
Global Const $UI_CFG_GRP1_H     = 298           ; = HINT_TOP + 4*HINT_PITCH + HINT_H + 14

Global Const $UI_CFG_PAD        = 34            ; 组内左边距
Global Const $UI_CFG_INNER_PAD  = 18            ; 组内右边距
Global Const $UI_CFG_BTN_H      = 32

; 「选择要安装的软件」组 —— 固定尺寸，软件多了由列表控件自带滚动条，窗口不随之变化
Global Const $UI_CFG_GRP2_Y     = 384
Global Const $UI_CFG_GRP2_BAR   = 58            ; 组内工具条高度
Global Const $UI_CFG_GRP2_BOT   = 14            ; 组底部留白
Global Const $UI_CFG_LIST_H     = 176           ; 列表高度，约 8 行
Global Const $UI_CFG_GRP2_H     = 248           ; = GRP2_BAR + LIST_H + GRP2_BOT
Global Const $UI_CFG_BOTTOM_Y   = 646           ; = GRP2_Y + GRP2_H + GRP2_BOT
Global Const $UI_CFG_BOTTOM_GAP = 18            ; 底部按钮与窗口下沿间距
Global Const $UI_CFG_WIN_H      = 696           ; = BOTTOM_Y + BTN_H + BOTTOM_GAP

; ------------------------------------------------------------------------------
; 界面：执行窗口布局
; ------------------------------------------------------------------------------
Global Const $UI_RUN_W              = 640
Global Const $UI_RUN_H              = 480
Global Const $UI_RUN_PAD            = 22
Global Const $UI_RUN_PROGRESS_H     = 18
Global Const $UI_RUN_LOG_Y          = 122
Global Const $UI_RUN_LOG_H          = 300
Global Const $UI_RUN_BTN_Y          = 434
Global Const $UI_RUN_BTN_W          = 120
Global Const $UI_RUN_BTN_H          = 30
Global Const $UI_RUN_AUTOCLOSE_WAIT = 1500      ; 无人值守模式下结果窗口停留时间（毫秒）
