

Register-ArgumentCompleter -CommandName 'Connect-AnyConnect' -ParameterName 'ProfileURL' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameter)
    $BinaryDetail = . $PSScriptRoot\AppInstallCheck.ps1
    # Common CLI settings
    $vpncli = New-Object System.Diagnostics.Process
    $vpncli.StartInfo = New-Object System.Diagnostics.ProcessStartInfo($BinaryDetail.PathCLI)
    $vpncli.StartInfo.CreateNoWindow  = $true
    $vpncli.StartInfo.UseShellExecute = $false
    $vpncli.StartInfo.RedirectStandardOutput = $true
    $vpncli.StartInfo.RedirectStandardError  = $true
    #
    $vpncli.StartInfo.Arguments = "hosts"
    $vpncli.Start() | Out-Null
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
    $SavedProfiles.Profiles | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}