@echo off
:menu
echo ===========================
echo Choose a .bat file to run:
echo ===========================
setlocal enabledelayedexpansion
set count=1
for %%f in (*.bat) do (
    if /i not "%%~nf"=="menu" if /i not "%%~nf"=="open_with_micro" (
        echo !count!. %%~nf
        set "option[!count!]=%%f"
        set /a count+=1
    )
)
echo ===========================
set /p choice="Enter the number of the script to run or 'q' to quit: "

if /i "%choice%"=="q" goto :eof
if defined option[%choice%] (
    echo Running !option[%choice%]!
    call !option[%choice%]!
) else (
    echo Invalid choice. Try again.
)
pause
goto menu
