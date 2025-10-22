# 1. Capturar o patch do PR remoto (Grails 2)

# Número do PR que você quer migrar
PR_NUMBER=12

# Caminho do patch
PATCH_FILE="/home/richard-almayer/Documentos/dev/pocs/migration/patches/pr${PR_NUMBER}-g2.patch"

# URL do repositório Grails 2
REPO_G2="https://github.com/richardmaltmayer/g2"
REPO_G4="https://github.com/richardmaltmayer/g4"

# Baixar o patch do PR remoto
curl -L "${REPO_G2}/pull/${PR_NUMBER}.patch" -o "$PATCH_FILE"

echo "Patch salvo em: $PATCH_FILE"


# -------------------------------------------
# 2. Criar uma branch no repositório destino (Grails 4)

# Diretório do repositório Grails 4
cd ~/Documentos/dev/pocs/migration/g4

# Atualizar referências locais
git fetch origin
git fetch g2

# Certificar-se de estar na branch principal
git checkout main
git pull origin main

# Criar nova branch para o PR
BRANCH_NAME="migration/pr${PR_NUMBER}_$(date +%Y%m%d%H%M%S)"

git branch "$BRANCH_NAME"
git checkout "$BRANCH_NAME"

echo "Branch criada: $BRANCH_NAME"

# -------------------------------------------
# Pré processamento do patch
# -------------------------------------------
sed -i 's#grails-app/conf/#grails-app/init/g4/#g' $PATCH_FILE
sed -i 's#src/groovy/#src/main/groovy/#g' $PATCH_FILE

# -------------------------------------------
# 3. Aplicar o patch (alterações do PR Grails 2)

# Aplicar o patch com preservação de autor/data/mensagem
git am --3way --whitespace=fix "$PATCH_FILE"

git push -u origin $BRANCH_NAME

echo "Patch Aplicado"

# -------------------------------------------
# 5. Executar o script de migração (.NET)

# dotnet build && dotnet run --project ~/Documentos/dev/projects/asaas-core-grails-migrator/GrailsMigrator


# -------------------------------------------
# 4. Criar um novo Pull Request (no Grails 4)

# Commit aplicado — criar PR referenciando o PR original
git fetch origin

gh repo set-default $REPO_G4

gh pr create \
  --title "Migração PR #${PR_NUMBER} (Grails 2 → Grails 4)" \
  --body "Este PR foi gerado automaticamente a partir do PR [#${PR_NUMBER}](${REPO_G2}/pull/${PR_NUMBER}) no repositório Grails 2. As alterações foram aplicadas e serão processadas pelo script de migração .NET para adequação à estrutura Grails 4." \
  --base main \
  --head "$BRANCH_NAME"

echo "PR criada: $BRANCH_NAME"

# -------------------------------------------
# 6. Realizar commit das alterações de migração

cd ~/Documentos/dev/pocs/migration/g4

git add -A

git commit -m "migration(adapt): adequações automáticas para PR #${PR_NUMBER} (Grails 2 → Grails 4)"


# -------------------------------------------
# 7. Atualizar o PR com as alterações de migração

git push origin "$BRANCH_NAME"


# -------------------------------------------
# 8. Merge automático do PR (se testes passarem ou se permitido)

gh pr merge "$BRANCH_NAME" \
  --merge \
  --auto \
  --delete-branch \
  --squash=false
