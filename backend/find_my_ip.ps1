#!/usr/bin/env pwsh
param(
    [switch]$Test = $false,
    [switch]$Cache = $false,
    [switch]$Clear = $false
)

# Create logs directory
if (!(Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" -Force | Out-Null
}

if ($Clear) {
    Remove-Item -Path "logs/last_ip.txt" -ErrorAction SilentlyContinue
    Write-Host "🗑️  Cleared cached IP addresses" -ForegroundColor Green
    exit 0
}

Write-Host "🔍 Flutter Backend IP Discovery Tool" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check cached IP first if requested
if ($Cache -and (Test-Path "logs/last_ip.txt")) {
    $cachedIP = Get-Content "logs/last_ip.txt" -Raw -ErrorAction SilentlyContinue
    if (![string]::IsNullOrWhiteSpace($cachedIP)) {
        $cachedIP = $cachedIP.Trim()
        Write-Host "📋 Checking cached IP: $cachedIP" -ForegroundColor Yellow
        
        try {
            $response = Invoke-WebRequest -Uri "http://$cachedIP:8000/health" -TimeoutSec 2 -ErrorAction Stop
            Write-Host "✅ Cached IP is working: http://$cachedIP:8000" -ForegroundColor Green
            Write-Host ""
            Write-Host "🚀 Use this URL in your Flutter app or it will auto-detect" -ForegroundColor Cyan
            exit 0
        } catch {
            Write-Host "❌ Cached IP is not responding, scanning network..." -ForegroundColor Yellow
            Write-Host ""
        }
    }
}

Write-Host "🔍 Scanning network interfaces..." -ForegroundColor Yellow

# Get network adapters
$adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.Name -notlike "*Loopback*"}
$workingIps = @()
$allIps = @()

foreach ($adapter in $adapters) {
    $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    
    foreach ($ip in $ipConfig) {
        if ($ip.IPAddress -like "192.168.*" -or $ip.IPAddress -like "10.*" -or ($ip.IPAddress -like "172.*" -and $ip.IPAddress -ne "172.17.0.1")) {
            $allIps += @{
                IP = $ip.IPAddress
                Network = $adapter.Name
                Status = "Unknown"
                URL = "http://$($ip.IPAddress):8000"
            }
        }
    }
}

Write-Host "📱 Found $($allIps.Count) potential IP address(es)" -ForegroundColor Green
Write-Host ""

# Test each IP if requested or if server is running
if ($Test -or $allIps.Count -eq 0) {
    Write-Host "🧪 Testing server accessibility..." -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($ipInfo in $allIps) {
        Write-Host "Testing $($ipInfo.IP) ..." -NoNewline
        
        try {
            $response = Invoke-WebRequest -Uri "$($ipInfo.URL)/health" -TimeoutSec 1 -ErrorAction Stop
            $ipInfo.Status = "✅ WORKING"
            $workingIps += $ipInfo
            Write-Host " ✅ ACCESSIBLE" -ForegroundColor Green
        } catch {
            $ipInfo.Status = "❌ Not accessible"
            Write-Host " ❌ Not accessible" -ForegroundColor Red
        }
    }
    Write-Host ""
}

# Display results
Write-Host "📋 Network Summary:" -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan
foreach ($ipInfo in $allIps) {
    Write-Host "Network: $($ipInfo.Network)" -ForegroundColor White
    Write-Host "IP: $($ipInfo.IP)" -ForegroundColor Yellow
    Write-Host "URL: $($ipInfo.URL)" -ForegroundColor Magenta
    if ($Test) {
        Write-Host "Status: $($ipInfo.Status)" -ForegroundColor $(if ($ipInfo.Status -like "*WORKING*") { "Green" } else { "Red" })
    }
    Write-Host "------------------------"
}

# Save working IP to cache
if ($workingIps.Count -gt 0) {
    $workingIps[0].IP | Out-File -FilePath "logs/last_ip.txt" -Encoding UTF8 -NoNewline
    Write-Host ""
    Write-Host "🎯 RECOMMENDED IP: $($workingIps[0].IP)" -ForegroundColor Green
    Write-Host "🔗 Flutter will auto-detect: $($workingIps[0].URL)" -ForegroundColor Cyan
} elseif ($allIps.Count -gt 0) {
    $allIps[0].IP | Out-File -FilePath "logs/last_ip.txt" -Encoding UTF8 -NoNewline
    Write-Host ""
    Write-Host "💡 SUGGESTED IP: $($allIps[0].IP)" -ForegroundColor Yellow
    Write-Host "🔗 Try: $($allIps[0].URL)" -ForegroundColor Cyan
    if (!$Test) {
        Write-Host ""
        Write-Host "💡 Run with -Test to check server accessibility" -ForegroundColor Blue
    }
}

Write-Host ""
Write-Host "📱 Instructions:" -ForegroundColor Cyan
Write-Host "1. Make sure your phone is on the SAME WiFi network" -ForegroundColor White  
Write-Host "2. Start the backend server (python main.py)" -ForegroundColor White
Write-Host "3. The Flutter app will automatically detect the server" -ForegroundColor White
Write-Host "4. If auto-detection fails, restart the Flutter app" -ForegroundColor White
Write-Host ""
Write-Host "🔧 Available commands:" -ForegroundColor Blue
Write-Host "   .\find_my_ip.ps1 -Test    # Test server accessibility"
Write-Host "   .\find_my_ip.ps1 -Cache   # Use cached IP if available"
Write-Host "   .\find_my_ip.ps1 -Clear   # Clear cached IP"
Write-Host ""
