# Functions
function Get-LatestGoogleChromeInstaller {
    $ChromeReleasesURI = "https://omahaproxy.appspot.com/all.json"
    $ChromeReleasesContentJSON = Invoke-WebRequest -Uri $ChromeReleasesURI
    $ChromeReleasesContent = $ChromeReleasesContentJSON | ConvertFrom-Json
    $ChromeReleasesOSContent = $ChromeReleasesContent | Where-Object { $_.os -like "win64" }
    foreach ($ChromeVersion in $ChromeReleasesOSContent.versions) {
        if ($ChromeVersion.channel -like "stable") {
            $PSObject = [PSCustomObject]@{
                Version = $ChromeVersion.current_version
                Date = ([DateTime]::ParseExact($ChromeVersion.current_reldate.Trim(), 'MM/dd/yy', [CultureInfo]::InvariantCulture))
                URL = -join@("https://dl.google.com", "/dl/chrome/install/googlechromestandaloneenterprise64.msi")
                FileName = "googlechromestandaloneenterprise64.msi"
            }
            Write-Output -InputObject $PSObject
        }
    }
}

# Amend these variables
$TenantName = "tenantname.onmicrosoft.com"
$Publisher = "MSEndpointMgr"
$SourceFolderRoot = "C:\IntuneWinAppUtil\Source\GoogleChrome" # This is the root folder where Google Chrome will be downloaded into a sub-folder that's named after the setup version
$OutputFolder = "C:\IntuneWinAppUtil\Output" # This is the folder where the packaged .intunewin file will be created in
$AppIconFile = "C:\IntuneWinAppUtil\Icons\Chrome.png" # Locate a suitable icon file for the application

# Retrieve information for latest Adobe Reader DC setup
$GoogleChromeSetup = Get-LatestGoogleChromeInstaller
Write-Output -InputObject "Latest version of Google Chrome detected as: $($GoogleChromeSetup.Version)"

# Check if latest version is already created in Intune
$GoogleChromeWin32Apps = Get-IntuneWin32App -TenantName $TenantName -DisplayName "Chrome" -Verbose
$NewerGoogleChromeWin32Apps = $GoogleChromeWin32Apps | Where-Object { [System.Version]($PSItem.displayName | Select-String -Pattern "(\d+\.)(\d+\.)(\d+\.)(\d+)").Matches.Value -ge [System.Version]$GoogleChromeSetup.Version }

if ($NewerGoogleChromeWin32Apps -eq $null) {
    Write-Output -InputObject "Newer Google Chrome version was not found, creating a new Win32 app for the latest version: $($GoogleChromeSetup.Version)"

    # Define download folder and file paths
    $DownloadDestinationFolderPath = Join-Path -Path $SourceFolderRoot -ChildPath $GoogleChromeSetup.Version
    $DownloadDestinationFilePath = Join-Path -Path $DownloadDestinationFolderPath -ChildPath $GoogleChromeSetup.FileName

    # Create version specific folder if it doesn't exist
    if (-not(Test-Path -Path $DownloadDestinationFolderPath)) {
        New-Item -Path $DownloadDestinationFolderPath -ItemType Directory -Force | Out-Null
    }

    # Download the Adobe Reader setup file, this generally takes a while
    $WebClient = New-Object -TypeName "System.Net.WebClient"
    $WebClient.DownloadFile($GoogleChromeSetup.URL, $DownloadDestinationFilePath)

    # Create .intunewin package file
    $IntuneWinFile = New-IntuneWin32AppPackage -SourceFolder $DownloadDestinationFolderPath -SetupFile $GoogleChromeSetup.FileName -OutputFolder $OutputFolder -Verbose 

    # Create custom display name like 'Name' and 'Version'
    $DisplayName = "Google Chrome" + " " + $GoogleChromeSetup.Version

    # Create detection rule using the MSI product code and version
    [string]$ProductCode = Get-MSIMetaData -Path $DownloadDestinationFilePath -Property ProductCode
    $DetectionRule = New-IntuneWin32AppDetectionRule -MSI -MSIProductCode $ProductCode.Trim() -MSIProductVersionOperator greaterThanOrEqual -MSIProductVersion $GoogleChromeSetup.Version

    # Create custom requirement rule
    $RequirementRule = New-IntuneWin32AppRequirementRule -Architecture All -MinimumSupportedOperatingSystem 1607

    # Convert image file to icon
    $Icon = New-IntuneWin32AppIcon -FilePath $AppIconFile

    # Add new MSI Win32 app
    Add-IntuneWin32App -TenantName $TenantName -FilePath $IntuneWinFile.Path -DisplayName $DisplayName -Description "Adobe Reader DC" -Publisher $Publisher -InstallExperience system -RestartBehavior suppress -DetectionRule $DetectionRule -RequirementRule $RequirementRule -Icon $Icon -Verbose

    # Create an available assignment for all users
    Add-IntuneWin32AppAssignment -TenantName $TenantName -DisplayName $DisplayName -Target "AllUsers" -Intent "available" -Verbose

    # Remove .intunewin packaged file
    Remove-Item -Path $IntuneWinFile.Path -Force
}
else {
    Write-Output -InputObject "A newer version of Google Chrome already exists in Intune, will not attempt to create new Win32 app"
}