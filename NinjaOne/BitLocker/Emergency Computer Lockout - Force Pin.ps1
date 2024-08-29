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

# Generate secure 8-digit PIN
$Rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
$Pin = [System.Security.SecureString]::new()
do {
    $Bytes = [System.Byte[]]::new(1)
    $Rng.GetBytes($Bytes)
    if ($Bytes[0] -ge 48 -and $Bytes[0] -le 57) {
        $Pin.AppendChar([char]$Bytes[0])
    }
} while ($Pin.Length -lt 8)

# If PIN generation failed, exit
if ($Pin.Length -ne 8) {
    Write-Output 'Failed to generate 8-digit PIN.'
    exit 1
}

# Use a TPM+PIN key protector to lockout the system
try {
    # Set BitLocker PIN
    Write-Output 'Setting BitLocker to use PIN...'
    Add-BitLockerKeyProtector -MountPoint $BitLockerVolume.MountPoint -TPMAndPinProtector -Pin $Pin -ErrorAction Stop | Out-Null
} catch {
    Write-Output "Failed to set BitLocker PIN: $($_.Exception.Message)"
    exit 1
}

# Store the PIN in Ninja "forcedBitLockerPin" secure field
try {
    Write-Output 'Storing PIN in Ninja secure field...'
    Ninja-Property-Set forcedBitlockerPin ([System.Management.Automation.PSCredential]::new(0, $Pin)).GetNetworkCredential().Password
} catch {
    Write-Output "Failed to store PIN in Ninja secure field: $($_.Exception.Message)"
    exit 1
}

# Force immediate restart
Write-Output 'Forcing immediate restart...'
Restart-Computer -Force
