@echo off
start "" "C:\Program Files\LOVE\love.exe" . --server --listen 127.0.0.1:6788 --quit-on-empty
start "" "C:\Program Files\LOVE\love.exe" . --connect 127.0.0.1:6788
