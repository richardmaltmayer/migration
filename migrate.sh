set -e

REPO_ORIGEM="/home/richard-almayer/Documentos/dev/pocs/migration/g2"
BRANCH_ORIGEM="main"
PATCH_DIR="/home/richard-almayer/Documentos/dev/pocs/migration/grails-sync-patches"
LOG_FILE="/home/richard-almayer/Documentos/dev/pocs/migration/grails-sync.log"

echo "==== [$(date)] Iniciando sincronização ====" | tee -a $LOG_FILE
cd "$REPO_ORIGEM"
echo "→ Atualizando repositório origem..." | tee -a $LOG_FILE

git fetch origin
git checkout $BRANCH_ORIGEM
git pull origin $BRANCH_ORIGEM

mkdir -p $PATCH_DIR
echo "→ Gerando patches..." | tee -a $LOG_FILE
git format-patch origin/$BRANCH_ORIGEM..origin/$BRANCH_ORIGEM -o $PATCH_DIR
# git format-patch $(git merge-base $BRANCH_ORIGEM origin/$BRANCH_ORIGEM)..origin/$BRANCH_ORIGEM -o $PATCH_DIR



echo "✅ Sincronização concluída com sucesso." | tee -a $LOG_FILE