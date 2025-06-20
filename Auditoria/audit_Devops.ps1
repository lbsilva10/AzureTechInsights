# Configurar suas organizações aqui

$organizations = @("sua-org-1", "sua-org-2")



# Solicita o PAT para autenticação segura

$pat = Read-Host -Prompt "Informe seu PAT do Azure DevOps" -AsSecureString

$ptraw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pat))

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$ptraw"))

$headers = @{Authorization = "Basic $base64AuthInfo"}



$resultados = @()



foreach ($org in $organizations) {

    Write-Host "Organização: $org"

    $projectsUrl = "https://dev.azure.com/$org/_apis/projects?api-version=7.0"

    $projects = (Invoke-RestMethod -Uri $projectsUrl -Headers $headers).value



    foreach ($project in $projects) {

        $projectName = $project.name

        Write-Host "Projeto: $projectName"



        # Verifica uso de Boards

        $wiql = @{ query = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '$projectName'" } | ConvertTo-Json -Depth 3

        $workItemsUrl = "https://dev.azure.com/$org/$projectName/_apis/wit/wiql?api-version=7.0"

        $workItems = Invoke-RestMethod -Method Post -Uri $workItemsUrl -Headers $headers -Body $wiql -ContentType "application/json"

        $temBoards = if ($workItems.workItems.Count -gt 0) { "Sim" } else { "Não" }



        # Último commit (mais recente) em todos os repositórios do projeto

        $reposUrl = "https://dev.azure.com/$org/$projectName/_apis/git/repositories?api-version=7.0"

        $repos = (Invoke-RestMethod -Uri $reposUrl -Headers $headers).value

        $ultimoCommit = $null

        $primeiroCommit = $null



        foreach ($repo in $repos) {

            # Commit mais recente

            $commitsRecentesUrl = "https://dev.azure.com/$org/$projectName/_apis/git/repositories/$($repo.id)/commits?`$top=1"

            $commitsRecentes = (Invoke-RestMethod -Uri $commitsRecentesUrl -Headers $headers).value

            if ($commitsRecentes.Count -gt 0) {

                $dataRecente = $commitsRecentes[0].committer.date

                if (-not $ultimoCommit -or [datetime]$dataRecente -gt [datetime]$ultimoCommit) {

                    $ultimoCommit = $dataRecente

                }

            }



            # Commit mais antigo (para data aproximada da criação)

            $commitsAntigosUrl = "https://dev.azure.com/$org/$projectName/_apis/git/repositories/$($repo.id)/commits?`$top=1&`$orderby=authorDate asc"

            $commitsAntigos = (Invoke-RestMethod -Uri $commitsAntigosUrl -Headers $headers).value

            if ($commitsAntigos.Count -gt 0) {

                $dataAntiga = $commitsAntigos[0].committer.date

                if (-not $primeiroCommit -or [datetime]$dataAntiga -lt [datetime]$primeiroCommit) {

                    $primeiroCommit = $dataAntiga

                }

            }

        }



        if (-not $ultimoCommit) { $ultimoCommit = "Sem commit" }

        if (-not $primeiroCommit) { $primeiroCommit = "Indisponível" }



        # Verifica uso de pipelines

        $pipelinesUrl = "https://dev.azure.com/$org/$projectName/_apis/pipelines?api-version=7.0"

        $pipelines = (Invoke-RestMethod -Uri $pipelinesUrl -Headers $headers).value

        $usouPipeline = "Não"

        foreach ($pipeline in $pipelines) {

            $runsUrl = "https://dev.azure.com/$org/$projectName/_apis/pipelines/$($pipeline.id)/runs?`$top=1"

            $runs = (Invoke-RestMethod -Uri $runsUrl -Headers $headers).value

            if ($runs.Count -gt 0) {

                $usouPipeline = "Sim"

                break

            }

        }



        # Monta o objeto resultado

        $resultados += [PSCustomObject]@{

            Organizacao     = $org

            Projeto         = $projectName

            CriadoEm        = $primeiroCommit

            BoardsUsado     = $temBoards

            UltimoCommit    = $ultimoCommit

            PipelinesUsado  = $usouPipeline

        }

    }

}



# Exporta para CSV

$csvPath = ".\\auditoria-devops-multiorgs.csv"

$resultados | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8



Write-Host "Auditoria concluída! Arquivo salvo em $csvPath"

=====================================================================