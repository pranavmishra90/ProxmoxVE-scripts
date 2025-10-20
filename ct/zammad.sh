#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/pranavmishra90/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Michel Roegl-Brunner (michelroegl-brunner)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://zammad.com

APP="Zammad"
var_tags="${var_tags:-webserver;ticket-system}"
var_disk="${var_disk:-8}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /opt/zammad ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Stopping Service"
  systemctl stop zammad
  msg_ok "Stopped Service"

  msg_info "Updating ${APP}"
  $STD apt update
  $STD apt-mark hold zammad
  $STD apt -y upgrade
  $STD apt-mark unhold zammad
  $STD apt -y upgrade
  msg_ok "Updated ${APP}"

  msg_info "Starting Service"
  systemctl start zammad
  msg_ok "Updated ${APP} LXC"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}${CL}"
