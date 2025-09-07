@echo off
echo 🚀 Starting Flutter Backend Server...
echo.

cd backend

echo 🌐 Starting server on all interfaces (0.0.0.0:8000)...
echo 📱 Mobile devices will auto-connect via network IP
echo 💻 Local testing available at: http://localhost:8000
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
    pause
)
