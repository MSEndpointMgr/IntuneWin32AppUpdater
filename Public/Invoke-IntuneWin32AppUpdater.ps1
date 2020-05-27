# Loop through each enabled application in config.json and attempt ensure app is up to date

# This should be converted into a private function to call Azure Automation runbook
$BodyHash = @(
    @{
        OrgAppID = "8004a596-7b16-4572-9283-c13c41038c53"
        UpdatedAppID = "4592f3f0-d5d6-48aa-8b3b-7518fc653d68"
        OrgAppVersion = "Adobe Reader DC 20.006.20034"
        UpdatedAppVersion = "Adobe Reader DC 20.009.20063"
    }
)
$BodyJSON = ConvertTo-Json -InputObject $BodyHash

# Call webhook
$Header = @{
    message = "Started by automation"
}
$WebHookUri = "https://9fc35f51-509e-4d33-bef9-a2483718cf3f.webhook.ne.azure-automation.net/webhooks?token=MwcKMhTLEJKGPi4IvKhVNJVwOGqygs8anshnuJkvORc%3d"
$Response = Invoke-WebRequest -Method "Post" -Uri $WebHookUri -Body $BodyJSON -Headers $Header
$Response