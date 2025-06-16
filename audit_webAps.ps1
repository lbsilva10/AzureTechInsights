# Nome do arquivo de saída

$OutputFile = "webapps_database_auditoria.csv"



# Cabeçalho do CSV

"SubscriptionID,SubscriptionName,WebApp,ResourceGroup,UsaBancoDados,TipoBanco,Origem,NomeBase,Usuario,Stack" | Out-File -FilePath $OutputFile -Encoding utf8



# Login no Azure

Write-Host " Fazendo login no Azure..." -ForegroundColor Cyan

az login | Out-Null



# Lista todas as assinaturas

$subscriptions = az account list --query "[].{id:id, name:name}" -o json | ConvertFrom-Json



foreach ($sub in $subscriptions) {

    $subId = $sub.id

    $subName = $sub.name



    Write-Host " Assinatura: $subName ($subId)" -ForegroundColor Yellow

    az account set --subscription $subId | Out-Null



    # Lista Web Apps

    $webApps = az webapp list --subscription $subId --query "[].{Name:name, ResourceGroup:resourceGroup}" -o json | ConvertFrom-Json



    foreach ($app in $webApps) {

        $appName = $app.Name

        $resourceGroup = $app.ResourceGroup

        $usaBanco = "NÃO"

        $tipoBanco = ""

        $origem = ""

        $nomeBase = ""

        $usuario = ""

        $stack = ""



        # Tenta pegar o stack do app

        $appInfoRaw = az webapp show --name $appName --resource-group $resourceGroup -o json

        if ($appInfoRaw) {

            $appInfo = $appInfoRaw | ConvertFrom-Json

            if ($appInfo.siteConfig -ne $null) {

                $stack = $appInfo.siteConfig.linuxFxVersion

            }

        }



        # Verifica connection strings

        $connStrings = az webapp config connection-string list --name $appName --resource-group $resourceGroup -o json | ConvertFrom-Json

        foreach ($conn in $connStrings) {

            $valor = $conn.value.ToLower()



            if ($valor -match "database.windows.net") { $tipoBanco = "SQL Server" }

            elseif ($valor -match "postgres.database.azure.com") { $tipoBanco = "PostgreSQL" }

            elseif ($valor -match "mysql.database.azure.com") { $tipoBanco = "MySQL" }

            elseif ($valor -match "documents.azure.com" -or $valor -match "cosmos") { $tipoBanco = "Cosmos DB" }

            elseif ($valor -match "mongodb") { $tipoBanco = "MongoDB" }



            if ($tipoBanco -ne "") {

                $usaBanco = "SIM"

                $origem = "Connection Strings"



                if ($conn.value -match "initial catalog=([^;]+)") {

                    $nomeBase = $Matches[1]

                } elseif ($conn.value -match "database=([^;]+)") {

                    $nomeBase = $Matches[1]

                }



                if ($conn.value -match "user id=([^;]+)") {

                    $usuario = $Matches[1]

                } elseif ($conn.value -match "uid=([^;]+)") {

                    $usuario = $Matches[1]

                }



                break

            }

        }



        # Verifica app settings

        $appSettings = az webapp config appsettings list --name $appName --resource-group $resourceGroup -o json | ConvertFrom-Json

        foreach ($setting in $appSettings) {

            $valor = $setting.value.ToLower()



            if ($valor -match "database.windows.net") { $tipoBanco = "SQL Server" }

            elseif ($valor -match "postgres.database.azure.com") { $tipoBanco = "PostgreSQL" }

            elseif ($valor -match "mysql.database.azure.com") { $tipoBanco = "MySQL" }

            elseif ($valor -match "documents.azure.com" -or $valor -match "cosmos") { $tipoBanco = "Cosmos DB" }

            elseif ($valor -match "mongodb") { $tipoBanco = "MongoDB" }



            if ($tipoBanco -ne "") {

                $usaBanco = "SIM"

                if ($origem -eq "") { $origem = "Application Settings" }



                if ($setting.value -match "initial catalog=([^;]+)") {

                    $nomeBase = $Matches[1]

                } elseif ($setting.value -match "database=([^;]+)") {

                    $nomeBase = $Matches[1]

                }



                if ($setting.value -match "user id=([^;]+)") {

                    $usuario = $Matches[1]

                } elseif ($setting.value -match "uid=([^;]+)") {

                    $usuario = $Matches[1]

                }



                break

            }

        }



        # Linha do CSV

        "$subId,$subName,$appName,$resourceGroup,$usaBanco,$tipoBanco,$origem,$nomeBase,$usuario,$stack" | Out-File -FilePath $OutputFile -Append -Encoding utf8

    }

}



Write-Host "`n Concluído! Verifique o relatório: $OutputFile" -ForegroundColor Green