Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   FLUTTER APP NETWORK CONFIG HELPER   " -ForegroundColor Cyan  
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Finding your computer's IP addresses..." -ForegroundColor Yellow
Write-Host ""

# Get all IPv4 addresses
$ips = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*" }

foreach ($ip in $ips) {
    if ($ip.InterfaceAlias -like "*Wi-Fi*" -or $ip.InterfaceAlias -like "*Ethernet*") {
        Write-Host "Interface: $($ip.InterfaceAlias)" -ForegroundColor Green
        Write-Host "IP Address: $($ip.IPAddress)" -ForegroundColor Green
        Write-Host ""
        Write-Host "UPDATE YOUR FLUTTER APP:" -ForegroundColor Yellow
        Write-Host "In lib/main.dart, change this line:" -ForegroundColor White
        Write-Host "const String API_BASE_URL = 'http://$($ip.IPAddress):8000';" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "=========================================" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "TESTING STEPS:" -ForegroundColor Yellow
Write-Host "1. Update the IP address in lib/main.dart" -ForegroundColor White
Write-Host "2. Make sure backend server is running" -ForegroundColor White
Write-Host "3. Make sure phone and computer are on SAME WiFi" -ForegroundColor White
Write-Host "4. Test signup/login in Flutter app" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to continue"
