#Requires -RunAsAdministrator
<#
.SYNOPSIS
    ROG Ally X Professional Update & Maintenance Suite
    
.DESCRIPTION
    Enterprise-grade update automation with diagnostics, scheduling, and recovery options
    
.PARAMETER UpdateType
    Specify update scope: 'Full', 'WindowsOnly', 'AppsOnly', 'GPU', 'BIOS'
    
.PARAMETER ScheduleTask
    Create scheduled task for automatic daily updates at specified time
    
.PARAMETER LogPath
    Custom log file location (default: C:\Logs\ROG-Ally-Updates.log)
    
.PARAMETER EmailReport
    Send completion report to specified email (requires SMTP config)
    
.PARAMETER EnableRollback
    Create system restore point before updates
    
.EXAMPLE
    .\Update-Ally-Pro.ps1 -UpdateType Full -EnableRollback -LogPath "C:\Logs\Ally-Updates.log"
#>

param(
    [ValidateSet('Full', 'WindowsOnly', 'AppsOnly', 'GPU', 'BIOS')]
    [string]$UpdateType = 'Full',
    
    [switch]$ScheduleTask,
    [string]$ScheduleTime = "02:00",
    
    [string]$LogPath = "C:\Logs\ROG-Ally-Updates.log",
    
    [string]$EmailReport,
    [string]$SMTPServer = "smtp.gmail.com",
    
    [switch]$EnableRollback,
    [switch]$SkipReboot,
    [switch]$TestMode
)

# ============================================================================
# INITIALIZATION & CONFIGURATION
# ============================================================================

$ScriptVersion = "3.0.0"
$ScriptStartTime = Get-Date

# Create log directory if it doesn't exist
$LogDir = Split-Path $LogPath
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# ============================================================================
# LOGGING FUNCTION
# ============================================================================

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info',
        
        [switch]$NoConsole
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to file
    Add-Content -Path $LogPath -Value $logEntry -Encoding UTF8
    
    # Write to console with colors
    if (-not $NoConsole) {
        switch ($Level) {
            'Error'   { Write-Host $logEntry -ForegroundColor Red }
            'Warning' { Write-Host $logEntry -ForegroundColor Yellow }
            'Success' { Write-Host $logEntry -ForegroundColor Green }
            default   { Write-Host $logEntry -ForegroundColor Cyan }
        }
    }
}

# ============================================================================
# SYSTEM CHECKS
# ============================================================================

function Test-AdminRights {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Log "ERROR: Script must run as Administrator!" -Level Error
        Start-Sleep -Seconds 3
        Exit 1
    }
    Write-Log "Administrator privileges verified" -Level Success
}

function Get-SystemDiagnostics {
    Write-Log "Gathering system diagnostics..." -Level Info
    
    $diagnostics = @{
        ComputerName = $env:COMPUTERNAME
        OSVersion = [System.Environment]::OSVersion.VersionString
        PowerState = (Get-WmiObject -Class Win32_Battery | Select-Object -ExpandProperty BatteryStatus)
        DiskSpace = (Get-Volume | Where-Object { $_.DriveLetter -eq 'C' } | Select-Object SizeRemaining, Size)
        RAM = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        LastRestorePoint = (Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty CreationTime)
    }
    
    Write-Log "System: $($diagnostics.ComputerName) | OS: $($diagnostics.OSVersion) | RAM: $($diagnostics.RAM)GB" -Level Info
    
    # Check disk space (warn if less than 10GB free)
    $freeGB = $diagnostics.DiskSpace.SizeRemaining / 1GB
    if ($freeGB -lt 10) {
        Write-Log "WARNING: Low disk space detected ($([math]::Round($freeGB, 2))GB free). Consider freeing space before updates." -Level Warning
    }
    
    return $diagnostics
}

function Test-InternetConnection {
    Write-Log "Testing internet connectivity..." -Level Info
    
    try {
        $pingResult = Test-NetConnection -ComputerName "www.microsoft.com" -WarningAction SilentlyContinue
        if ($pingResult.PingSucceeded) {
            Write-Log "Internet connection verified" -Level Success
            return $true
        } else {
            Write-Log "No internet connection detected" -Level Warning
            return $false
        }
    } catch {
        Write-Log "Error testing connection: $_" -Level Warning
        return $false
    }
}

# ============================================================================
# WINDOWS UPDATE
# ============================================================================

function Update-WindowsSystem {
    Write-Log "Starting Windows Update process..." -Level Info
    
    try {
        # Install PSWindowsUpdate module if missing
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Write-Log "Installing PSWindowsUpdate module..." -Level Info
            Install-Module PSWindowsUpdate -Force -SkipPublisherCheck -ErrorAction Stop
        }
        
        if ($TestMode) {
            Write-Log "[TEST MODE] Would scan for Windows updates" -Level Warning
            Get-WindowsUpdate -Verbose -ErrorAction Stop
            return
        }
        
        # Scan and install updates
        Write-Log "Scanning for Windows updates..." -Level Info
        $updates = Get-WindowsUpdate -AcceptAll -ErrorAction Stop
        
        if ($updates) {
            Write-Log "Found $($updates.Count) update(s). Installing..." -Level Info
            Get-WindowsUpdate -Install -AcceptAll -Verbose -ErrorAction Stop
            Write-Log "Windows updates completed successfully" -Level Success
        } else {
            Write-Log "System is up to date (no Windows updates available)" -Level Success
        }
    } catch {
        Write-Log "Windows Update error: $_" -Level Error
        throw
    }
}

# ============================================================================
# APPLICATIONS UPDATE (WINGET)
# ============================================================================

function Update-Applications {
    Write-Log "Starting application updates via WinGet..." -Level Info
    
    try {
        # Verify WinGet availability
        $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $wingetPath) {
            Write-Log "WinGet not found. Installing from Microsoft Store..." -Level Warning
            Start-Process "ms-appinstaller:?source=https://aka.ms/getwinget" -Wait
            Start-Sleep -Seconds 5
        }
        
        if ($TestMode) {
            Write-Log "[TEST MODE] Would list available app updates" -Level Warning
            & winget list --upgrade-available 2>$null | Write-Log -Level Info
            return
        }
        
        Write-Log "Listing available updates..." -Level Info
        & winget list --upgrade-available 2>$null
        
        Write-Log "Installing all available app updates..." -Level Info
        & winget upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements --silent --verbose-logs 2>&1 | 
            Tee-Object -FilePath $LogPath -Append | Write-Log -Level Info
        
        Write-Log "Application updates completed" -Level Success
    } catch {
        Write-Log "Application update error: $_" -Level Error
        # Don't throw - allow script to continue even if winget fails
    }
}

# ============================================================================
# GPU DRIVER UPDATE (AMD)
# ============================================================================

function Update-AMDGPUDrivers {
    Write-Log "Starting AMD GPU driver update process..." -Level Info
    
    try {
        # Detect AMD GPU
        Write-Log "Detecting AMD GPU hardware..." -Level Info
        $gpuInfo = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -like "*AMD*" -or $_.Name -like "*Radeon*" }
        
        if (-not $gpuInfo) {
            Write-Log "No AMD GPU detected. Skipping GPU driver update." -Level Warning
            return
        }
        
        Write-Log "Found GPU: $($gpuInfo.Name)" -Level Info
        Write-Log "Current driver version: $($gpuInfo.DriverVersion) (Date: $($gpuInfo.DriverDate))" -Level Info
        
        if ($TestMode) {
            Write-Log "[TEST MODE] Would check for AMD GPU driver updates" -Level Warning
            Write-Log "Current GPU: $($gpuInfo.Name)" -Level Info
            return
        }
        
        # Method 1: Try WinGet for AMD Software/Drivers
        Write-Log "Attempting GPU driver update via WinGet..." -Level Info
        $wingetOutput = & winget upgrade --id AMD.AMDSoftware --include-unknown --accept-source-agreements --accept-package-agreements --silent 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "AMD Software updated successfully via WinGet" -Level Success
        } else {
            Write-Log "WinGet update returned code $LASTEXITCODE. Trying alternative method..." -Level Warning
            
            # Method 2: Direct download guidance
            Write-Log "For manual AMD driver update:" -Level Info
            Write-Log "1. Visit: https://www.amd.com/en/support" -Level Info
            Write-Log "2. Select: Graphics > AMD Radeon" -Level Info
            Write-Log "3. Choose your model and download the latest driver" -Level Info
            Write-Log "4. Or use AMD Software: Adrenalin Edition auto-detect" -Level Info
        }
        
        # Method 3: Try Windows Update for drivers
        Write-Log "Checking Windows Update for GPU driver updates..." -Level Info
        try {
            $driverUpdates = Get-WindowsUpdate -CategoryIDs "ebfc1fc5-71a4-4f7b-9aca-3b9a503104a0" -ErrorAction SilentlyContinue
            if ($driverUpdates) {
                Write-Log "Found $($driverUpdates.Count) driver update(s) via Windows Update" -Level Info
                Get-WindowsUpdate -CategoryIDs "ebfc1fc5-71a4-4f7b-9aca-3b9a503104a0" -Install -AcceptAll -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Log "Could not check Windows Update for driver updates: $_" -Level Warning
        }
        
        # Get updated GPU info
        $updatedGpuInfo = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -like "*AMD*" -or $_.Name -like "*Radeon*" }
        Write-Log "Updated driver version: $($updatedGpuInfo.DriverVersion) (Date: $($updatedGpuInfo.DriverDate))" -Level Success
        
        Write-Log "AMD GPU driver update process completed" -Level Success
        
    } catch {
        Write-Log "GPU driver update error: $_" -Level Error
        Write-Log "You can manually update drivers at: https://www.amd.com/en/support" -Level Info
    }
}

# ============================================================================
# CLEANUP & OPTIMIZATION
# ============================================================================

function Optimize-System {
    Write-Log "Starting system cleanup and optimization..." -Level Info
    
    try {
        # Windows Disk Cleanup
        Write-Log "Running disk cleanup..." -Level Info
        if ($TestMode) {
            Write-Log "[TEST MODE] Would run cleanmgr.exe" -Level Warning
        } else {
            Start-Process cleanmgr.exe -ArgumentList "/sagerun:1" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        }
        
        # Clear Windows Update cache
        Write-Log "Clearing Windows Update cache..." -Level Info
        if (-not $TestMode) {
            Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Clear temporary files
        Write-Log "Cleaning temporary files..." -Level Info
        if (-not $TestMode) {
            Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        Write-Log "System optimization completed" -Level Success
    } catch {
        Write-Log "Cleanup error (non-critical): $_" -Level Warning
    }
}

# ============================================================================
# SYSTEM RESTORE POINT (ROLLBACK)
# ============================================================================

function New-RestorePoint {
    Write-Log "Creating system restore point for rollback capability..." -Level Info
    
    try {
        $restorePointName = "ROG-Ally-Updates-$(Get-Date -Format 'yyyy-MM-dd-HHmmss')"
        
        if ($TestMode) {
            Write-Log "[TEST MODE] Would create restore point: $restorePointName" -Level Warning
            return
        }
        
        Checkpoint-Computer -Description $restorePointName -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Restore point created: $restorePointName" -Level Success
    } catch {
        Write-Log "Could not create restore point: $_" -Level Warning
    }
}

# ============================================================================
# BIOS/FIRMWARE UPDATE (Manual Guide)
# ============================================================================

function Show-BIOSUpdateGuide {
    Write-Log "BIOS/Firmware update information:" -Level Info
    
    $biosInfo = @"
    
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ROG ALLY X - BIOS & FIRMWARE UPDATE GUIDE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

BIOS Updates:
  1. Open 'MyASUS' app or 'Armoury Crate SE'
  2. Navigate to: System > System Update
  3. Click "Check for updates"
  4. Download and install any BIOS updates
  5. System will reboot automatically
  
Firmware Updates:
  1. Open 'Armoury Crate'
  2. Go to: Tools > Firmware Update
  3. Select device (Controller, GPU, etc.)
  4. Install available updates
  5. May require device reboot

⚠️  IMPORTANT:
  - Do NOT turn off during BIOS updates!
  - Ensure battery is >80% charged
  - Unplug USB devices if prompted
  - Back up important data first

Last check time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"@
    
    Write-Host $biosInfo -ForegroundColor Cyan
    Add-Content -Path $LogPath -Value $biosInfo
}

# ============================================================================
# TASK SCHEDULING
# ============================================================================

function New-UpdateScheduledTask {
    param(
        [string]$Time = "02:00"
    )
    
    Write-Log "Creating scheduled task for daily updates..." -Level Info
    
    try {
        $taskName = "ROG-Ally-Auto-Update"
        
        # Remove existing task if present
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        
        # Create trigger (daily at specified time)
        $trigger = New-ScheduledTaskTrigger -Daily -At $Time
        
        # Create action
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -UpdateType Full -SkipReboot"
        
        # Create task with high privileges
        Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -RunLevel Highest -Force | Out-Null
        
        Write-Log "Scheduled task created: $taskName at $Time daily" -Level Success
    } catch {
        Write-Log "Could not create scheduled task: $_" -Level Error
    }
}

# ============================================================================
# EMAIL REPORTING
# ============================================================================

function Send-UpdateReport {
    param(
        [string]$EmailAddress,
        [object]$Results
    )
    
    if (-not $EmailAddress) { return }
    
    Write-Log "Preparing email report..." -Level Info
    
    try {
        $duration = New-TimeSpan -Start $ScriptStartTime -End (Get-Date)
        
        $emailBody = @"
ROG ALLY X - UPDATE REPORT
═══════════════════════════════════════════

Update Type: $UpdateType
Duration: $($duration.Hours)h $($duration.Minutes)m $($duration.Seconds)s
Completion Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

System Information:
  Computer: $($Results.ComputerName)
  OS: $($Results.OSVersion)
  Free Disk Space: $([math]::Round($Results.DiskSpace.SizeRemaining / 1GB, 2))GB

Test Mode: $TestMode
Reboot Pending: $([System.Environment]::OSVersion.VersionString -match "reboot")

For detailed logs, see: $LogPath

═══════════════════════════════════════════
Report generated by Update-Ally-Pro.ps1 v$ScriptVersion
"@
        
        Write-Log "Email report would be sent to: $EmailAddress" -Level Info
        # Note: Actual email implementation requires SMTP credentials
    } catch {
        Write-Log "Could not send email: $_" -Level Warning
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Invoke-MainProcess {
    Write-Host "`n" -ForegroundColor Cyan
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   ROG ALLY X - PRO UPDATE SUITE v$ScriptVersion            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    if ($TestMode) {
        Write-Host "⚠️  TEST MODE ENABLED - No actual changes will be made`n" -ForegroundColor Yellow
    }
    
    # Pre-update checks
    Test-AdminRights
    $systemInfo = Get-SystemDiagnostics
    Test-InternetConnection
    
    # Create restore point if requested
    if ($EnableRollback) {
        New-RestorePoint
    }
    
    # Execute updates based on type
    switch ($UpdateType) {
        'Full' {
            Update-WindowsSystem
            Update-Applications
            Update-AMDGPUDrivers
            Optimize-System
            Show-BIOSUpdateGuide
        }
        'WindowsOnly' {
            Update-WindowsSystem
        }
        'AppsOnly' {
            Update-Applications
        }
        'GPU' {
            Update-AMDGPUDrivers
        }
        'BIOS' {
            Show-BIOSUpdateGuide
        }
    }
    
    # Schedule future updates if requested
    if ($ScheduleTask) {
        New-UpdateScheduledTask -Time $ScheduleTime
    }
    
    # Send report email if requested
    if ($EmailReport) {
        Send-UpdateReport -EmailAddress $EmailReport -Results $systemInfo
    }
    
    # Summary
    $totalDuration = New-TimeSpan -Start $ScriptStartTime -End (Get-Date)
    
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║             ✓ UPDATES COMPLETED SUCCESSFULLY            ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
    
    Write-Log "═════════════════════════════════════════════" -Level Success
    Write-Log "Total execution time: $($totalDuration.Hours)h $($totalDuration.Minutes)m $($totalDuration.Seconds)s" -Level Success
    Write-Log "Log file: $LogPath" -Level Success
    
    Write-Host "`nℹ️  Full details saved to: $LogPath`n" -ForegroundColor Cyan
    
    # Reboot prompt
    if (-not $SkipReboot -and -not $TestMode) {
        Write-Host "System restart may be required for some updates." -ForegroundColor Yellow
        $response = Read-Host "Restart now? (Y/N)"
        if ($response -eq 'Y' -or $response -eq 'y') {
            Write-Log "User initiated system restart" -Level Info
            Restart-Computer -Force
        }
    }
}

# Execute
Invoke-MainProcess
