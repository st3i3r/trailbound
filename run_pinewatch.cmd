@echo off
REM Launch the Pinewatch test scene — double-click this file.
REM --dev-ui: show dev chrome (status/report lines); drop it for clean runs.
"C:\Users\tomog3s\AppData\Local\Microsoft\WinGet\Links\godot.cmd" --path "%~dp0game" "res://scenes/pinewatch_test.tscn" --dev-ui
pause
