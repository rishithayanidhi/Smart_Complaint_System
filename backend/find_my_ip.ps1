Write-Host "Finding your computer's IP address for Flutter testing..." -ForegroundColor Cyan

# Get network adapters
$adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}

foreach ($adapter in $adapters) {
    $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    
    foreach ($ip in $ipConfig) {
        if ($ip.IPAddress -like "192.168.*" -or $ip.IPAddress -like "10.*" -or $ip.IPAddress -like "172.*") {
            Write-Host ""
            Write-Host "Network: $($adapter.Name)" -ForegroundColor Green
            Write-Host "IP Address: $($ip.IPAddress)" -ForegroundColor Yellow
            Write-Host "Test URL: http://$($ip.IPAddress):8000" -ForegroundColor Magenta
            
            # Test if backend is accessible on this IP
            try {
                $response = Invoke-WebRequest -Uri "http://$($ip.IPAddress):8000/health" -TimeoutSec 2 -ErrorAction Stop
                Write-Host "✅ Backend ACCESSIBLE on this IP!" -ForegroundColor Green
            } catch {
                Write-Host "❌ Backend not accessible on this IP" -ForegroundColor Red
            }
            Write-Host "----------------------------------------"
        }
    }
}

Write-Host ""
Write-Host "Instructions:" -ForegroundColor Cyan
Write-Host "1. Look for the IP marked with ✅ Backend ACCESSIBLE" -ForegroundColor White
Write-Host "2. Make sure your phone is on the SAME WiFi network" -ForegroundColor White  
Write-Host "3. The Flutter app will auto-detect this IP during startup" -ForegroundColor White
Write-Host ""
