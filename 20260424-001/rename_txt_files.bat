@echo off
setlocal enabledelayedexpansion

:: 使用PowerShell获取当前日期（格式：YYYYMMDD）
for /f "usebackq delims=" %%a in (`powershell -Command "Get-Date -Format 'yyyyMMdd'"`) do (
    set "date_str=%%a"
)

set "count=0"
set "file_count=0"
set "skipped_count=0"

:: 创建临时文件存储文件列表，避免空格问题
set "temp_file=%temp%\file_list_%random%.txt"

:: 先收集所有需要处理的文件到临时文件
for %%f in (*.txt) do (
    set "filename=%%~nf"
    set "has_prefix=0"

    if "!filename:~8,1!"=="_" (
        set "prefix=!filename:~0,8!"
        set "is_number=1"

        for /l %%i in (0,1,7) do (
            set "char=!prefix:~%%i,1!"
            if not "!char!" GEQ "0" if not "!char!" LEQ "9" (
                set "is_number=0"
            )
        )

        if "!is_number!"=="1" (
            set "has_prefix=1"
        )
    )

    if "!has_prefix!"=="0" (
        echo %%~ff>>"%temp_file%"
        set /a file_count+=1
    )
)

if "!file_count!"=="0" (
    echo 没有找到需要重命名的 .txt 文件
    echo.
    if exist "%temp_file%" del "%temp_file%"
    pause
    exit /b 0
)

echo 正在查找当前目录下的 .txt 文件...
echo.
echo ========================================
echo 重命名前后对比
echo ========================================
echo.

:: 从临时文件读取文件列表并处理
for /f "usebackq delims=" %%f in ("%temp_file%") do (
    set "full_path=%%f"
    set "old_name=%%~nxf"
    set "new_name=!date_str!_%%~nxf"
    set "new_path=%%~dpf!new_name!"

    :: 检查目标文件是否已存在
    if exist "!new_path!" (
        echo 跳过: !old_name!
        echo 原因: 目标文件 !new_name! 已存在
        echo ----------------------------------------
        set /a skipped_count+=1
    ) else (
        echo 旧文件名: !old_name!
        echo 新文件名: !new_name!
        echo ----------------------------------------

        ren "!full_path!" "!new_name!"
        if !errorlevel! equ 0 (
            set /a count+=1
        ) else (
            echo 重命名失败: !old_name!
            echo ----------------------------------------
            set /a skipped_count+=1
        )
    )
)

:: 清理临时文件
if exist "%temp_file%" del "%temp_file%"

echo.
echo ========================================
echo 重命名完成！
echo ========================================
echo 成功处理: !count! 个文件
echo 跳过: !skipped_count! 个文件
echo 总计: !file_count! 个文件
echo.

pause
