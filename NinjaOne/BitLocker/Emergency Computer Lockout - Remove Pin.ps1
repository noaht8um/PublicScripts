# Get OS BitLocker Volume Encryption Status
$BitLockerVolume = Get-BitLockerVolume | Where-Object { $_.VolumeType -eq 'OperatingSystem' }

# if BitLocker is not enabled on the OS, exit
if ($BitLockerVolume.ProtectionStatus -eq 'Off') {
    Write-Output 'BitLocker is not enabled on the OS volume.'
    exit 1
}

# If no recovery password is found, exit
if (-not $BitLockerVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }) {
    Write-Output 'No recovery password found for the OS volume.'
    exit 1
}

# If BitLocker is already pin-less, exit
if ($BitLockerVolume.KeyProtector.KeyProtectorType -contains 'Tpm') {
    Write-Output 'BitLocker is already pin-less.'
    exit 1
}

# Set BitLocker to pin-less
try {
    Write-Output 'Removing BitLocker PIN...'
    Add-BitLockerKeyProtector -MountPoint $BitLockerVolume.MountPoint -TpmProtector -ErrorAction Stop | Out-Null
} catch {
    Write-Output "Failed to to update BitLocker to pin-less: $($_.Exception.Message)"
    exit 1
}

# Clear the secure field in Ninja "forcedBitlockerPin"
try {
    Write-Output 'Clearing PIN in Ninja secure field...'
    Ninja-Property-Set forcedBitlockerPin $null
} catch {
    Write-Output "Failed to clear PIN in Ninja secure field: $($_.Exception.Message)"
    exit 1
}

# Force immediate restart
Write-Output 'Forcing immediate restart...'
Restart-Computer -Force
