# Install required script
Install-Script -Name Get-LatestAdobeReaderInstaller

# Amend these variables
$TenantName = "configmgrse.onmicrosoft.com"
$Publisher = "MSEndpointMgr"
$SourceFolderRoot = "C:\IntuneWinAppUtil\Source\AdobeReader" # This is the root folder where Adobe Reader DC will be downloaded into a sub-folder that's named after the setup version
$OutputFolder = "C:\IntuneWinAppUtil\Output" # This is the folder where the packaged .intunewin file will be created in
$AppIconFile = "C:\IntuneWinAppUtil\Icons\AdobeReader.png" # Locate a suitable icon file for the application

# Retrieve information for latest Adobe Reader DC setup
$AdobeReaderSetup = Get-LatestAdobeReaderInstaller.ps1 -Type "EXE" -Language "en_US"
Write-Output -InputObject "Latest version of Adobe Reader DC detected as: $($AdobeReaderSetup.SetupVersion)"

# Check if latest version is already created in Intune
$AdobeReaderDCWin32Apps = Get-IntuneWin32App -TenantName $TenantName -DisplayName "Adobe Reader DC" -Verbose
$NewerAdobeReaderDCWin32Apps = $AdobeReaderDCWin32Apps | Where-Object { [System.Version]($PSItem.displayName | Select-String -Pattern "(\d+\.)(\d+\.)(\d+)").Matches.Value -ge [System.Version]$AdobeReaderSetup.SetupVersion }

if ($NewerAdobeReaderDCWin32Apps -eq $null) {
    Write-Output -InputObject "Newer Adobe Reader DC version was not found, creating a new Win32 app for the latest version: $($AdobeReaderSetup.SetupVersion)"

    # Define download folder and file paths
    $DownloadDestinationFolderPath = Join-Path -Path $SourceFolderRoot -ChildPath $AdobeReaderSetup.SetupVersion
    $DownloadDestinationFilePath = Join-Path -Path $DownloadDestinationFolderPath -ChildPath $AdobeReaderSetup.FileName

    # Create version specific folder if it doesn't exist
    if (-not(Test-Path -Path $DownloadDestinationFolderPath)) {
        New-Item -Path $DownloadDestinationFolderPath -ItemType Directory -Force | Out-Null
    }

    # Download the Adobe Reader setup file, this generally takes a while
    Write-Output -InputObject "Downloading setup file from: $($AdobeReaderSetup.URL)"
    $WebClient = New-Object -TypeName "System.Net.WebClient"
    $WebClient.DownloadFile($AdobeReaderSetup.URL, $DownloadDestinationFilePath)

    # Create .intunewin package file
    $IntuneWinFile = New-IntuneWin32AppPackage -SourceFolder $DownloadDestinationFolderPath -SetupFile $AdobeReaderSetup.FileName -OutputFolder $OutputFolder -Verbose 

    # Create custom display name like 'Name' and 'Version'
    $DisplayName = "Adobe Reader DC" + " " + $AdobeReaderSetup.SetupVersion

    # Create detection rule using the en-US MSI product code (1033 in the GUID below correlates to the lcid)
    $DetectionRule = New-IntuneWin32AppDetectionRule -MSI -MSIProductCode "{AC76BA86-7AD7-1033-7B44-AC0F074E4100}" -MSIProductVersionOperator greaterThanOrEqual -MSIProductVersion $AdobeReaderSetup.SetupVersion

    # Create custom requirement rule
    $RequirementRule = New-IntuneWin32AppRequirementRule -Architecture All -MinimumSupportedOperatingSystem 1607

    # Convert image file to icon
    $Icon = New-IntuneWin32AppIcon -FilePath $AppIconFile

    # Add new EXE Win32 app
    $InstallCommandLine = "$($AdobeReaderSetup.FileName) /sAll /rs /rps /l"
    $UninstallCommandLine = "msiexec.exe /x {AC76BA86-7AD7-1033-7B44-AC0F074E4100} /qn"
    Add-IntuneWin32App -TenantName $TenantName -FilePath $IntuneWinFile.Path -DisplayName $DisplayName -Description "Adobe Reader DC" -Publisher $Publisher -InstallExperience system -RestartBehavior suppress -DetectionRule $DetectionRule -RequirementRule $RequirementRule -InstallCommandLine $InstallCommandLine -UninstallCommandLine $UninstallCommandLine -Icon $Icon -Verbose

    # Create an available assignment for all users
    Add-IntuneWin32AppAssignment -TenantName $TenantName -DisplayName $DisplayName -Target "AllUsers" -Intent "available" -Verbose

    # Remove .intunewin packaged file
    Remove-Item -Path $IntuneWinFile.Path -Force
}
else {
    Write-Output -InputObject "A newer version of Adobe Reader DC already exists in Intune, will not attempt to create new Win32 app"
}