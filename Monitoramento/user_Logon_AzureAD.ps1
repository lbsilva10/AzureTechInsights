# Script para auditoria de usuários ativos no Azure AD
Write-Host "Conectando ao Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.Read.All", "AuditLog.Read.All"

Write-Host "Buscando usuários ativos internos..." -ForegroundColor Cyan
$usuarios = Get-MgUser -All -Property "DisplayName,UserPrincipalName,UserType,AccountEnabled,Department,JobTitle,CreatedDateTime,SignInActivity,OnPremisesSyncEnabled" |
    Where-Object {
        $_.AccountEnabled -eq $true -and
        $_.UserType -eq "Member"
    }

$resultados = $usuarios | Select-Object `
    @{Name='Nome';Expression={$_.DisplayName}},
    @{Name='UserPrincipal';Expression={$_.UserPrincipalName}},
    @{Name='Departamento';Expression={$_.Department}},
    @{Name='Cargo';Expression={$_.JobTitle}},
    @{Name='CriadoEm';Expression={$_.CreatedDateTime.ToString("yyyy-MM-dd")}},
    @{Name='UltimoAcesso';Expression={
        if ($_.SignInActivity.LastSignInDateTime) {
            ([datetime]$_.SignInActivity.LastSignInDateTime).ToString("yyyy-MM-dd HH:mm:ss")
        } else {
            "Sem login registrado"
        }
    }},
    @{Name='TipoConta';Expression={
        if ($_.OnPremisesSyncEnabled -eq $true) {
            "Sincronizado (AD Local)"
        } else {
            "Nuvem (Cloud Only)"
        }
    }}

# Exporta para CSV
$arquivo = "Auditoria_Usuarios_AzureAD.csv"
Write-Host "Exportando relatório para $arquivo..." -ForegroundColor Green
$resultados | Export-Csv -Path $arquivo -NoTypeInformation -Encoding UTF8

Write-Host "Concluído! Relatório salvo em: $arquivo" -ForegroundColor Green