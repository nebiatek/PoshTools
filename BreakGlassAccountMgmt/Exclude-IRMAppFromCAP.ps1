Connect-MgGraph -NoWelcome -Scopes Policy.Read.All, Policy.ReadWrite.ConditionalAccess -TenantId 1eae22f0-5728-4559-b5fa-bec04a2763cd

# Define app id for the Microsoft Rights Management Services app
$IRMAppId = "00000012-0000-0000-c000-000000000000"

# Parameters needed to update a CA policy
$Parameters = @{
    Conditions = @{
        applications = @{  
            excludeapplications = @(
                "00000012-0000-0000-c000-000000000000"
            )
        }
    }
}


ForEach ($Policy in (Get-MgIdentityConditionalAccessPolicy | Sort-Object DisplayName)) {
    Write-Host ("Checking conditional access policy {0}" -f $Policy.displayName)
    If ($Policy.conditions.applications.IncludeAuthenticationContextClassReferences) {
        Write-Host ("Policy {0} uses an authentication context. Can't apply an app exclusion" -f $Policy.displayName) -ForegroundColor Yellow
    }
    Else {
        # Get already excluded apps
        [array]$ExcludedApps = $Policy.conditions.applications.excludeapplications

        # If IRM App Id is not already there, add it to the excluded app list
        If ($IRMAppId -notin $ExcludedApps) {
            Write-Host ("Exclusion for Microsoft Rights Management Services app not present in CA policy {0}" -f $Policy.DisplayName)
            [array]$AuthenticationStrength = $Policy.grantcontrols | Select-Object -ExpandProperty AuthenticationStrength

            If (($Policy.grantcontrols.builtincontrols -eq 'mfa') -or ($AuthenticationStrength.AllowedCombinations)) {
                Write-Host "Checking policy to see if exclusion for Microsoft Rights Management Services app is possible"

                If ($Policy.grantcontrols.builtincontrols -eq 'passwordchange') {
                    Write-Host "Forced password change control means app exclusion is not possible" -ForegroundColor Yellow
                }
                Else {
                    Write-Host "Updating policy with exclusion" -ForegroundColor DarkRed
                    Update-MgIdentityConditionalAccessPolicy -BodyParameter $Parameters -ConditionalAccessPolicyId $Policy.Id
                }
            }
            Else {
                Write-Host "Policy doesn't use MFA - ignoring" -ForegroundColor Yellow
            }
        }
        Else {
            Write-Host "Exclusion for Microsoft Rights Management Services app present" -ForegroundColor DarkGray
        }
    }
}