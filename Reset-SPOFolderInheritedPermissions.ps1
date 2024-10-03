# Import required PnP Powershell module
try {
  Import-Module PnP.PowerShell -ErrorAction Stop
} catch {
  Write-Warning "PnP.PowerShell not found. Installing it"
  Install-module PnP.PowerShell -Scope CurrentUser -SkipPublisherCheck -AllowClobber -Force
  Import-Module PnP.PowerShell -ErrorAction Stop
}

# Need an App Registration with permissions for the script to work (see https://pnp.github.io/powershell/articles/registerapplication.html for help)
# Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "PnP PowerShell" -Tenant contoso.onmicrosoft.com -Interactive
$pnpAppClientId = Read-Host 'PnP App ClientId'

$SiteURL = Read-Host 'Site Collection URL (ex.:"https://yourtenant.sharepoint.com/sites/YourSiteCollection/")'
$ListTitle = Read-Host 'Document Library Name (ex.:"Documents")'
$Scope = Read-Host 'Folder to scope (ex.:"/sites/YourSiteCollection/Documents/MyFolderToReset")

# Connect to PnP Online
Connect-PnPOnline -Url $SiteURL -ClientId $pnpAppClientId -Interactive

# Retrieve all context
$context = Get-PnPContext
$context.Load($context.Web.Lists)
$context.Load($context.Web)
$context.Load($ctx.Web.Webs)
$context.ExecuteQuery()
$allLists=$context.Web.Lists.GetByTitle($ListTitle)
$context.Load($allLists)
$context.ExecuteQuery()

## View XML
$qCommand = @"
<View Scope="RecursiveAll">
    <Query>
        <OrderBy><FieldRef Name='ID' Ascending='TRUE'/></OrderBy>
    </Query>
    <RowLimit Paged="TRUE">5000</RowLimit>
</View>
"@

## Page Position
$position = $null
 
## All Items
$allItems = @()
Do{
    $camlQuery = New-Object Microsoft.SharePoint.Client.CamlQuery
    $camlQuery.ListItemCollectionPosition = $position
    $camlQuery.ViewXml = $qCommand
   
    ## Executing the query
    $currentCollection = $allLists.GetItems($camlQuery)
    $context.Load($currentCollection)
    $context.ExecuteQuery()
 
    ## Getting the position of the previous page
    $position = $currentCollection.ListItemCollectionPosition
 
    # Adding current collection to the allItems collection
    $allItems += $currentCollection

    Write-Host "Collecting items. Current number of items: " $allItems.Count
}
while($position -ne $null)

Write-Host "Total number of items: " $allItems.Count

for($i=0;$i -lt $allItems.Count ;$i++)
{
    if($allItems[$i]["FileRef"].StartsWith($Scope))
    {
        Write-Host "Reset to inherited permissions: " $allItems[$i]["FileRef"]
        $allItems[$i].ResetRoleInheritance()
        $context.ExecuteQuery()
    }
}
