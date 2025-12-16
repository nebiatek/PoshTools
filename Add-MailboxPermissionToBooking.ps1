$UserEmail = Read-Host "adresse courriel"
Get-EXOMailbox -RecipientTypeDetails SchedulingMailbox | % { Add-MailboxPermission -Identity $_.UserPrincipalName -User $UserEmail -AccessRights FullAccess } 
