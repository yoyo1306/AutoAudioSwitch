# Auto-switch audio/mic for Windows 11
# Règles:
#   - Pixel Buds connectés  -> sortie + micro Pixel (pas Hands-Free)
#   - Razer allumé (lien 2.4 GHz réel via HID dongle) -> Game + Chat
#   - Sinon                 -> Philips Evnia
# Si les deux: le dernier connecté gagne.
# Au démarrage: Pixel > Razer (HID) > écran.

$ErrorActionPreference = 'SilentlyContinue'
$PollSeconds = 2
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $ScriptDir 'Modules\AudioDeviceCmdlets\3.1.0.2\AudioDeviceCmdlets.psd1') -ErrorAction Stop
$AppDir = Join-Path $env:LOCALAPPDATA 'AutoAudioSwitch'
$LogPath = Join-Path $AppDir 'log.txt'
$StatePath = Join-Path $AppDir 'state.txt'
$CsPath = Join-Path $ScriptDir 'RazerDongle.cs'
New-Item -ItemType Directory -Path $AppDir -Force | Out-Null

if ((Test-Path $LogPath) -and ((Get-Item $LogPath).Length -gt 512KB)) {
    Move-Item $LogPath ($LogPath + '.old') -Force
}

function Write-Log([string]$Message) {
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

# Load HID helper once
if (-not ('AutoAudioSwitch.RazerDongle' -as [type])) {
    Add-Type -Path $CsPath -ErrorAction Stop
}

function Find-Device($Devices, [string]$Type, [string[]]$Include, [string[]]$Exclude = @()) {
    foreach ($d in $Devices) {
        if ($d.Type -ne $Type) { continue }
        $name = $d.Name
        $ok = $true
        foreach ($inc in $Include) {
            if ($name -notlike $inc) { $ok = $false; break }
        }
        if (-not $ok) { continue }
        foreach ($exc in $Exclude) {
            if ($name -like $exc) { $ok = $false; break }
        }
        if ($ok) { return $d }
    }
    return $null
}

function Test-PixelBluetoothConnected {
    $bt = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
        Where-Object { $_.FriendlyName -like '*Pixel Buds*' -and $_.Status -eq 'OK' }
    return [bool]$bt
}

function Test-RazerWirelessConnected {
    $state = [AutoAudioSwitch.RazerDongle]::GetWirelessState()
    return ($state -eq [AutoAudioSwitch.RazerHeadsetState]::Connected)
}

function Get-HeadsetPresence {
    $devices = Get-AudioDevice -List

    $pixelPlay = Find-Device $devices 'Playback' @('*Pixel Buds*') @('*Hands-Free*')
    $pixelRec  = Find-Device $devices 'Recording' @('*Pixel Buds*') @('*Hands-Free*')
    if (-not $pixelRec) {
        $pixelRec = Find-Device $devices 'Recording' @('*Pixel Buds*')
    }
    $pixelOn = ($null -ne $pixelPlay) -and (Test-PixelBluetoothConnected)

    $razerPlay = Find-Device $devices 'Playback' @('*BlackShark*Game*')
    $razerRec  = Find-Device $devices 'Recording' @('*BlackShark*Chat*')
    # Important: le dongle reste visible même casque éteint → statut HID wireless
    $razerOn = ($null -ne $razerPlay) -and (Test-RazerWirelessConnected)

    $screen = Find-Device $devices 'Playback' @('*Philips Evnia*')

    return [PSCustomObject]@{
        Devices   = $devices
        PixelOn   = $pixelOn
        RazerOn   = $razerOn
        PixelPlay = $pixelPlay
        PixelRec  = $pixelRec
        RazerPlay = $razerPlay
        RazerRec  = $razerRec
        Screen    = $screen
    }
}

function Set-DefaultBoth($Device) {
    if (-not $Device) { return }
    Set-AudioDevice -ID $Device.ID -DefaultOnly | Out-Null
    Set-AudioDevice -ID $Device.ID -CommunicationOnly | Out-Null
}

function Apply-Profile([string]$Name, $Presence) {
    switch ($Name) {
        'Razer' {
            if (-not $Presence.RazerPlay) { return }
            Set-DefaultBoth $Presence.RazerPlay
            if ($Presence.RazerRec) { Set-DefaultBoth $Presence.RazerRec }
            Write-Log "Profile Razer | out=$($Presence.RazerPlay.Name) | mic=$($Presence.RazerRec.Name)"
        }
        'Pixel' {
            if (-not $Presence.PixelPlay) { return }
            Set-DefaultBoth $Presence.PixelPlay
            if ($Presence.PixelRec) { Set-DefaultBoth $Presence.PixelRec }
            Write-Log "Profile Pixel | out=$($Presence.PixelPlay.Name) | mic=$($Presence.PixelRec.Name)"
        }
        default {
            if (-not $Presence.Screen) { return }
            Set-DefaultBoth $Presence.Screen
            Write-Log "Profile Screen | out=$($Presence.Screen.Name)"
        }
    }
    Set-Content -Path $StatePath -Value $Name -Encoding UTF8
}

function Resolve-StartupProfile($Presence) {
    if ($Presence.PixelOn) { return 'Pixel' }
    if ($Presence.RazerOn) { return 'Razer' }
    return 'Screen'
}

function Ensure-Applied([string]$Name, $Presence) {
    $play = Get-AudioDevice -Playback
    $rec  = Get-AudioDevice -Recording

    $need = $false
    switch ($Name) {
        'Razer' {
            if ($Presence.RazerPlay -and $play.ID -ne $Presence.RazerPlay.ID) { $need = $true }
            if ($Presence.RazerRec -and $rec.ID -ne $Presence.RazerRec.ID) { $need = $true }
        }
        'Pixel' {
            if ($Presence.PixelPlay -and $play.ID -ne $Presence.PixelPlay.ID) { $need = $true }
            if ($Presence.PixelRec -and $rec.ID -ne $Presence.PixelRec.ID) { $need = $true }
        }
        default {
            if ($Presence.Screen -and $play.ID -ne $Presence.Screen.ID) { $need = $true }
        }
    }
    if ($need) { Apply-Profile $Name $Presence }
}

Write-Log 'Watcher started (Pixel BT + Razer HID wireless)'
$presence = Get-HeadsetPresence
$pixelWas = [bool]$presence.PixelOn
$razerWas = [bool]$presence.RazerOn
$active = Resolve-StartupProfile $presence
Write-Log "Startup: Pixel=$pixelWas RazerHID=$razerWas -> $active"
Apply-Profile $active $presence

while ($true) {
    try {
        $presence = Get-HeadsetPresence
        $pixelOn = [bool]$presence.PixelOn
        $razerOn = [bool]$presence.RazerOn

        if ($razerOn -and -not $razerWas) {
            $active = 'Razer'
            Apply-Profile $active $presence
        }
        elseif ($pixelOn -and -not $pixelWas) {
            $active = 'Pixel'
            Apply-Profile $active $presence
        }
        elseif ($active -eq 'Razer' -and -not $razerOn) {
            $active = if ($pixelOn) { 'Pixel' } else { 'Screen' }
            Apply-Profile $active $presence
        }
        elseif ($active -eq 'Pixel' -and -not $pixelOn) {
            $active = if ($razerOn) { 'Razer' } else { 'Screen' }
            Apply-Profile $active $presence
        }
        else {
            Ensure-Applied $active $presence
        }

        $pixelWas = $pixelOn
        $razerWas = $razerOn
    }
    catch {
        Write-Log "Error: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds $PollSeconds
}
