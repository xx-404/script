@echo off
setlocal enabledelayedexpansion

:: Default parameters
set "EXTENSION=txt"
set "DATE_FORMAT=YYYYMMDD"
set "SHOW_HELP=0"

:: Parse command line arguments
:PARSE_ARGS
if "%~1"=="" goto END_PARSE_ARGS

if /i "%~1"=="-ext" (
    if "%~2"=="" (
        echo Error: Missing value for -ext parameter
        set "SHOW_HELP=1"
        goto END_PARSE_ARGS
    )
    set "EXTENSION=%~2"
    shift
    shift
    goto PARSE_ARGS
)

if /i "%~1"=="-format" (
    if "%~2"=="" (
        echo Error: Missing value for -format parameter
        set "SHOW_HELP=1"
        goto END_PARSE_ARGS
    )
    set "DATE_FORMAT=%~2"
    shift
    shift
    goto PARSE_ARGS
)

if /i "%~1"=="-h" (
    set "SHOW_HELP=1"
    shift
    goto PARSE_ARGS
)

if /i "%~1"=="-help" (
    set "SHOW_HELP=1"
    shift
    goto PARSE_ARGS
)

:: Unknown parameter
echo Error: Unknown parameter '%~1'
set "SHOW_HELP=1"
goto END_PARSE_ARGS

:END_PARSE_ARGS

:: Show help information
if "%SHOW_HELP%"=="1" (
    echo.
    echo Usage: %~nx0 [options]
    echo.
    echo Options:
    echo   -ext extension    Specify file extension to process (default: txt)
    echo   -format format    Specify date format: YYYYMMDD or YYYY-MM-DD (default: YYYYMMDD)
    echo   -h, -help         Show this help message
    echo.
    echo Examples:
    echo   %~nx0                            Process all .txt files with YYYYMMDD format
    echo   %~nx0 -ext log                   Process all .log files
    echo   %~nx0 -format YYYY-MM-DD         Use YYYY-MM-DD date format
    echo   %~nx0 -ext log -format YYYY-MM-DD   Process .log files with YYYY-MM-DD format
    echo.
    pause
    exit /b 0
)

:: Validate date format
set "PS_FORMAT="
set "PREFIX_LEN=0"

if /i "%DATE_FORMAT%"=="YYYYMMDD" (
    set "PS_FORMAT=yyyyMMdd"
    set "PREFIX_LEN=8"
) else if /i "%DATE_FORMAT%"=="YYYY-MM-DD" (
    set "PS_FORMAT=yyyy-MM-dd"
    set "PREFIX_LEN=10"
) else (
    echo Error: Invalid date format '%DATE_FORMAT%'
    echo Valid formats: YYYYMMDD or YYYY-MM-DD
    pause
    exit /b 1
)

:: Get current date using PowerShell
for /f "usebackq delims=" %%a in (`powershell -Command "Get-Date -Format '%PS_FORMAT%'"`) do (
    set "DATE_STR=%%a"
)

set "COUNT=0"
set "FILE_COUNT=0"
set "SKIPPED=0"

:: Create temp file to store file list (avoids issues with spaces in filenames)
set "TEMP_FILE=%temp%\file_list_%random%.txt"

:: First, collect all files that need to be processed
echo Collecting files with extension: .%EXTENSION%
echo.

for %%f in (*.%EXTENSION%) do (
    set "FILENAME=%%~nf"
    set "HAS_PREFIX=0"
    
    :: Check if filename already has a date prefix
    :: We need to check if:
    :: 1. Filename is long enough to contain the prefix
    :: 2. The character after the prefix is an underscore
    :: 3. The prefix matches the expected date format
    
    :: Get filename length
    set "LEN=0"
    :GET_LEN
    if not "!FILENAME:~%LEN%,1!"=="" (
        set /a LEN+=1
        goto GET_LEN
    )
    
    :: Check if filename is long enough
    set /a MIN_LEN=%PREFIX_LEN%+1
    if !LEN! geq !MIN_LEN! (
        :: Get the character after the prefix position
        set "SEP_CHAR=!FILENAME:~%PREFIX_LEN%,1!"
        
        if "!SEP_CHAR!"=="_" (
            :: Extract the potential prefix
            set "PREFIX=!FILENAME:~0,%PREFIX_LEN%!"
            
            :: Validate the prefix based on date format
            set "VALID=1"
            
            if /i "%DATE_FORMAT%"=="YYYYMMDD" (
                :: YYYYMMDD format: 8 digits
                for /l %%i in (0,1,7) do (
                    set "C=!PREFIX:~%%i,1!"
                    if "!C!" lss "0" set "VALID=0"
                    if "!C!" gtr "9" set "VALID=0"
                )
            ) else (
                :: YYYY-MM-DD format: check positions 4 and 7 are hyphens, others are digits
                :: Check hyphens at positions 4 and 7
                if not "!PREFIX:~4,1!"=="-" set "VALID=0"
                if not "!PREFIX:~7,1!"=="-" set "VALID=0"
                
                :: Check year (positions 0-3)
                if "!VALID!"=="1" (
                    for /l %%i in (0,1,3) do (
                        set "C=!PREFIX:~%%i,1!"
                        if "!C!" lss "0" set "VALID=0"
                        if "!C!" gtr "9" set "VALID=0"
                    )
                )
                
                :: Check month (positions 5-6)
                if "!VALID!"=="1" (
                    for /l %%i in (5,1,6) do (
                        set "C=!PREFIX:~%%i,1!"
                        if "!C!" lss "0" set "VALID=0"
                        if "!C!" gtr "9" set "VALID=0"
                    )
                )
                
                :: Check day (positions 8-9)
                if "!VALID!"=="1" (
                    for /l %%i in (8,1,9) do (
                        set "C=!PREFIX:~%%i,1!"
                        if "!C!" lss "0" set "VALID=0"
                        if "!C!" gtr "9" set "VALID=0"
                    )
                )
            )
            
            if "!VALID!"=="1" (
                set "HAS_PREFIX=1"
            )
        )
    )
    
    :: If no prefix, add to temp file
    if "!HAS_PREFIX!"=="0" (
        echo %%~ff>>"%TEMP_FILE%"
        set /a FILE_COUNT+=1
    )
)

:: Check if any files were found
if "%FILE_COUNT%"=="0" (
    echo No .%EXTENSION% files found to rename
    echo.
    if exist "%TEMP_FILE%" del "%TEMP_FILE%"
    pause
    exit /b 0
)

echo Found %FILE_COUNT% file(s) to process
echo Using date format: %DATE_FORMAT% (%DATE_STR%)
echo.
echo ========================================
echo Rename Comparison
echo ========================================
echo.

:: Process files from temp file
for /f "usebackq delims=" %%f in ("%TEMP_FILE%") do (
    set "FULL_PATH=%%f"
    set "OLD_NAME=%%~nxf"
    set "NEW_NAME=%DATE_STR%_%%~nxf"
    set "NEW_PATH=%%~dpf!NEW_NAME!"
    
    :: Check if target file already exists
    if exist "!NEW_PATH!" (
        echo Skipped: !OLD_NAME!
        echo Reason: Target file !NEW_NAME! already exists
        echo ----------------------------------------
        set /a SKIPPED+=1
    ) else (
        echo Old name: !OLD_NAME!
        echo New name: !NEW_NAME!
        echo ----------------------------------------
        
        ren "!FULL_PATH!" "!NEW_NAME!"
        if !errorlevel! equ 0 (
            set /a COUNT+=1
        ) else (
            echo Rename failed: !OLD_NAME!
            echo ----------------------------------------
            set /a SKIPPED+=1
        )
    )
)

:: Clean up temp file
if exist "%TEMP_FILE%" del "%TEMP_FILE%"

echo.
echo ========================================
echo Rename Completed!
echo ========================================
echo Successfully processed: !COUNT! files
echo Skipped: !SKIPPED! files
echo Total: !FILE_COUNT! files
echo.

pause
exit /b 0
