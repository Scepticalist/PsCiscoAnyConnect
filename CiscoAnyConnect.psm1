$BinaryDetail = . $PSScriptRoot\AppInstallCheck.ps1

###############################################################################
##               Retrieve AnyConnect and VPN settings information            ##
###############################################################################
#

Function Get-AnyConnectInfo() {
    <#
        .SYNOPSIS
            Retrieves information about the current Cisco Anyconnect installation and VPN status.

        .DESCRIPTION
            Get information about the current Cisco AnyConnect connections status, install path
            profiles or version and returns the result as an object.

        .PARAMETER BinaryPaths
            Current install paths for command line and gui executables. Returns an object,
            with PathCLI and PathGUI properties 
            
        .PARAMETER ConnectionStatus
            Whether a current connection is running - returns an object with Status property,
            which can be Connected or Disconnected.

        .PARAMETER Profiles
            Current saved connection profiles. Returns an object with Profiles property containing all the connection profile values.

        .PARAMETER Version
            Current Anyconnect version. Returns object with Version property containing the version value.

        .NOTES
            Name: Get-AnyConnectInfo

        .EXAMPLE
            Get-AnyConnectInfo -BinaryPaths
            PathCLI                                                 PathGUI
            -------                                                 -------
            C:\Program Files (x86)\Cisco\Cisco AnyConnect Sec...    C:\Program Files (x86)\Cisco\Cisco AnyConnect Sec...


            Description
            -----------
            Get install path for executables

        .EXAMPLE
            Get-AnyConnectInfo -ConnectionStatus
            Status
            ------
            Disconnected


            Description
            -----------
            Get connection status (currently disconnected)

        .EXAMPLE
            Get-AnyConnectInfo -Profiles
            Profiles
            --------
            vpn.nhsnss.org
            vpn1.nhsnss.org


            Description
            -----------
            Get current saved connection profiles

        .EXAMPLE
            Get-AnyConnectInfo -Version
            Version
            -------
            4.3.05017


            Description
            -----------
            Get current version of AnyConnect
    #>
    [CmdletBinding(DefaultParameterSetName='NoOption')]
    Param(
        [Parameter(ParameterSetName='Binaries')][switch]$BinaryPath,
        [Parameter(ParameterSetName='Status')][switch]$ConnectionStatus,
        [Parameter(ParameterSetName='Profiles')][switch]$Profiles,
        [Parameter(ParameterSetName='Version')][switch]$Version
    )
#
    Begin {
        If ($PSCmdlet.ParameterSetName -eq 'NoOption') {
            Write-Error "Invalid parameter option.`nYou must specify one of the following options: '-BinaryPath', '-ConnectionStatus', '-Profiles', '-Version'"
            Return
        }
        # Common CLI settings
        $vpncli = New-Object System.Diagnostics.Process
        $vpncli.StartInfo = New-Object System.Diagnostics.ProcessStartInfo($BinaryDetail.PathCLI)
        $vpncli.StartInfo.CreateNoWindow  = $true
        $vpncli.StartInfo.UseShellExecute = $false
        $vpncli.StartInfo.RedirectStandardOutput = $true
        $vpncli.StartInfo.RedirectStandardError  = $true
    }
    #
    Process {
        Switch ($PSBoundParameters.Keys) {
            BinaryPath {
                $BinaryDetail = . $PSScriptRoot\AppInstallCheck.ps1
                Return $BinaryDetail
            }
            Version {
                Write-Verbose "Starting the AnyConnect cli"
                $vpncli.StartInfo.Arguments = "version"
                $vpncli.Start() | Out-Null
                Write-Verbose "Reading output"
                $SavedProfiles = For ($output = $vpncli.StandardOutput.ReadLine(); $null -ne $output; $output = $vpncli.StandardOutput.ReadLine()) {
                    If ($output -notmatch '[^A-Za-z0-9]*') {
                        Write-Verbose $output
                    }
                    If ($output -match 'Cisco(.*)') {
                        [string]$VersionAC = [regex]::match((& $CLIpath -v),'\(version ([^\)]+)\)').Groups[1].Value
                        Break
                    }
                }
                For ($output = $vpncli.StandardError.ReadLine(); $null -ne $output; $output = $vpncli.StandardError.ReadLine()) {
                Write-Warning $output
                }
                Return [pscustomobject]@{Version = $VersionAC}
            }
            Profiles {
                Write-Verbose "Starting the AnyConnect cli"
                $vpncli.StartInfo.Arguments = "hosts"
                $vpncli.Start() | Out-Null
                Write-Verbose "Reading output"
                $SavedProfiles = For ($output = $vpncli.StandardOutput.ReadLine(); $null -ne $output; $output = $vpncli.StandardOutput.ReadLine()) {
                    If ($output -notmatch '[^A-Za-z0-9]*') {
                        Write-Verbose $output
                    }
                    If ($output -match '  >> note: (.*)') {
                        Write-Warning $matches[1]
                        $status = 'Note'
                    }
                    ElseIf ($output -match '.*\[hosts\]') {
                        Write-Verbose "Found VPN profiles:"
                    }
                    ElseIf ($output -match '.*> (.*)') {
                        Write-Verbose "  Adding $($matches[1])"
                        [pscustomobject]@{Profiles = $matches[1]}
                    }
                }
                For ($output = $vpncli.StandardError.ReadLine(); $null -ne $output; $output = $vpncli.StandardError.ReadLine()) {
                Write-Warning $output
                }
                Return $SavedProfiles
            }
            ConnectionStatus {
                Write-Verbose "Starting the AnyConnect cli"
                $vpncli.StartInfo.Arguments = "state"
                $vpncli.Start() | Out-Null
                $status = 'Unknown'
                Write-Verbose "Reading output"
                For ($output = $vpncli.StandardOutput.ReadLine(); $null -ne $output; $output = $vpncli.StandardOutput.ReadLine()) {
                    If ($output -notmatch '[^A-Za-z0-9]*') {
                        Write-Verbose $output
                    }
                    If ($output -match '  >> note: (.*)') {
                        Write-Warning $matches[1]
                        $status = 'Note'
                    }
                    If ($output -match '  >> state: (.*)') {
                        $status = $matches[1]
                        Write-Verbose $status
                    }
                }
                For ($output = $vpncli.StandardError.ReadLine(); $null -ne $output; $output = $vpncli.StandardError.ReadLine()) {
                    Write-Warning $output
                }
                Return [pscustomobject]@{Status = $status}
            }
        }
    }
}
#
###############################################################################
##                               Connect to VPN                              ##
###############################################################################
#
Function Connect-AnyConnect() {
    <#
        .SYNOPSIS
            Connects to a VPN using Cisco AnyConnect.

        .DESCRIPTION
            Connects to a VPN using cisco AnyConnect using a VPN profile saved in the application. Will
            disconnect any currently running sessions if present.

        .PARAMETER User
            User ID or name. 
            
        .PARAMETER RSAPass
            Password from RSA SecureID.

        .PARAMETER ProfileURL
            A URL connection profile.

        .NOTES
            Name: Connect-AnyConnect

        .EXAMPLE
            Connect-AnyConnect -User 'johnsm01' -RSAPass '12345678' -ProfileURL vpn.mycompany.com


            Description
            -----------
            Connect to the saved AnyConnect profile 'vpn.mycompany.com' using user id 'johnsm01' and numeric password from RSA SecureID token
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Position=1,Mandatory=$true)][string]$ProfileURL,
        [Parameter(Position=2,Mandatory=$true)][string]$User,
        [Parameter(Position=3,Mandatory=$true)][string]$RSAPass
    )
    Process {
    # Disconnect if needed
        If ((Get-AnyConnectInfo -ConnectionStatus -Verbose:$false).Status -ne 'Disconnected') {
            Disconnect-AnyConnect -Verbose:$Verbose
        }

    # First Stop any VPN cli and ui
    # There must be only one "client" running when connecting
        Get-Process | Where-Object ProcessName -match 'vpn(ui|cli)' | ForEach-Object {
            If (! $_.HasExited) {
                Write-Verbose "Stopping process $($_.Name) (pid: $($_.Id))"
                Stop-Process $_.Id
            }
            Else {
                Write-Verbose "Process $($_.Name) is exiting (pid: $($_.Id))"
            }
        }
        Write-Host "`nStarting AnyConnect to $ProfileURL as $User`n"
        Write-Verbose "Starting the AnyConnect cli"
        $vpncli = New-Object System.Diagnostics.Process
        $vpncli.StartInfo = New-Object System.Diagnostics.ProcessStartInfo($BinaryDetail.PathCLI)
        $vpncli.StartInfo.Arguments = "-s"
        $vpncli.StartInfo.CreateNoWindow  = $true
        $vpncli.StartInfo.UseShellExecute = $false
        $vpncli.StartInfo.RedirectStandardInput  = $true
        $vpncli.StartInfo.RedirectStandardOutput = $true
        $vpncli.StartInfo.RedirectStandardError  = $true

        If (! $vpncli.Start()) {
            Throw "Cannot start AnyConnect Client, error: $LASTEXITCODE"
        }

        Write-Verbose "Waiting for process to be ready"
        Start-Sleep 2

        Write-Verbose "Sending connect"
        $vpncli.StandardInput.WriteLine('connect ' + $ProfileURL)

        Write-Verbose "Sending user"
        $vpncli.StandardInput.WriteLine($User)

        Write-Verbose "Sending password"
        $vpncli.StandardInput.WriteLine($RSAPass)

        Write-Verbose "Reading output stream"
        For ($output = $vpncli.StandardOutput.ReadLine(); $null -ne $output; $output = $vpncli.StandardOutput.ReadLine()) {
            # Remove empty lines
            If ($output -notmatch '[^A-Za-z0-9]*') {
                Write-Verbose $output
            }
            If ($output -eq '  >> Login failed.') {
                Throw [System.Security.Authentication.InvalidCredentialException]
            }
            ElseIf ($output -match '  >> notice: Please respond to banner.') {
                Write-Warning "Banner detected..."
            }
            ElseIf ($output -match 'accept?(.*)') {
                Write-Warning "Banner answer"
                $vpncli.StandardInput.WriteLine('y')
            }
            ElseIf ($output -match '  >> note: (.*)') {
                Write-Warning $matches[1]
            }
            Elseif ($output -match '  >> state: (.*)') {
                $state = $matches[1]
                Write-Host $state
                If ($state -eq 'Connected') {
                    Break
                }
            }
        }
        Start-Process -FilePath ($BinaryDetail).PathGUI
        Return [PSCustomObject] @{Provider='AnyConnect';Connection=$ProfileURL;State = $state}
    }
}
############################################################################### 
##                            Disconnect from VPN                            ##
###############################################################################
#
Function Disconnect-AnyConnect() {
    <#
        .SYNOPSIS
            Disconnects any currently running Cisco AnyConnect VPN session.

        .DESCRIPTION
            Disconnects the currently running Cisco AnyConnect VPN session and reports connection status.

        .NOTES
            Name: 
            Disonnect-AnyConnect

        .EXAMPLE
            Disconnect-AnyConnect

            Status
            ------
            Disconnected


            Description
            -----------
            Disconnect from the current AnyConnect session. Resulting status reported.
    #>
    [CmdletBinding()]
    Param(
    )
    Write-Verbose "Setting up VPN cli"
    $vpncli = New-Object System.Diagnostics.Process
    $vpncli.StartInfo = New-Object System.Diagnostics.ProcessStartInfo($BinaryDetail.PathCLI)
    $vpncli.StartInfo.Arguments = "disconnect"
    $vpncli.StartInfo.CreateNoWindow  = $true
    $vpncli.StartInfo.UseShellExecute = $false
    $vpncli.StartInfo.RedirectStandardOutput = $true
    $vpncli.StartInfo.RedirectStandardError  = $true
    $vpncli.Start() | Out-Null

    For ($output = $vpncli.StandardOutput.ReadLine(); $null -ne $output; $output = $vpncli.StandardOutput.ReadLine()) {
    # Remove empty lines
        If ($output -notmatch '[^A-Za-z0-9]*') {
            Write-Verbose $output
        }
        If ($output -match '  >> note: (.*)') {
            Write-Warning $matches[1]
        }
        ElseIf ($output -match '  >> state: (.*)') {
            Write-Verbose $matches[1]
        }
    }
    For ($output = $vpncli.StandardError.ReadLine(); $null -ne $output; $output = $vpncli.StandardError.ReadLine()) {
        Write-Warning $output
    }
    Get-AnyConnectInfo -ConnectionStatus
}

