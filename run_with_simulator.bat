@echo off
REM Quick start script for Windows - runs simulator and app together

echo ==========================================
echo FlexPAL Control Suite - Quick Start
echo ==========================================
echo.

REM Check if flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Error: Flutter is not installed or not in PATH
    pause
    exit /b 1
)

REM Install dependencies if needed
if not exist ".dart_tool" (
    echo Installing dependencies...
    flutter pub get
)

echo Starting UDP Simulator on port 5006...
start "FlexPAL Simulator" dart run tools/udp_simulator.dart 127.0.0.1 5006

REM Wait for simulator to start
timeout /t 2 /nobreak >nul

echo.
echo Starting Flutter app...
echo ==========================================
flutter run -d windows

echo.
echo Closing simulator...
taskkill /FI "WindowTitle eq FlexPAL Simulator*" /T /F >nul 2>nul
