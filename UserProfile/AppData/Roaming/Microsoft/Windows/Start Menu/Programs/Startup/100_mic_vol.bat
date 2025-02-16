start "" "cmd.exe" -e cmd /c "title Force 100% Mic Vol && nircmdc.exe loop 172800 100 setsysvolume 65535 default_record && exit"
timeout /t 1 /nobreak >nul
nircmdc.exe win min ititle "Force 100% Mic Vol"
