@echo off

REM - https://calculateaspectratio.com/ ~ How I got resolution calculations

REM - Remove "REM" to use command when running ".bat"
REM - Adjust color depth: "32"
REM - Adjust display refresh rate: "240"

REM - Native Display Resolution: 1920x1080 (FHD)
nircmd setdisplay 1920 1080 32 400

REM - Native Display Resolution: 2560x1440 (QHD)
REM nircmd setdisplay 2560 1440 32 240

REM - Native Display Resolution: 3840x2160 (UHD)
REM nircmd setdisplay 3840 2160 32 120
