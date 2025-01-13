@echo off

REM - https://calculateaspectratio.com/ ~ How I got resolution calculations

REM - Remove "REM" to use command when running ".bat"
REM - Adjust color depth: "32"
REM - Adjust display refresh rate: "240"

REM - Native Display Resolution: 1920x1080 (FHD)
nircmd setdisplay 1600 1024 32 400
REM nircmd setdisplay 1728 1080 32 400

REM - Native Display Resolution: 2560x1440 (QHD)
REM nircmd setdisplay 2304 1440 32 240
REM nircmd setdisplay 2048 1280 32 240  REM - Step-down QHD resolution (16:10)

REM - Native Display Resolution: 3840x2160 (UHD)
REM nircmd setdisplay 3456 2160 32 120
REM nircmd setdisplay 3072 1920 32 120  REM - Step-down UHD resolution (16:10)
