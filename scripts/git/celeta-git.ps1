<#
Fluxo Git da Celeta (ver docs/process/git-flow.md).

Hierarquia:  main <- develop <- spec/<nome> <- feature/<tarefa>-<slug>

Uso (na raiz do repositório, PowerShell):
  .\scripts\git\celeta-git.ps1 bootstrap
  .\scripts\git\celeta-git.ps1 spec-start -Spec architecture
  .\scripts\git\celeta-git.ps1 feature-start -Spec architecture -Task T01 -Slug fundacao
  .\scripts\git\celeta-git.ps1 feature-finish -Message "feat(T01): estrutura, config e pool MySQL"
  .\scripts\git\celeta-git.ps1 spec-finish
  .\scripts\git\celeta-git.ps1 mvp-release
#>
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateSet('bootstrap', 'spec-start', 'feature-start', 'feature-finish', 'spec-finish', 'mvp-release')]
  [string]$Command,

  [ValidateSet('architecture', 'auth', 'profiles', 'jobs', 'discovery', 'resumes', 'applications', 'screening')]
  [string]$Spec,

  [ValidatePattern('^T\d{2}$')]
  [string]$Task,

  [ValidatePattern('^[a-z0-9]+(-[a-z0-9]+)*$')]
  [string]$Slug,

  [string]$Message
)

$ErrorActionPreference = 'Stop'
$Main = 'main'
$Develop = 'develop'

function Invoke-Git {
  & git @args
  if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') falhou (código $LASTEXITCODE)" }
}

function Get-Current {
  return (& git rev-parse --abbrev-ref HEAD).Trim()
}

function Test-LocalBranch([string]$name) {
  & git show-ref --verify --quiet "refs/heads/$name"
  return ($LASTEXITCODE -eq 0)
}

function Test-CleanTree {
  $changes = & git status --porcelain
  return (-not $changes)
}

function Set-Base([string]$branch, [string]$base) {
  Invoke-Git config "branch.$branch.celetaBase" $base
}

function Get-Base([string]$branch) {
  $base = & git config --get "branch.$branch.celetaBase"
  if (-not $base) {
    throw "Base não registrada para '$branch'. Crie a branch com spec-start ou feature-start."
  }
  return $base.Trim()
}

function New-Pr([string]$base, [string]$head, [string]$title, [string]$body) {
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) não encontrado. Instale e rode: gh auth login'
  }
  & gh pr create --base $base --head $head --title $title --body $body
  if ($LASTEXITCODE -ne 0) { throw "Falha ao criar PR de $head para $base" }
}

switch ($Command) {

  'bootstrap' {
    if (-not (Test-Path .git)) { Invoke-Git init -b $Main }
    if (-not ((& git remote) -contains 'origin')) {
      throw 'Configure o remoto antes: git remote add origin <url-do-repositorio>'
    }
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & git rev-parse --verify --quiet HEAD *> $null
    $hasCommit = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = $prevPref
    if (-not $hasCommit) { Invoke-Git commit --allow-empty -m 'chore: início do projeto' }
    if (-not (Test-LocalBranch $Develop)) { Invoke-Git branch $Develop $Main }
    Invoke-Git push -u origin $Main
    Invoke-Git push -u origin $Develop
    Invoke-Git checkout $Develop
    Write-Host 'Bootstrap pronto: main e develop criadas e publicadas.'
  }

  'spec-start' {
    if (-not $Spec) { throw 'Informe -Spec' }
    $branch = "spec/$Spec"
    Invoke-Git checkout $Develop
    Invoke-Git pull --ff-only origin $Develop
    if (-not (Test-LocalBranch $branch)) {
      Invoke-Git checkout -b $branch $Develop
      Set-Base $branch $Develop
    } else {
      Invoke-Git checkout $branch
    }
    Invoke-Git push -u origin $branch
    Write-Host "Branch $branch pronta."
  }

  'feature-start' {
    if (-not $Spec -or -not $Task -or -not $Slug) { throw 'Informe -Spec, -Task e -Slug' }
    $parent = "spec/$Spec"
    $branch = "feature/$Task-$Slug"
    if (-not (Test-LocalBranch $parent)) { throw "Branch $parent não existe. Rode spec-start -Spec $Spec" }
    if (Test-LocalBranch $branch) { throw "Branch $branch já existe" }
    Invoke-Git checkout $parent
    Invoke-Git checkout -b $branch $parent
    Set-Base $branch $parent
    Invoke-Git push -u origin $branch
    Write-Host "Branch $branch criada a partir de $parent."
  }

  'feature-finish' {
    $branch = Get-Current
    if (-not $branch.StartsWith('feature/')) { throw "Não está em feature/: $branch" }
    if (-not $Message) { throw 'Informe -Message no formato: tipo(escopo): descrição' }
    if ($Message -notmatch '^(feat|fix|docs|test|chore|refactor)(\(.+\))?: .+') {
      throw 'Mensagem fora do padrão. Ex.: feat(T01): estrutura base'
    }
    $base = Get-Base $branch
    Invoke-Git add -A
    & git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) { throw 'Nada para commitar.' }
    Invoke-Git commit -m $Message
    Invoke-Git push -u origin $branch
    New-Pr $base $branch $Message "Feature $branch, base $base. Tarefa em docs/tasks/backlog.md, spec em docs/specifications."
    Write-Host 'PR criado. Mescle no GitHub antes de rodar spec-finish ou a próxima feature da mesma spec.'
  }

  'spec-finish' {
    $branch = Get-Current
    if (-not $branch.StartsWith('spec/')) { throw "Não está em spec/: $branch" }
    if (-not (Test-CleanTree)) { throw 'Há alterações não commitadas. Use feature-finish primeiro.' }
    $base = Get-Base $branch
    $specName = $branch.Substring(5)
    Invoke-Git push -u origin $branch
    New-Pr $base $branch "spec: $specName" "Entrega da spec $specName em $base. Todas as features da spec foram mescladas em $branch."
    Write-Host 'PR criado. Mescle no GitHub antes de iniciar a próxima spec.'
  }

  'mvp-release' {
    Invoke-Git checkout $Develop
    if (-not (Test-CleanTree)) { throw 'Há alterações não commitadas em develop.' }
    Invoke-Git push -u origin $Develop
    New-Pr $Main $Develop 'MVP: develop para main' 'Release final do MVP. Só mesclar com todas as specs em develop e testes verdes.'
    Write-Host 'PR de release criado.'
  }
}
