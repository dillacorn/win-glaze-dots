@echo off
start "" wt.exe -w new new-tab --title "Micro" --suppressApplicationTitle -d "%~dp1" micro "%~1"
