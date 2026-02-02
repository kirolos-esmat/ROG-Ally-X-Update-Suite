# ROG Ally X Pro Update Suite - User Guide

## Overview

This is a **professional-grade** version of the update script with enterprise features including:

- ✅ Comprehensive error handling & logging
- ✅ System diagnostics & health checks
- ✅ AMD GPU driver updates (automatic detection)
- ✅ Rollback capability (system restore points)
- ✅ Scheduled automated updates
- ✅ Test/dry-run mode
- ✅ Email reporting
- ✅ Detailed audit trails

---

## Installation

1. **Save the script** as `Update-Ally-Pro.ps1` in a safe location, like:

   ```
   C:\Scripts\Update-Ally-Pro.ps1
   ```

2. **Allow script execution** (one-time setup):

   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Run as Administrator**

---

## Usage Examples

### Basic Usage (Full System Update)

```powershell
.\Update-Ally-Pro.ps1
```

### Update Only Windows

```powershell
.\Update-Ally-Pro.ps1 -UpdateType WindowsOnly
```

### Update Only Applications

```powershell
.\Update-Ally-Pro.ps1 -UpdateType AppsOnly
```

### Update AMD GPU Drivers Only

```powershell
.\Update-Ally-Pro.ps1 -UpdateType GPU
```

### Full Update with Rollback Protection

```powershell
.\Update-Ally-Pro.ps1 -UpdateType Full -EnableRollback
```

### Test Mode (Preview without Changes)

```powershell
.\Update-Ally-Pro.ps1 -UpdateType Full -TestMode
```

### Create Scheduled Daily Updates

```powershell
.\Update-Ally-Pro.ps1 -ScheduleTask -ScheduleTime "02:00" -UpdateType Full
```

### Custom Log Location

```powershell
.\Update-Ally-Pro.ps1 -LogPath "E:\Logs\Ally-Updates.log"
```

### Skip Reboot Prompt

```powershell
.\Update-Ally-Pro.ps1 -SkipReboot
```

---

## Parameter Reference

| Parameter        | Type   | Default        | Description                                  |
| ---------------- | ------ | -------------- | -------------------------------------------- |
| `UpdateType`     | String | Full           | Type: Full, WindowsOnly, AppsOnly, GPU, BIOS |
| `ScheduleTask`   | Switch | False          | Create daily automated update task           |
| `ScheduleTime`   | String | 02:00          | Time for scheduled updates (24-hour format)  |
| `LogPath`        | String | C:\Logs\       | Location for detailed logs                   |
| `EmailReport`    | String | —              | Email address for completion report          |
| `SMTPServer`     | String | smtp.gmail.com | SMTP server for email reporting              |
| `EnableRollback` | Switch | False          | Create system restore point before updating  |
| `SkipReboot`     | Switch | False          | Don't prompt for reboot                      |
| `TestMode`       | Switch | False          | Dry-run mode (preview without changes)       |

---

## Advanced Examples

### Complete Pro Setup (Everything)

```powershell
.\Update-Ally-Pro.ps1 `
  -UpdateType Full `
  -EnableRollback `
  -ScheduleTask `
  -ScheduleTime "03:00" `
  -LogPath "C:\Logs\ROG-Ally-Updates.log" `
  -SkipReboot
```

### Test Before Full Deployment

```powershell
# First, preview what would happen:
.\Update-Ally-Pro.ps1 -UpdateType Full -TestMode

# If satisfied, run for real:
.\Update-Ally-Pro.ps1 -UpdateType Full -EnableRollback
```

### Scheduled Maintenance (Auto-runs at 2 AM Daily)

```powershell
.\Update-Ally-Pro.ps1 -ScheduleTask -ScheduleTime "02:00"
```

---

## Features Explained

### 🔍 System Diagnostics

- Checks available disk space (warns if <10GB)
- Verifies internet connectivity
- Collects system information for reporting
- Monitors available RAM

### 🎮 AMD GPU Driver Updates

- Automatically detects AMD/Radeon GPU
- Shows current driver version and date
- Updates via multiple methods (WinGet, Windows Update)
- Displays driver version before and after update
- Provides manual update guidance if needed

### 💾 Logging

- **Detailed audit trail** saved to log file
- Color-coded console output (Info, Warning, Error, Success)
- Timestamp on every entry
- Non-intrusive (also logged to file with -NoConsole flag)

### 🔄 Rollback Protection

- Creates system restore points before updates
- Named with timestamp for easy identification
- Can be used to revert if issues occur

### ⏰ Automatic Scheduling

- Sets up Windows scheduled task
- Runs at specified time daily
- Can be modified or disabled in Task Scheduler

### 📧 Email Reporting

- Sends update completion summary
- Includes duration, system info, and status
- _(Requires SMTP configuration for actual sending)_

### 🧪 Test Mode

- Preview all updates without applying them
- Dry-run functionality
- Perfect for validating before production runs

---

## Log File Location

All logs are saved to (customizable):

```
C:\Logs\ROG-Ally-Updates.log
```

View latest logs:

```powershell
Get-Content -Path "C:\Logs\ROG-Ally-Updates.log" -Tail 50
```

---

## Troubleshooting

### "Script cannot be loaded because running scripts is disabled"

**Solution:**

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "PSWindowsUpdate module not found"

The script auto-installs it. If manual install needed:

```powershell
Install-Module PSWindowsUpdate -Force -SkipPublisherCheck
```

### "WinGet not found"

The script attempts auto-installation from Microsoft Store. Manual install:

```powershell
Start-Process "ms-appinstaller:?source=https://aka.ms/getwinget"
```

### Script hangs during updates

- Press `Ctrl+C` to cancel
- Check log file for what was running
- Run with `-TestMode` first to verify

### GPU driver update fails

**Solution:**

```powershell
# Try manual update via AMD Software
# Or visit: https://www.amd.com/en/support
# Use auto-detect feature for ROG Ally X
```

Alternatively, update through Windows Update:

```powershell
.\Update-Ally-Pro.ps1 -UpdateType WindowsOnly
```

---

## Scheduled Task Management

### View scheduled tasks

```powershell
Get-ScheduledTask -TaskName "ROG-Ally-Auto-Update"
```

### Disable scheduled task

```powershell
Disable-ScheduledTask -TaskName "ROG-Ally-Auto-Update"
```

### Remove scheduled task

```powershell
Unregister-ScheduledTask -TaskName "ROG-Ally-Auto-Update" -Confirm:$false
```

### View scheduled task history

```powershell
Get-ScheduledTaskInfo -TaskName "ROG-Ally-Auto-Update"
```

---

## Security Notes

- ✅ Script requires Administrator privileges (verified at startup)
- ✅ Handles elevation automatically on compatible systems
- ✅ Logs all actions for audit trail
- ✅ No credentials stored in script
- ✅ Safe for production use on ROG Ally X

---

## Version History

- **v3.0.1** - Added AMD GPU driver update functionality
- **v3.0.0** - Pro Suite with full diagnostics, scheduling, and rollback
- v2.0.0 - Added logging and error handling
- v1.0.0 - Basic update script

---

## Support & Tips

**Best Practices:**

1. Always run with `-EnableRollback` first time
2. Use `-TestMode` before production runs
3. Schedule updates during low-usage hours (2-4 AM)
4. Keep log file for troubleshooting
5. Update GPU drivers monthly for best gaming performance
6. Check BIOS/Firmware manually in Armoury Crate monthly

**Backup First:**

```powershell
# Create manual restore point before running
Checkpoint-Computer -Description "Pre-Update Backup" -RestorePointType "MODIFY_SETTINGS"
```

---

_For ROG Ally X running Windows 11_  
_Compatible with both standard and elevated command prompts_
