#!/bin/bash

Green="\033[32m"
Red="\033[31m"
Yellow='\033[33m'
Font="\033[0m"
INFO="${Green}INFO${Font}"
ERROR="${Red}ERROR${Font}"
WARN="${Yellow}WARN${Font}"
Time=$(date +"%Y-%m-%d %T")
INFO(){
echo -e "${Time} ${INFO}    | ${1}"
}
ERROR(){
echo -e "${Time} ${ERROR}    | ${1}"
}
WARN(){
echo -e "${Time} ${WARN}    | ${1}"
}

umask "${UMASK}"

## 创建文件夹
function __mkdir_dir {

    nginx_run="/var/run/nginx"
    bgmi_conf="/bgmi/conf/bgmi"
    bgmi_nginx="/bgmi/conf/nginx"
    bgmi_log="/bgmi/log"
    media_cartoon=${MEDIA_DIR}
    meida_downloads=${DOWNLOAD_DIR}

    if [ ! -d ${nginx_run} ]; then
    	mkdir -p ${nginx_run}
    fi

    if [ ! -d ${bgmi_conf} ]; then
    	mkdir -p ${bgmi_conf}
    fi

    if [ ! -d ${bgmi_nginx} ]; then
    	mkdir -p ${bgmi_nginx}
    fi

    if [ ! -d ${bgmi_log} ]; then
    	mkdir -p ${bgmi_log}
    fi

    if [ ! -d ${media_cartoon} ]; then
    	mkdir -p ${media_cartoon}
    fi

    if [ ! -d ${meida_downloads} ]; then
    	mkdir -p ${meida_downloads}
    fi

}

function __bgmi_crond {

    crontab -r
    if [ ! -f /etc/crontabs/root ]; then
        touch /etc/crontabs/root
    fi
    bash ${BGMI_HOME}/BGmi/bgmi/others/crontab.sh

}

# 设置BGMI
function __config_bgmi {

    bangumi_db="$BGMI_PATH/bangumi.db"
    bgmi_config="$BGMI_PATH/config.toml"

    cp ${BGMI_HOME}/config/crontab.sh ${BGMI_HOME}/BGmi/bgmi/others/crontab.sh

    if [ ! -f $bangumi_db ]; then
    	bgmi install
        __bgmi_crond
    else
    	bgmi upgrade
        __bgmi_crond
    fi

    bgmi config set save_path --value ${DOWNLOAD_DIR}

    if [ "${BGMI_VERSION}" == "transmission" ]; then
        bgmi config set download_delegate --value transmission-rpc
        bgmi config set transmission rpc_path --value /tr/rpc
        if [[ -n "$TR_USER" ]] && [[ -n "$TR_PASS" ]]; then
            bgmi config set transmission rpc_username --value ${TR_USER}
            bgmi config set transmission rpc_password --value ${TR_PASS}
        fi
    elif [ "${BGMI_VERSION}" == "aria2" ]; then
        bgmi config set download_delegate --value aria2-rpc
        bgmi config set aria2 rpc_token --value token:${ARIA2_RPC_SECRET}
        bgmi config set aria2 rpc_url --value http://127.0.0.1:${ARIA2_RPC_PORT}/rpc
    fi

}

function __config_bgmi_hardlink {

    if [ ! -d ${BGMI_HARDLINK_PATH} ]; then
    	mkdir -p ${BGMI_HARDLINK_PATH}
    fi

    if [ ! -f ${BGMI_HARDLINK_PATH}/config.py ]; then
        dockerize -no-overwrite -template ${BGMI_HOME}/hardlink/config.py:${BGMI_HARDLINK_PATH}/config.py
    fi
    
    rm -rf ${BGMI_HOME}/hardlink/config.py

    (crontab -l ; echo "20 */2 * * * umask ${UMASK}; LC_ALL=zh_CN.UTF-8 su-exec bgmi $(which python3) ${BGMI_HOME}/hardlink/hardlink.py run") | crontab -
    INFO "hard link timing task setting is completed"

}

# 设置Nginx
function __config_nginx {

    bgmi_nginx="/bgmi/conf/nginx"
    bgmi_nginx_conf="$bgmi_nginx/bgmi.conf"
    nginx_conf_dir="/etc/nginx/http.d"

    rm -rf $nginx_conf_dir
    ln -s $bgmi_nginx $nginx_conf_dir

    if [ ! -f "${bgmi_nginx_conf}" ]; then
        if [ -z ${BGMI_VERSION} ]; then
            export NGINX_PARAMETER="
"
        elif [ "${BGMI_VERSION}" == "transmission" ]; then
            export NGINX_PARAMETER="
    location /tr {
        proxy_pass http://127.0.0.1:9091;
    }
"
        elif [ "${BGMI_VERSION}" == "aria2" ]; then
            export NGINX_PARAMETER="
    location /ariang {
        alias /home/bgmi-docker/downloader/aria2/ariang;
    }
"
        fi
    dockerize -no-overwrite -template ${BGMI_HOME}/config/bgmi_nginx.conf.tmpl:${bgmi_nginx_conf}
    fi

    rm -rf /etc/nginx/nginx.conf
    cp ${BGMI_HOME}/config/nginx.conf /etc/nginx/nginx.conf

}

# 设置permission
function __adduser {

    if [[ -z ${PUID} && -z ${PGID} ]]; then
    	WARN "Ignore permission settings. Start with root user"
    	export PUID=0
        export PGID=0
    	groupmod -o -g "$PGID" bgmi 2>&1 | sed "s#^#${Time} WARN    | $0#g" | sed "s#/home/bgmi-docker/entrypoint.sh##g"
    	usermod -o -u "$PUID" bgmi 2>&1 | sed "s#^#${Time} WARN    | $0#g" | sed "s#/home/bgmi-docker/entrypoint.sh##g"
    else
    	groupmod -o -g "$PGID" bgmi 2>&1 | sed "s#^#${Time} INFO    | $0#g" | sed "s#/home/bgmi-docker/entrypoint.sh##g"
    	usermod -o -u "$PUID" bgmi 2>&1 | sed "s#^#${Time} INFO    | $0#g" | sed "s#/home/bgmi-docker/entrypoint.sh##g"
    fi

}

function __supervisord_downloader {

    if [ -z ${BGMI_VERSION} ]; then
    
        dockerize -no-overwrite -template ${BGMI_HOME}/downloader/none/supervisord.ini.tmpl:${BGMI_HOME}/bgmi_supervisord.ini

    elif [ "${BGMI_VERSION}" == "transmission" ]; then

        dockerize -no-overwrite -template ${BGMI_HOME}/downloader/transmission/supervisord.ini.tmpl:${BGMI_HOME}/bgmi_supervisord.ini

        bash ${BGMI_HOME}/downloader/transmission/settings.sh

    elif [ "${BGMI_VERSION}" == "aria2" ]; then

        dockerize -no-overwrite -template ${BGMI_HOME}/downloader/aria2/supervisord.ini.tmpl:${BGMI_HOME}/bgmi_supervisord.ini

        bash ${BGMI_HOME}/downloader/aria2/settings.sh

    else
        echo -e "\033[31m[+] Wrong container version, start with default version\033[0m"
        dockerize -no-overwrite -template ${BGMI_HOME}/downloader/none/supervisord.ini.tmpl:${BGMI_HOME}/bgmi_supervisord.ini
    fi

}

function __bgmi_scripts {

    cp -r ${BGMI_HOME}/scripts/* /usr/local/bin

}

first_lock="${BGMI_HOME}/bgmi_install.lock"
BGMI_HARDLINK_USE=${BGMI_HARDLINK_USE:-true}

function __init_proc {

    touch "${first_lock}"

}

if [ ! -f "${first_lock}" ]; then

    __init_proc

    __mkdir_dir

    __adduser

    __config_bgmi

    if [ "${BGMI_HARDLINK_USE}" == "true" ]; then
        __config_bgmi_hardlink
    fi

    __config_nginx

    __supervisord_downloader

    __bgmi_scripts

fi

chown -R bgmi:bgmi \
    /home/bgmi-docker \
    /home/bgmi \
    /var/lib/nginx \
    /run/nginx \
    /var/log/nginx
chown -R bgmi:bgmi \
    /bgmi
if [[ "$(stat -c '%U' /media)" != "bgmi" ]] || [[ "$(stat -c '%G' /media)" != "bgmi" ]]; then
    chown bgmi:bgmi \
        /media
fi
if [[ "$(stat -c '%U' ${MEDIA_DIR})" != "bgmi" ]] || [[ "$(stat -c '%G' ${MEDIA_DIR})" != "bgmi" ]]; then
    chown bgmi:bgmi \
        ${MEDIA_DIR}
fi
if [[ "$(stat -c '%U' ${DOWNLOAD_DIR})" != "bgmi" ]] || [[ "$(stat -c '%G' ${DOWNLOAD_DIR})" != "bgmi" ]]; then
    chown bgmi:bgmi \
        ${DOWNLOAD_DIR}
fi

cat /home/bgmi-docker/utils/BGmi-Docker.logo
echo "Current crontab is:"
crontab -l

exec dumb-init /usr/bin/supervisord -n -c "${BGMI_HOME}"/bgmi_supervisord.ini
