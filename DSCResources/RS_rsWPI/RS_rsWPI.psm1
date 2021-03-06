function Get-TargetResource
{
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Product,
        [int] $timeout,
        [String] $AdditionalArgs
    )
    Set-Alias webpicmd 'C:\Program Files\Microsoft\Web Platform Installer\WebpiCmd.exe'
    $allInstalled = webpicmd /List /ListOption:Installed | ConvertFrom-CSV -Delimiter "`t"
    @{
        Product = if( ($allInstalled -match $Product) ) { "$Product Installed" } else { "$Product Not Installed" }
        Timeout = $timeout
        AdditionalArgs = $AdditionalArgs
    } 
}

Function Invoke-Process {
    Param($FileName,$Arguments,$timeout)
    if (!($timeout)) {$timeout = 30}
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = New-Object System.Diagnostics.ProcessStartInfo -Property @{
        FileName = $FileName
	    Arguments = $Arguments
	    CreateNoWindow = $true
	    RedirectStandardError = $true
	    RedirectStandardOutput = $true
	    UseShellExecute = $false
    }
    $proc.Start() | Out-Null
    if (!($proc.WaitForExit($timeout*1000))) {$proc.kill()}
    $stderr = $proc.StandardError.ReadToEnd()
    $stdout = $proc.StandardOutput.ReadToEnd()
    $proc.close()
    $proc = $null
    $result = @()
    $result += New-Object psObject -Property @{
        'stdOut'=$stdout
        'stdErr'=$stderr
    } 
    return $result
}

function Set-TargetResource
{
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Product,
        [int] $timeout,
        [String] $AdditionalArgs
    )
    if ( -not (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{4D84C195-86F0-4B34-8FDE-4A17EB41306A}") )
    {
        try
        {
            if ( -not (Test-Path "C:\rs-pkgs\webpi.msi") )
            {
                Write-Verbose "Downloading WPI.msi"
                Invoke-WebRequest 'http://download.microsoft.com/download/C/F/F/CFF3A0B8-99D4-41A2-AE1A-496C08BEB904/WebPlatformInstaller_amd64_en-US.msi' -OutFile "C:\rs-pkgs\webpi.msi"
            }
        }
        catch [Exception]
        {
            Write-Debug $_.Exception.Message
            return
        }
        Write-Verbose "Installing WPI"
        $process = Start-Process msiexec -ArgumentList "/i C:\rs-pkgs\webpi.msi /qn"  -wait -NoNewWindow -PassThru
        if ( $process.ExitCode -ne 0 ) { Write-Debug "Error Installing WebPI" }
        else { Write-Verbose "Web Platform Installer Completed Successfully"}
    }

    Set-Alias webpicmd 'C:\Program Files\Microsoft\Web Platform Installer\WebpiCmd.exe'

    $allInstalled = webpicmd /List /ListOption:Installed | ConvertFrom-CSV -Delimiter "`t"
    Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Local AppData" -Value "C:\Windows\Temp"

    if( -not ($allInstalled -match $Product) )
    {
        Write-Verbose "Installing $Product"
        $process = Invoke-Process "C:\Program Files\Microsoft\Web Platform Installer\WebpiCmd.exe" -Arguments "/INSTALL /Products:$Product /AcceptEula $AdditionalArgs" -timeout $timeout
        Write-Debug $process.stdOut
    }
    Set-ItemProperty -Path "Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Local AppData" -Value "%USERPROFILE%\AppData\Local"
}

function Test-TargetResource
{
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Product,
        [int] $timeout,
        [String] $AdditionalArgs
    )
    $testresult = $true

    if ( -not (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{4D84C195-86F0-4B34-8FDE-4A17EB41306A}") )
    {
        Write-Verbose "Need to Install Web Platform Installer"
        return $false
    }

    Set-Alias webpicmd 'C:\Program Files\Microsoft\Web Platform Installer\WebpiCmd.exe'
    Write-Verbose "Getting List of Installed Products"
    $allInstalled = webpicmd /List /ListOption:Installed | ConvertFrom-CSV -Delimiter "`t"

    if( -not ($allInstalled -match $Product) )
    {
        Write-Verbose "Need to Install $Product"
        $testresult = $false
    }

    return $testresult
}
Export-ModuleMember -Function *-TargetResource