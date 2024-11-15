@echo off
setlocal

rem Set the target directory in AppData for Alacritty
set "TARGET_DIR=%APPDATA%\alacritty\themes"

rem Check if the 'themes' directory already exists
if exist "%TARGET_DIR%" (
    echo The 'themes' directory already exists in %TARGET_DIR%. Checking for updates...

    rem Navigate to the themes directory
    cd /d "%TARGET_DIR%"

    rem Fetch the latest changes from the remote repository
    git fetch origin

    rem Determine the default branch name
    for /f "tokens=*" %%B in ('git remote show origin ^| findstr /i "HEAD branch"') do (
        for %%C in (%%B) do set "DEFAULT_BRANCH=%%C"
    )
    set "DEFAULT_BRANCH=%DEFAULT_BRANCH:~-1%"

    rem Get the latest commit hash on the remote default branch
    for /f %%D in ('git rev-parse "origin/%DEFAULT_BRANCH%"') do set "REMOTE_COMMIT=%%D"
    for /f %%E in ('git rev-parse HEAD') do set "LOCAL_COMMIT=%%E"

    if not "%LOCAL_COMMIT%"=="%REMOTE_COMMIT%" (
        echo Updating 'themes' directory to the latest version...
        git reset --hard "origin/%DEFAULT_BRANCH%"
    ) else (
        echo The 'themes' directory is up-to-date.
    )
) else (
    rem Clone the alacritty-theme repository if it does not exist
    git clone https://github.com/alacritty/alacritty-theme "%TARGET_DIR%"
    if errorlevel 1 (
        echo Error: Failed to clone the repository. Exiting.
        exit /b 1
    )
)

echo Finished running install_alacritty_themes.bat. 'themes' directory placed in %TARGET_DIR%
exit /b 0
