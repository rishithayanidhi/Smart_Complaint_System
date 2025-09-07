#!/usr/bin/env pwsh
param(
    [switch]$ShowIP = $false,
    [switch]$Help = $false
)

if ($Help) {
    Write-Host "🚀 Flutter Backend Server Starter" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\start_server.ps1           # Start server normally"
    Write-Host "  .\start_server.ps1 -ShowIP   # Show available IPs and start server"
    Write-Host "  .\start_server.ps1 -Help     # Show this help"
    Write-Host ""
    exit 0
}

Write-Host "🚀 Starting Flutter Backend Server..." -ForegroundColor Cyan
Write-Host ""

# Change to backend directory
Set-Location -Path "backend"

if ($ShowIP -or !(Test-Path "logs/last_ip.txt")) {
    Write-Host "🔍 Detecting available IP addresses..." -ForegroundColor Yellow
    Write-Host ""
    
    # Get network adapters
    $adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.Name -notlike "*Loopback*"}
    $foundIps = @()
    
    foreach ($adapter in $adapters) {
        $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        
        foreach ($ip in $ipConfig) {
            if ($ip.IPAddress -like "192.168.*" -or $ip.IPAddress -like "10.*" -or ($ip.IPAddress -like "172.*" -and ![string]::IsNullOrEmpty($ip.IPAddress))) {
                $foundIps += $ip.IPAddress
                Write-Host "📱 Network: $($adapter.Name)" -ForegroundColor Green
                Write-Host "   IP: $($ip.IPAddress)" -ForegroundColor Yellow
                Write-Host "   Flutter will auto-detect: http://$($ip.IPAddress):8000" -ForegroundColor Magenta
                Write-Host ""
            }
        }
    }
    
    if ($foundIps.Count -gt 0) {
        # Save the first IP for caching
        $foundIps[0] | Out-File -FilePath "logs/last_ip.txt" -Encoding UTF8
        Write-Host "✅ Found $($foundIps.Count) available IP(s)" -ForegroundColor Green
    } else {
        Write-Host "⚠️  No network IPs found. Server will be available on localhost only." -ForegroundColor Yellow
    }
    
    Write-Host "📝 Instructions for mobile testing:" -ForegroundColor Cyan
    Write-Host "   1. Make sure your phone is on the SAME WiFi network" -ForegroundColor White
    Write-Host "   2. The Flutter app will automatically detect the server" -ForegroundColor White
    Write-Host "   3. If detection fails, restart the app to retry" -ForegroundColor White
    Write-Host ""
}

Write-Host "🌐 Starting server on all interfaces (0.0.0.0:8000)..." -ForegroundColor Green
Write-Host "📱 Mobile devices will auto-connect via network IP" -ForegroundColor Green
Write-Host "💻 Local testing available at: http://localhost:8000" -ForegroundColor Green
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray

# Start the Python server
try {
    python main.py
} catch {
    Write-Host ""
    Write-Host "❌ Error starting server: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔧 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   1. Make sure Python is installed and in PATH" -ForegroundColor White
    Write-Host "   2. Install dependencies: pip install -r requirements.txt" -ForegroundColor White
    Write-Host "   3. Check if port 8000 is already in use" -ForegroundColor White
    exit 1
}
