# Get paths to Cisco AnyConnect client binaries
Try {
    If($env:PROCESSOR_ARCHITECTURE -eq "x86") {
        $Installed = Get-ItemProperty 'HKLM:\SOFTWARE\Cisco\Cisco AnyConnect Secure Mobility Client' -ErrorAction Stop
    }
    Else {
        $Installed = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Cisco\Cisco AnyConnect Secure Mobility Client' -ErrorAction Stop
    }
    $AnyConnectPath = $Installed.InstallPathWithSlash
    $CLIpath = Join-Path -Path $AnyConnectPath -ChildPath 'vpncli.exe' -ErrorAction Stop
    # GUI executable changed name in recent versions.
    # Test path to GUI executable
    If (Test-Path -Path (Join-Path -Path $AnyConnectPath -ChildPath 'vpnui.exe')) {
        $GUIpath = Join-Path -Path $AnyConnectPath -ChildPath 'vpnui.exe' -ErrorAction Stop
    }
    ElseIf (Test-Path -Path (Join-Path -Path $AnyConnectPath -ChildPath 'vpnxui.exe')) {
        $GUIpath = Join-Path -Path $AnyConnectPath -ChildPath 'vpngui.exe' -ErrorAction Stop
    }
    Else {
        Write-Host "Warning: AnyConnect Secure Mobility Client gui not detected`n$_ " -ForegroundColor Yellow
        Break
    }
    #
    [pscustomobject]@{PathCLI = $CLIpath;PathGUI = $GUIpath}
}
Catch {
    Write-Host "Warning: AnyConnect Secure Mobility Client installation not detected`n$_ " -ForegroundColor Yellow
    Break
}