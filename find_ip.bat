@echo off
echo =============================================
echo    FLUTTER APP NETWORK CONFIGURATION HELPER
echo =============================================
echo.
echo Finding your computer's IP addresses...
echo.

for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr "IPv4"') do (
    set "ip=%%i"
    setlocal enabledelayedexpansion
    set "ip=!ip: =!"
    echo Found IP Address: !ip!
    echo.
    echo UPDATE YOUR FLUTTER APP:
    echo In lib/main.dart, change this line:
    echo const String API_BASE_URL = 'http://!ip!:8000';
    echo.
    echo =============================================
    endlocal
)

echo.
echo TESTING INSTRUCTIONS:
echo 1. Update the IP address in lib/main.dart
echo 2. Make sure backend server is running (python main.py)
echo 3. Make sure your phone and computer are on the SAME WiFi network
echo 4. Test the signup/login in your Flutter app
echo.
pause
