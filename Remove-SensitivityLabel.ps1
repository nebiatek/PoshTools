$SPOAdminUrl = Read-Host -Prompt 'SharePoint admin URL'
$SPOFileToUnlock = Read-Host -Prompt 'URL of the protected file to remove sensitivity label from'
$JustificationText = Read-Host -Prompt 'Justification for the label removal operation'

Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell
Connect-SPOService -Url $SPOAdminUrl
Unlock-SPOSensitivityLabelEncryptedFile -JustificationText $JustificationText -FileUrl $SPOFileToUnlock
