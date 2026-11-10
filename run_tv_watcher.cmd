@echo off
rem Builds the latest source and launches TV Watcher (debug).
rem Hot reload: press r in this window. Hot restart: R. Quit: q.
rem Flutter is found on PATH, then in %FLUTTER_ROOT%, then C:\src\flutter.
title TV Watcher (flutter run)
cd /d "%~dp0"

set "FLUTTER="
rem Full path is required: flutter.bat misreads a quoted bare name.
for /f "delims=" %%i in ('where flutter.bat 2^>nul') do if not defined FLUTTER set "FLUTTER=%%i"
if not defined FLUTTER if defined FLUTTER_ROOT if exist "%FLUTTER_ROOT%\bin\flutter.bat" set "FLUTTER=%FLUTTER_ROOT%\bin\flutter.bat"
if not defined FLUTTER if exist "C:\src\flutter\bin\flutter.bat" set "FLUTTER=C:\src\flutter\bin\flutter.bat"
if not defined FLUTTER (
  echo Flutter not found. Add it to PATH or set FLUTTER_ROOT.
  goto done
)

call "%FLUTTER%" run -d windows

:done
echo.
echo Finished (exit code %ERRORLEVEL%). Press any key to close this window.
pause >nul
