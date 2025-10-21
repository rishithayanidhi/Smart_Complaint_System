@echo off
echo 🚀 Starting Flutter Backend Server...
echo.

cd backend

echo 🌐 Getting your computer's IP address...
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /C:"IPv4 Address"') do set IP=%%a
set IP=%IP: =%
echo 📍 Your computer IP: %IP%
echo.

echo 🌐 Starting server on all interfaces (0.0.0.0:8000)...
echo 📱 Mobile devices can connect via: http://%IP%:8000
echo 💻 Local testing available at: http://localhost:8000
echo 🔍 Flutter app will auto-detect the connection
echo.
echo Press Ctrl+C to stop the server
echo ----------------------------------------

python main.py

if errorlevel 1 (
    echo.
    echo ❌ Error starting server
    echo.
    echo 🔧 Troubleshooting:
    echo    1. Make sure Python is installed and in PATH
    echo    2. Install dependencies: pip install -r requirements.txt
    echo    3. Check if port 8000 is already in use
    echo    4. Make sure you're in the correct directory
    echo    5. Try running: python --version
    pause
)
