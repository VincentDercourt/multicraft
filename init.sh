#!/bin/bash

DIR_ROOT="/mc"
DIR_INSTALL="$DIR_ROOT/install"
MC_DIR="$DIR_ROOT/multicraft"
MC_WEB_DIR="$DIR_ROOT/panel"
MC_WEB_DATAName="data.db"
MC_WEB_DATA="$MC_WEB_DIR/protected/data/$MC_WEB_DATAName"
MC_USER="multicraft"
MC_USERADD="/usr/sbin/useradd"
MC_GROUPADD="/usr/sbin/groupadd"
MC_USERDEL="/usr/sbin/userdel"
MC_GROUPDEL="/usr/sbin/groupdel"
install="1"
FILE="$DIR_ROOT/install.txt"
contentFile="";
if [ -f $FILE ]; then
   install=`cat $FILE`
fi

echo "install : $install"

### Multicraft user & directory setup

echo
echo "Création de l'utilisateur '$MC_USER'"
"$MC_GROUPADD" "$MC_USER"
if [ ! "$?" = "0" ]; then
    echo "Erreur: impossible de créer le group pour l'utilisateur '$MC_USER'!"
fi

"$MC_USERADD" "$MC_USER" -g "$MC_USER" -s /bin/false
if [ ! "$?" = "0" ]; then
    echo "Erreur: Impossible de créer l'utilisateur '$MC_USER'!"
fi

if [ "$install" -eq "1" ]
then

    echo "0" > "$DIR_ROOT/install.txt"

    MC_DAEMON_ID="1"
    MC_DAEMON_IP="`ifconfig 2>/dev/null | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}' | head -n1`"
    MC_DAEMON_PORT="25465"
    MC_DAEMON_DATAName="data.db"
    MC_DAEMON_DATA="$MC_DIR/data/$MC_DAEMON_DATAName"
    MC_DAEMON_PW=${MC_DAEMON_PW:-"changeMe"}
    MC_FTP_IP=${MC_FTP_IP:-""}
    MC_FTP_PORT=${MC_FTP_PORT:-"21"}
    MC_FTP_SERVER=${MC_FTP_SERVER:-"y"}
    MC_DB_TYPE="sqlite"
    MC_KEY=${MC_KEY:-"0B10-A841-E555-3B78"}
    MC_LOCAL="y"
    MC_MULTIUSER="y"
    MC_PLUGINS="n"
    MC_WEB_USER="www-data"
    MC_CREATE_USER="y"
    MC_JAVA="/usr/bin/java"
    MC_ZIP="/usr/bin/zip"
    MC_UNZIP="/usr/bin/unzip"
    next=1

    if [ ! -d "$DIR_INSTALL" ]; then
        mkdir "$DIR_INSTALL"
    fi
    if [ ! -f multicraft.zip ]; then
        next=0
        echo "'multicraft.zip' manquant impossible de poursuivre l'installation!!!"
    fi
    if (($next)); then
        mv multicraft.zip "$DIR_INSTALL/multicraft.zip"
        cd "$DIR_INSTALL"
        if [ -f multicraft.zip ]; then
            unzip multicraft.zip
            rm multicraft.zip
        fi
        cd "$DIR_INSTALL/multicraft"

        trap SIGINT SIGTERM

        INSTALL2="bin/ jar/ launcher/ scripts/ templates/ eula.txt multicraft.conf.dist default_server.conf.dist server_configs.conf.dist"

        ### Basic checks

        for i in $INSTALL2; do
            if [ ! -e "$i" ]; then
                echo "Erreur: impossible de trouver '$i'! Le script doit être placé dans un dossier nommé Multicraft pour démarrer."
                echo "Installation annulé."
                exit
            fi
        done

        ### Begin
        echo
        echo "***"
        echo "*** Bienvenue dans Multicraft!"
        echo "***"
        echo
        echo

        ### Installation

        echo
        echo "NOTE: Tous les daemon seront arrêté!"
        echo "L'installation va commencer!!!"

        echo
        echo "***"
        echo "*** INSTALLATION"
        echo "***"
        echo

        chown -R "$MC_USER":"$MC_USER" "$MC_DIR"
        chmod -R 755 "$MC_DIR"

        if [ -e "$MC_DIR/bin/multicraft" ]; then
            echo "Arrêt de daemon si lancé..."
            "$MC_DIR/bin/multicraft" stop
            "$MC_DIR/bin/multicraft" stop_ftp
            echo "done."
            sleep 1
        fi

        echo
        SAVE_DIR=""
        ### SAVE OLD INSTALL
        if [ -d "$MC_DIR" -o -d "$MC_WEB_DIR" ]; then
            timestamp=$(date +"%s")
            SAVE_DIR="$DIR_ROOT/backup/$timestamp"
            echo "Création du répertoire '$SAVE_DIR/{multicraft,panel}'"
            mkdir -p $SAVE_DIR
        fi

        echo
        echo "Création du répertoire '$MC_DIR'"
        if [ -d "$MC_DIR" ]; then
            if [ -d "$SAVE_DIR" ]; then
                echo "Le repertoire existe déjà il va être copié dans une dossier backup"
                cp -r "$MC_DIR" "$SAVE_DIR/"
            fi
        else
            mkdir -p "$MC_DIR"
        fi

        echo
        if [ ! -d "$MC_DIR" ]; then
            echo "Impossible de créer le répertoire '$MC_DIR'"
            exit
        fi
        echo
        if [ -e "$MC_DAEMON_DATA" ]; then
            echo "Sauvegarde de la base de données sqlite : '$MC_DAEMON_DATA'"
            cp -a "$MC_DAEMON_DATA" "$MC_DAEMON_DATA/$MC_DAEMON_DATAName.bak"
        fi
        echo
        if [ -e "$MC_DIR/bin" -a "$( cd "bin/" && pwd )" != "$( cd "$MC_DIR/bin" 2>/dev/null && pwd )" ]; then
            mv "$MC_DIR/bin" "$MC_DIR/bin.bak"
        fi
        for i in $INSTALL2; do
            echo "Installation de '$i' vers '$MC_DIR/'"
            cp -a "$i" "$MC_DIR/"
        done
        rm -f "$MC_DIR/bin/_weakref.so"
        rm -f "$MC_DIR/bin/collections.so"
        rm -f "$MC_DIR/bin/libpython2.5.so.1.0"
        rm -f "$MC_DIR/bin/"*-py2.5*.egg

        if [ "$MC_KEY" != "no" ]; then
            echo
            echo "Installation de la license"
            echo "$MC_KEY" > "$MC_DIR/multicraft.key"
        fi

        ### Generate config

        echo
        CFG="$MC_DIR/multicraft.conf"
        if [ -e "$CFG" ]; then
            echo "Le fichier multicraft.conf existe déjà. Il va être copié puis écrasé."
            cp -a "$CFG" "$CFG.bak"
            echo "Génération du fichier 'multicraft.conf'"
            > "$CFG"
        fi

        function repl {
            LINE="$SETTING = `echo $1 | sed "s/['\\&,]/\\\\&/g"`"
        }

        SECTION=""
        cat "$CFG.dist" | while IFS="" read -r LINE
        do
            if [ "`echo $LINE | grep "^ *\[\w\+\] *$"`" ]; then
                SECTION="$LINE"
                SETTING=""
            else
                SETTING="`echo $LINE | sed -n 's/^ *\#\? *\([^ ]\+\) *=.*/\1/p'`"
            fi
            case "$SECTION" in
            "[multicraft]")
                case "$SETTING" in
                "user")         repl "$MC_USER" ;;
                "ip")           if [ "$MC_LOCAL" != "y" ]; then repl "$MC_DAEMON_IP";       fi ;;
                "port")         if [ "$MC_LOCAL" != "y" ]; then repl "$MC_DAEMON_PORT";     fi ;;
                "password")     repl "$MC_DAEMON_PW" ;;
                "id")           repl "$MC_DAEMON_ID" ;;
                "database")     if [ "$MC_DB_TYPE" = "sqlite" ]; then repl "sqlite:$MC_DAEMON_DATA";        fi ;;
                "webUser")      if [ "$MC_DB_TYPE" = "mysql" ]; then repl "";               else repl "$MC_WEB_USER"; fi ;;
                "baseDir")      repl "$MC_DIR" ;;
                esac
            ;;
            "[ftp]")
                case "$SETTING" in
                "enabled")          if [ "$MC_FTP_SERVER" = "y" ]; then repl "true";    else repl "false"; fi ;;
                "ftpIp")            repl "$MC_FTP_IP" ;;
                "ftpPort")          repl "$MC_FTP_PORT" ;;
                "forbiddenFiles")   if [ "$MC_PLUGINS" = "n" ]; then repl "";           fi ;;
                esac
            ;;
            "[minecraft]")
                case "$SETTING" in
                "java") repl "$MC_JAVA" ;;
                esac
            ;;
            "[system]")
                case "$SETTING" in
                "unpackCmd")    repl "$MC_UNZIP"' -quo "{FILE}"' ;;
                "packCmd")      repl "$MC_ZIP"' -qr "{FILE}" .' ;;
                esac
                if [ "$MC_MULTIUSER" = "y" ]; then
                    case "$SETTING" in
                    "multiuser")    repl "true" ;;
                    "addUser")      repl "$MC_USERADD"' -c "Multicraft Server {ID}" -d "{DIR}" -g "{GROUP}" -s /bin/false "{USER}"' ;;
                    "addGroup")     repl "$MC_GROUPADD"' "{GROUP}"' ;;
                    "delUser")      repl "$MC_USERDEL"' "{USER}"' ;;
                    "delGroup")     repl "$MC_GROUPDEL"' "{GROUP}"' ;;
                    esac
                fi
            ;;
            "[backup]")
                case "$SETTING" in
                "command")  repl "$MC_ZIP"' -qr "{WORLD}-tmp.zip" . -i "{WORLD}"*/*' ;;
                esac
            ;;
            esac
            echo "$LINE" >> "$CFG"
        done

        echo
        echo "Ajout des permission sur le répertoire '$MC_DIR' pour '$MC_USER'"
        chown -R "$MC_USER":"$MC_USER" "$MC_DIR"
        chmod -R 755 "$MC_DIR"
        chmod 555 "$MC_DIR/launcher/launcher"
        chmod 555 "$MC_DIR/scripts/getquota.sh"

        echo "Paramétrage des permissions spécial"
        if [ "$MC_MULTIUSER" = "y" ]; then
            chown 0:"$MC_USER" "$MC_DIR/bin/useragent"
            chmod 4550 "$MC_DIR/bin/useragent"
        fi
        chmod 755 "$MC_DIR/jar/"*.jar 2> /dev/null

        ### Install PHP frontend

        if [ "$MC_LOCAL" = "y" ]; then
            echo
            if [ -e "$MC_WEB_DIR" ]; then
                if [ -d "$SAVE_DIR" ]; then
                    echo "Le repertoire existe déjà il va être copié dans une dossier backup"
                    cp -r "$MC_WEB_DIR" "$SAVE_DIR/"
                fi
                if [ -e "$MC_WEB_DATA" ]; then
                    echo "Sauvegarde de la base de donnée sqlite : '$MC_WEB_DATA'"
                    cp -a "$MC_WEB_DATA" "$MC_WEB_DATA.bak"
                fi
                if [ -e "$MC_WEB_DIR/protected/config/config.php" ]; then
                    echo "Le répertoire web existe, sauvegarde $MC_WEB_DIR/protected/config/config.php"
                    cp -a "$MC_WEB_DIR/protected/config/config.php" "$MC_WEB_DIR/protected/config/config.php.bak"
                fi
            fi

            echo "Création du repertoire '$MC_WEB_DIR'"
            mkdir -p "$MC_WEB_DIR"

            echo "Installation du panneau de contrôle '$DIR_INSTALL/panel/' vers '$MC_WEB_DIR'"
            cp -a panel/* "$MC_WEB_DIR"
            cp -a panel/.ht* "$MC_WEB_DIR"

            echo "Paramétrage du propriétaire du répertoire '$MC_WEB_DIR' vers '$MC_WEB_USER'"
            chown -R "$MC_WEB_USER":1000 "$MC_WEB_DIR"
            echo "Paramétrage des permission de '$MC_WEB_DIR'"
            chmod -R o-rwx "$MC_WEB_DIR"

        else
            ### PHP frontend not on local machine
            echo
            echo "* NOTE: Le frontend PHP ne sera pas installé sur cette machine. Mettez le contenu du répertoire 'panel/' dans la racine www de la machine que vous souhaitez exécuter le frontend PHP et exécutez le programme d'installation (install.php)."
        fi

        echo "Démarrage temporaire du daemon pour définir les autorisations de base de données."
        "$MC_DIR/bin/multicraft" set_permissions

        echo
        echo
        echo "***"
        echo "*** Installation complète!"
        echo "***"
        echo "***"
        echo
        echo "Veuillez lire:"
        echo
        echo "Avant de démarrer le daemon vous devez exécuter le programme d'installistion du panneau de contrôle pour initialiser votre base de données. (Exemple : example: http://votre.adresse/multicraft/install.php)"
        echo
        echo "Le daemon ne fonctionnera pas correctement tant que la base de données n'a pas été initialisée."
        echo
        echo
        echo "Après avoir exécuté le programme d'installation du panneau de contrôle, démarrez le daemon en utilisant la commande suivante:"
        echo "$MC_DIR/bin/multicraft start"
        echo
        echo
        echo "S'il y a des problème, vérifiez le fichier log: '$MC_DIR/multicraft.log'"
        echo
        echo
        echo "Dans le cas où vous souhaitez relancer ce script, vous pouvez enregistrer les paramètres saisis."

        cd "$MC_DIR"

        if [ -d "$DIR_INSTALL" ]; then
            rm -r "$DIR_INSTALL"
        fi
    fi
elif [ "$install" -eq "0" ]
then
    if [ -f "$MC_WEB_DIR/install.php" -a -f "$MC_WEB_DIR/protected/config/config.php" -a -f "$MC_WEB_DATA" ]; then
        rm "$MC_WEB_DIR/install.php"
    fi
fi
echo "install : $install"
echo "<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot $MC_WEB_DIR
    <Directory $MC_WEB_DIR>
        Options +Indexes +FollowSymLinks +MultiViews
        Order Allow,Deny
        Allow from all
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>" > /etc/apache2/sites-enabled/000-default.conf

service apache2 restart
/mc/multicraft/bin/multicraft start

/bin/bash