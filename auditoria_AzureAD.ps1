Permissions Required:

    - Microsoft Graph: User.Read.All (at least) for reading user properties and sign-in activity.

    - Exchange Online: View-Only Recipients or higher role for Get-EXORecipient.

    #Requires -Modules Microsoft.Graph.Users, ExchangeOnlineManagement

  Runs the script, prompts for authentication, performs the audit, and creates 'AzureAD_Cloud_User_Audit.csv'.

#>



param (

    [Parameter(Mandatory=$false)]

    [string]$OutputPath = ".\AzureAD_Cloud_User_Audit.csv"

)



# --- Script Start --- 



Write-Host "Iniciando auditoria de usuários Cloud-Only no Azure AD..." -ForegroundColor Cyan



#region Connect to Services



Write-Host "Verificando e conectando aos serviços necessários (Microsoft Graph e Exchange Online)..." -ForegroundColor Yellow



# Check and Import Modules

try {

    Import-Module Microsoft.Graph.Users -ErrorAction Stop

    Import-Module ExchangeOnlineManagement -ErrorAction Stop

    Write-Host "Módulos necessários carregados com sucesso." -ForegroundColor Green

} catch {

    Write-Error "Erro ao carregar módulos necessários (Microsoft.Graph.Users, ExchangeOnlineManagement). Certifique-se de que estão instalados (Install-Module Microsoft.Graph.Users; Install-Module ExchangeOnlineManagement). Detalhes: $($_.Exception.Message)"

    # Exit if modules can't be loaded

    return 

}



# Connect to Microsoft Graph

try {

    # Check existing connection

    $graphConnection = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $graphConnection) {

        Write-Host "Conectando ao Microsoft Graph..." 

        # Define required scopes

        $scopes = @("User.Read.All", "AuditLog.Read.All") # AuditLog.Read.All needed for signInActivity

        Connect-MgGraph -Scopes $scopes

        Write-Host "Conectado ao Microsoft Graph com sucesso." -ForegroundColor Green

    } else {

        Write-Host "Já conectado ao Microsoft Graph." -ForegroundColor Green

    }

} catch {

    Write-Error "Falha ao conectar ao Microsoft Graph. Verifique permissões e conectividade. Detalhes: $($_.Exception.Message)"

    return

}



# Connect to Exchange Online

try {

    # Check existing connection

    $exoConnection = Get-ConnectionInformation -ErrorAction SilentlyContinue

    if (-not ($exoConnection | Where-Object { $_.AppName -eq 'ExchangeOnline' -and $_.ConnectionState -eq 'Connected' })) {

        Write-Host "Conectando ao Exchange Online..."

        Connect-ExchangeOnline -ShowBanner:$false

        Write-Host "Conectado ao Exchange Online com sucesso." -ForegroundColor Green

    } else {

        Write-Host "Já conectado ao Exchange Online." -ForegroundColor Green

    }

} catch {

    Write-Error "Falha ao conectar ao Exchange Online. Verifique permissões e conectividade. Detalhes: $($_.Exception.Message)"

    return

}



#endregion



#region Fetch and Process Users



Write-Host "Buscando usuários Cloud-Only no Azure AD..." -ForegroundColor Yellow



$allUsers = @()

try {

    # Get users - Filter for members, exclude guests, and check onPremisesSyncEnabled

    # Select necessary properties including signInActivity for LastSignInDateTime

    # Note: Filtering directly on onPremisesSyncEnabled can be inconsistent. We filter later.

    # Note: signInActivity requires Azure AD Premium P1 or P2 license.

    $users = Get-MgUser -All -Property Id, DisplayName, UserPrincipalName, Department, JobTitle, UserType, onPremisesSyncEnabled, signInActivity 

        -Filter "UserType eq 'Member'"



    Write-Host "Encontrados $($users.Count) usuários do tipo 'Member'. Filtrando por Cloud-Only e processando..."



    $ProgressPreference = 'SilentlyContinue' # Suppress progress bar for Get-EXORecipient inside loop

    $i = 0

    foreach ($user in $users) {

        $i++

        Write-Progress -Activity "Processando Usuários" -Status "Verificando Usuário $i de $($users.Count): $($user.UserPrincipalName)" -PercentComplete (($i / $users.Count) * 100)



        # Filter for Cloud-Only: onPremisesSyncEnabled is null or explicitly false

        if ($null -eq $user.onPremisesSyncEnabled -or $user.onPremisesSyncEnabled -eq $false) {

            

            # Check if it's a Shared Mailbox in Exchange Online

            $isSharedMailbox = "Não"

            try {

                $recipient = Get-EXORecipient -Identity $user.UserPrincipalName -ErrorAction SilentlyContinue

                if ($recipient -ne $null -and $recipient.RecipientTypeDetails -eq "SharedMailbox") {

                    $isSharedMailbox = "Sim"

                }

            } catch {

                # Handle potential errors if user not found in EXO or other issues

                Write-Warning "Não foi possível verificar o status da caixa de correio para $($user.UserPrincipalName) no Exchange Online. Detalhes: $($_.Exception.Message)"

            }



            # Get Last Sign-In DateTime (Handle potential null value)

            $lastSignIn = if ($user.SignInActivity -ne $null) { $user.SignInActivity.LastSignInDateTime } else { $null }



            # Create custom object with desired properties

            $userData = [PSCustomObject]@{ 

                Nome                = $user.DisplayName

                EnderecoDeEmail     = $user.UserPrincipalName

                Departamento        = $user.Department

                Cargo               = $user.JobTitle

                UltimoLogin         = $lastSignIn

                EhCaixaCompartilhada = $isSharedMailbox

            }

            $allUsers += $userData

        }

    }

    $ProgressPreference = 'Continue' # Restore progress bar preference



} catch {

    Write-Error "Erro ao buscar ou processar usuários do Azure AD. Detalhes: $($_.Exception.Message)"

    # Attempt to disconnect before exiting

    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue

    Disconnect-MgGraph -ErrorAction SilentlyContinue

    return

}



Write-Host "Processamento de usuários concluído. Encontrados $($allUsers.Count) usuários Cloud-Only." -ForegroundColor Green



#endregion



#region Export to CSV



if ($allUsers.Count -gt 0) {

    Write-Host "Exportando resultados para CSV: $OutputPath" -ForegroundColor Yellow

    try {

        $allUsers | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'

        Write-Host "Exportação para CSV concluída com sucesso: $OutputPath" -ForegroundColor Green

    } catch {

        Write-Error "Falha ao exportar dados para CSV. Verifique o caminho e permissões. Detalhes: $($_.Exception.Message)"

    }

} else {

    Write-Host "Nenhum usuário Cloud-Only encontrado para exportar." -ForegroundColor Yellow

}



#endregion



#region Disconnect Services



Write-Host "Desconectando dos serviços..." -ForegroundColor Yellow

try {

    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue

    # Disconnect-MgGraph # Optional: Keep Graph connection if running multiple scripts

    Write-Host "Desconexão concluída (Exchange Online)." -ForegroundColor Green

} catch {

    Write-Warning "Ocorreu um problema ao desconectar dos serviços. Detalhes: $($_.Exception.Message)"

}



#endregion



Write-Host "Auditoria concluída." -ForegroundColor Cyan



# --- Script End ---