Import-Module ImportExcel

Connect-AzureAD



$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"

$excelPath = "AuditoriaUsuarios_$timestamp.xlsx"



# Arrays para armazenar dados

$comManager = @()

$semManager = @()

$managersComSubordinados = @()



$usuarios = Get-AzureADUser -All $true | Where-Object {

    $_.UserType -eq 'Member' -and $_.AccountEnabled -eq $true -and $_.UserPrincipalName -notlike "*#EXT#*"

}



foreach ($user in $usuarios) {

    $manager = Get-AzureADUserManager -ObjectId $user.ObjectId -ErrorAction SilentlyContinue

    $licenciado = (Get-AzureADUserLicenseDetail -ObjectId $user.ObjectId -ErrorAction SilentlyContinue).Count -gt 0

    $statusLicenca = if ($licenciado) { "Licensed" } else { "Unlicensed" }

    $statusConta = if ($user.AccountEnabled) { "Active" } else { "Disabled" }



    if ($manager) {

        $comManager += [PSCustomObject]@{

            Nome            = $user.DisplayName

            UPN             = $user.UserPrincipalName

            Departamento    = $user.Department

            'Manager Nome'  = $manager.DisplayName

            'Manager UPN'   = $manager.UserPrincipalName

            'Status Conta'  = $statusConta

            'Status Licença'= $statusLicenca

        }

    } else {

        $semManager += [PSCustomObject]@{

            Nome            = $user.DisplayName

            UPN             = $user.UserPrincipalName

            Departamento    = $user.Department

            'Manager Nome'  = "N/A"

            'Manager UPN'   = "N/A"

            'Status Conta'  = $statusConta

            'Status Licença'= $statusLicenca

        }

    }



    $subordinados = Get-AzureADUserDirectReport -ObjectId $user.ObjectId -ErrorAction SilentlyContinue

    if ($subordinados.Count -gt 0) {

        $managersComSubordinados += [PSCustomObject]@{

            NomeManager        = $user.DisplayName

            UPNManager         = $user.UserPrincipalName

            Departamento       = $user.Department

            StatusConta        = $statusConta

            StatusLicenca      = $statusLicenca

            QtdSubordinados    = $subordinados.Count

            'Nomes Subordinados' = ($subordinados | Select-Object -ExpandProperty DisplayName) -join ", "

            'UPNs Subordinados'  = ($subordinados | Select-Object -ExpandProperty UserPrincipalName) -join ", "

        }

    }

}



# Exporta para Excel (com múltiplas abas)

# ...