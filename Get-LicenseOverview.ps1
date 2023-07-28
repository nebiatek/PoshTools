<#
.SYNOPSIS
    Return a summary of subscribed and consumed Microsoft licenses

.DESCRIPTION
    This function helps IT administrators to get an overview of all the licenses a Microsoft tenant has, even those not visible in Microsoft 365 Admin portal or Microsoft Entra portal.
    It might come handy in case your tenant has multiple licenses sources, such as Enterprise Agreement + Reseller + Commercial Direct subscriptions.
    The matching of the name displayed in administration portal and the SkuPartNumber is really helpful to identify the right Sku

.INPUTS
    String

.OUTPUTS
    Array

.EXAMPLE
    Get-LicenseOverview

.EXAMPLE
    Get-LicenseOverview | ConverTo-Csv | Out-File -FilePath .\Desktop\LicensesSummary.csv

.NOTES
    Website: https://github.com/nebiatek
#>
function Get-LicenseOverview {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [string]
        $TenantId
    )
    
    begin {
        
        $subscribedLicensesWithDisplayName = @()
    }
    
    process {
        
        try {
            if ($TenantId) {
                Connect-MgGraph -Scopes Organization.Read.All -TenantId $TenantId
            }
            else {
                Connect-MgGraph -Scopes Organization.Read.All
            }
        }
        catch {
            Write-Error 'An error occured when trying to connect to your organization'
        }

        # Retrieve latest version of Display Name and Sku of Microsoft plan from Microsoft's documentation 
        $products = ConvertFrom-Csv (Invoke-RestMethod -Method Get -Uri "https://download.microsoft.com/download/e/3/e/e3e9faf2-f28b-490a-9ada-c6089a1fc5b0/Product%20names%20and%20service%20plan%20identifiers%20for%20licensing.csv")
        
        # Retrieve all existing licenses in the tenant
        $subscribedLicenses = Get-MgSubscribedSku -All

        for ($i = 0; $i -lt $subscribedLicenses.Count; $i++) {

            $subscribedLicensesWithDisplayName += $products | ? GUID -EQ $($subscribedLicenses[$i].SkuId) | Select-Object -Unique Product_Display_Name | Select-Object @{n = "ProductDisplayName"; e = { $_.Product_Display_Name } }, `
            @{n = "SkuPartNumber"; e = { $($subscribedLicenses[$i].SkuPartNumber) } }, `
            @{n = "SkuId"; e = { $($subscribedLicenses[$i].SkuId) } }, `
            @{n = "AppliesTo"; e = { $($subscribedLicenses[$i].AppliesTo) } }, `
            @{n = "CapabilityStatus"; e = { $($subscribedLicenses[$i].CapabilityStatus) } }, `
            @{n = "PrepaidUnitsEnabled"; e = { $($subscribedLicenses[$i].PrepaidUnits.Enabled) } }, `
            @{n = "ConsumedUnits"; e = { $($subscribedLicenses[$i].ConsumedUnits) } }
        
        }

        return $subscribedLicensesWithDisplayName
    }
    
    end {
        $products, $subscribedLicenses, $subscribedLicensesWithDisplayName, $i, $TenantId = $null
    }
}