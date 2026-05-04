#!/bin/bash
set -e

############################################
# VARIABILI
############################################
HTTPD_ROOT="/prod/IBM/HTTPServer"
BACKUP_ROOT="/prod/IBM/backup"
LOGS_DIR="$HTTPD_ROOT/logs"
REBOOT_NEEDED=0
DRY_RUN=0

############################################
# FUNZIONI
############################################
error_exit() {
  echo "[ERRORE] $1"
  exit 1
}

info() {
  echo "[INFO] $1"
}

run_cmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] $*"
  else
    eval "$@"
  fi
}

############################################
# PARSE ARGOMENTI
############################################
  DRY_RUN=1
 info "Esecuzione in modalità DRY-RUN (nessuna operazione verrà eseguita)"

############################################
# CHECK 1 - libreria libexpat caricata
############################################
info "CHECK 1: Verifica libreria libexpat caricata"

CHECK1=$(lsof -p "$(pidof dbus-broker-launch)" 2>/dev/null | grep libexpat || true)

if echo "$CHECK1" | grep -q HTTPServer; then
  info "libexpat caricata da HTTPServer: pulizia ld.so e richiesta reboot"
  run_cmd "rm -fv /etc/ld.so.conf.d/httpd-lib.conf /etc/ld.so.cache"
  REBOOT_NEEDED=1
  info "⚠️  RIAVVIO MACCHINA NECESSARIO"
fi

############################################
# CHECK 2 - riconferma libreria libexpat
############################################
info "CHECK 2: Riconferma libreria libexpat"

CHECK2=$(lsof -p "$(pidof dbus-broker-launch)" 2>/dev/null | grep libexpat || true)

if echo "$CHECK2" | grep -q HTTPServer; then
  error_exit "libexpat ancora caricata da HTTPServer"
fi

############################################
# CHECK 3 - spazio disco per backup logs
############################################
info "CHECK 3: Verifica spazio disponibile per backup log"

LOGS_SIZE=$(du -sk "$LOGS_DIR" | awk '{print $1}')
AVAILABLE_SPACE=$(df -k /prod | awk 'NR==2 {print $4}')

if [ "$AVAILABLE_SPACE" -lt "$LOGS_SIZE" ]; then
  error_exit "Spazio insufficiente per il backup dei log"
fi

############################################
# CHECK 4 / 5 - Detection Installation Manager
############################################
info "CHECK 4/5: Ricerca Installation Manager"

if [ -d "/prod/IBM/InstallationManager" ]; then
  IM_INSTALLATION_HOME="/prod/IBM/InstallationManager"
elif [ -d "/opt/IBM/InstallationManager" ]; then
  IM_INSTALLATION_HOME="/opt/IBM/InstallationManager"
else
  error_exit "Installation Manager non trovato"
fi

info "Installation Manager rilevato in: $IM_INSTALLATION_HOME"

############################################
# STOP IHS
############################################
info "Stop di tutte le istanze IHS"

pgrep -f httpd | while read -r PID; do
  run_cmd "kill -9 $PID"
done || true

############################################
# FASE DI BACKUP
############################################
info "INIZIO FASE DI BACKUP"

run_cmd "mkdir -pv '$BACKUP_ROOT/IHS/logs' '$BACKUP_ROOT/IHS/htdocs' '$BACKUP_ROOT/WebSphere/Plugins/config'"

run_cmd "find '$HTTPD_ROOT' -mindepth 1 -maxdepth 1 -type d \
! -name bin ! -name build ! -name cgi-bin ! -name codeset ! -name conf \
! -name example_module ! -name gsk8 ! -name htdocs ! -name icons \
! -name ihsdiag ! -name include ! -name lafiles ! -name lib ! -name logs \
! -name man ! -name modules ! -name properties ! -name readme ! -name swidtag \
! -name error ! -name java ! -name plugins ! -name uninstall ! -name util \
-exec cp -a -t '$BACKUP_ROOT/IHS/' {} +"

run_cmd "find '$HTTPD_ROOT/htdocs' -mindepth 1 -maxdepth 1 -type d \
! -name images -exec cp -a {} '$BACKUP_ROOT/IHS/htdocs' \;"

run_cmd "find /prod/IBM/WebSphere/Plugins/config -mindepth 1 -maxdepth 1 -type d \
! -name actionRegistry ! -name templates \
-exec cp -a {} '$BACKUP_ROOT/WebSphere/Plugins/config' \;"

run_cmd "find '$LOGS_DIR' -mindepth 1 -maxdepth 1 -type d \
! -name postinstall -exec cp -a {} '$BACKUP_ROOT/IHS/logs' \;"

info "FINE FASE DI BACKUP"

############################################
# DISINSTALLAZIONE PLUGINS 8.5
############################################
info "Disinstallazione Plugins 8.5"

run_cmd "'$IM_INSTALLATION_HOME'/eclipse/tools/imcl uninstall com.ibm.websphere.PLG.v85"
run_cmd "rm -rf /prod/IBM/WebSphere/Plugins"

############################################
# DISINSTALLAZIONE IHS 8.5
############################################
info "Disinstallazione IHS 8.5"

run_cmd "'$IM_INSTALLATION_HOME'/eclipse/tools/imcl uninstall com.ibm.websphere.IHS.v85"
run_cmd "rm -rf '$HTTPD_ROOT'"

############################################
# AGGIORNAMENTO INSTALLATION MANAGER
############################################
info "Aggiornamento Installation Manager"

run_cmd "mkdir -pv /prod/IBM/IM_INSTALL"
run_cmd "cd /prod/IBM/IM_INSTALL"
run_cmd "curl -o agent.installer.linux.zip http://stcwebiblprepo1.srv.sogei.it/IM/agent.installer.linux.gtk.x86_64_1.10.1003.20250827_1041.zip"
run_cmd "unzip -q agent.installer.linux.zip -d im"
run_cmd "im/installc -acceptLicense -showProgress -preferences com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts=false"
run_cmd "rm -rf im"

############################################
# INSTALLAZIONE PLUGINS 9.0
############################################
info "Installazione Plugins 9.0"

run_cmd "'$IM_INSTALLATION_HOME'/eclipse/tools/imcl install \
com.ibm.websphere.PLG.v90 com.ibm.java.jdk.v8 \
-installationDirectory /prod/IBM/WebSphere/Plugins \
-repositories http://stcwebiblprepo1.srv.sogei.it/WAS-IHS-PLG9.0.x_multiplatform/repository.config,\
http://stcwebiblprepo1.srv.sogei.it/LIBERTY_JDK/LIBERTYJDK_8.0/ibm-java-sdk-8.0-8.50-linux-x64-installmgr.zip \
-acceptLicense -preferences com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts=false \
-showProgress"

############################################
# INSTALLAZIONE IHS 9.0
############################################
info "Installazione IHS 9.0"

run_cmd "'$IM_INSTALLATION_HOME'/eclipse/tools/imcl install \
com.ibm.websphere.IHS.v90 com.ibm.java.jdk.v8 \
-installationDirectory '$HTTPD_ROOT' \
-repositories http://stcwebiblprepo1.srv.sogei.it/WAS-IHS-PLG9.0.x_multiplatform/repository.config,\
http://stcwebiblprepo1.srv.sogei.it/LIBERTY_JDK/LIBERTYJDK_8.0/ibm-java-sdk-8.0-8.50-linux-x64-installmgr.zip \
-acceptLicense -preferences com.ibm.cic.common.core.preferences.preserveDownloadedArtifacts=false \
-showProgress"

############################################
# RIPRISTINO CONFIGURAZIONI
############################################
info "Ripristino configurazioni e log"

run_cmd "cp -a '$BACKUP_ROOT/IHS/'* '$HTTPD_ROOT/'"
run_cmd "cp -a '$BACKUP_ROOT/WebSphere/Plugins/'* /prod/IBM/WebSphere/Plugins/"

############################################
# OWNER
############################################
run_cmd "chown -R webihs:webihs '$HTTPD_ROOT' /prod/IBM/WebSphere/Plugins"

info "Script completato con successo"

if [ "$REBOOT_NEEDED" -eq 1 ]; then
  info "⚠️  È richiesto un RIAVVIO DEL SISTEMA"
fi
