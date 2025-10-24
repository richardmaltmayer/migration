#!/bin/bash

# Número do PR que você quer migrar
PR_NUMBER=22

# Caminho do projeto do script de transformação de artefatos
SCRIPT_PATH="/home/richard-almayer/Documentos/dev/projects/asaas-core-grails-migrator"

# Caminho do patch
PATCH_FILE="/home/richard-almayer/Documentos/dev/pocs/migration/patches/pr${PR_NUMBER}-g2.patch"

# URL dos repositórios
REPO_G2="https://github.com/richardmaltmayer/g2"
REPO_G4="https://github.com/richardmaltmayer/g4"

# Diretórios do projeto
PROJECT_G2=~/Documentos/dev/pocs/migration/g2
PROJECT_G4=~/Documentos/dev/pocs/migration/g4

# Setup
function setup() {
  export GH_TOKEN=$(<secrets.txt)

  cd $PROJECT_G2
  git checkout main
  git pull

  cd $PROJECT_G4
  git checkout main
  git pull

  dotnet build $SCRIPT_PATH
}

# Captura o patch do PR remoto (Grails 2)
function get_patch_pr() {
  curl -L "${REPO_G2}/pull/${PR_NUMBER}.patch" -o "$PATCH_FILE"
  echo "Patch salvo em: $PATCH_FILE"
}

# Verifica arquivos (não deletados) em patch
function verify_files_to_migrate() {
  patch_files_to_migrate=$(awk '
    function clean(p) {
      gsub(/^b\//, "", p)
      gsub(/^"|"$/, "", p)    # remove possíveis aspas
      return p
    }

    # Quando começa um diff para um arquivo: capturamos o caminho "b/..."
    /^diff --git/ {
      # Ex.: diff --git a/path/to/file b/path/to/file
      # $3 = a/..., $4 = b/...
      file = clean($4)
      deleted[file] = 0
      printed[file] = 0
      next
    }

    # Se o patch indica que o arquivo foi deletado, marcamos
    /deleted file mode/ {
      if (file != "") deleted[file] = 1
      next
    }

    # Linhas de rename explícitas (rename to ...)
    /^rename to / {
      # formato: "rename to src/groovy/..." -> pega o terceiro campo
      to = $3
      to = clean(to)
      file = to
      deleted[file] = 0
      printed[file] = 0
      next
    }

    # Se surgem hunks e o arquivo atual não foi deletado, registramos
    /^@@/ {
      if (file != "" && !deleted[file] && !printed[file]) {
        print file
        printed[file] = 1
      }
      next
    }

    # Quando encontramos "similarity index" ou "rename ..." sem hunks,
    # precisamos garantir que o arquivo seja emitido — tratamos na transição de diff ou no END.
    /^rename / { next }

    # Ao encontrar a linha de separação de commits (--- ou From ), 
    # podemos emitir o arquivo atual se ainda não foi impresso.
    /^--- $/ { 
      if (file != "" && !deleted[file] && !printed[file]) {
        print file; printed[file] = 1
      }
      next
    }

    # Ao encontrar uma nova diff (linha que inicia novo diff) - já tratada no início,
    # mas como segurança, quando virmos uma linha que parece de sumário, emitimos
    /^$/ { next }

    END {
      # garante que o último arquivo também seja emitido se não teve @@
      for (f in printed) {
        # nothing: printed[] já marca quem foi impresso
      }
      if (file != "" && !deleted[file] && !printed[file]) {
        print file
      }
    }
  ' "$PATCH_FILE" | sort -u)

  echo $patch_files_to_migrate
}

# Renomeia/move arquivos, quando necessário, prevendo compatibilidade com Grails 4
function rename_patch_files_if_necessary() {
  files_to_migrate=$(verify_files_to_migrate)

  for file in $files_to_migrate; do
    newFilePath=$(dotnet run --project $SCRIPT_PATH/GrailsMigrator -- path $file)

    echo "$file - $newFilePath"

    if [ -n "$newFilePath" ]; then
      sed -i "s#$file#$newFilePath#g" $PATCH_FILE
    fi
  done
}

# Aplicar o patch com preservação de autor/data/mensagem
function apply_patch() {
  cd $PROJECT_G4

  git checkout $BRANCH_NAME

  git am --abort

  git am --3way --whitespace=fix "$PATCH_FILE"
  git add -A 
  git commit -m "Patch aplicado"
  git push -u origin $BRANCH_NAME

  echo "Patch Aplicado"
}

function copy_files_if_necessary() {
  cd $PROJECT_G2
  git checkout main
  git pull

  # Processo fixo para um Filter/Interceptor
  cat $PROJECT_G2/grails-app/conf/web/CustomFilters.groovy > $PROJECT_G4/grails-app/controllers/com/asaas/interceptor/CustomInterceptor.groovy

  cd $PROJECT_G4

  git add -A 
  git commit -m "Refaz arquivo com base no Filters"
  git push origin "$BRANCH_NAME"

  echo "Conteúdo do arquivo recriado"
}

# Criar uma branch no repositório destino (Grails 4)
function create_grails4_branch() {
  cd $PROJECT_G4

  git fetch origin
  git fetch g2

  git checkout main
  git pull origin main

  BRANCH_NAME="migration/pr${PR_NUMBER}_$(date +%Y%m%d%H%M%S)"

  git branch "$BRANCH_NAME"
  git checkout "$BRANCH_NAME"

  echo "Branch criada: $BRANCH_NAME"
}

# Executar o script de migração (.NET)
function execute_migration() {
  echo "executing"

  files_to_migrate=$(verify_files_to_migrate)

  for file in $files_to_migrate; do
    dotnet run --project $SCRIPT_PATH/GrailsMigrator -- transform $file
  done
}

# Criar um novo Pull Request (no Grails 4)
function create_grails4_pr() {
  git fetch origin
  gh repo set-default $REPO_G4

  gh pr create \
    --title "Migração PR #${PR_NUMBER} (Grails 2 → Grails 4)" \
    --body "Este PR foi gerado automaticamente a partir do PR [#${PR_NUMBER}](${REPO_G2}/pull/${PR_NUMBER}) no repositório Grails 2. As alterações foram aplicadas e serão processadas pelo script de migração .NET para adequação à estrutura Grails 4." \
    --base main \
    --head "$BRANCH_NAME"

  echo "PR criada: $BRANCH_NAME"
}

# Realizar commit das alterações de migração
function commit_grails4() {
  cd $PROJECT_G4

  git add -A
  git commit -m "$1"
  git push origin "$BRANCH_NAME"
}

# 8. Merge automático do PR
function approve_merge() {
  cd $PROJECT_G4

  gh pr merge "$BRANCH_NAME" \
    --merge \
    --auto \
    --delete-branch \
    --squash=false
}

setup
echo ">> 1"
get_patch_pr
echo ">> 2"
rename_patch_files_if_necessary
echo ">> 3"
create_grails4_branch
echo ">> 4"
copy_files_if_necessary
echo ">> 5"
apply_patch
echo ">> 6"
commit_grails4 "migration(adapt): adequações automáticas para PR #${PR_NUMBER} (Grails 2 → Grails 4)"
echo ">> 7"
create_grails4_pr
echo ">> 8"
execute_migration
echo ">> 9"
commit_grails4 "Transformações via script"
echo ">> 10"
#approve_merge
#echo ">> 11"


