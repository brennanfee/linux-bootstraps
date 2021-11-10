#!/usr/bin/env bash
# Author: Brennan Fee
# License: MIT License
# Version: 0.01  2021-11-09
#
# URL to install: bash <(curl -fsSL https://<path tbd>)
#
# TBD
#
# Bash strict mode
# shellcheck disable=SC2154
([[ -n ${ZSH_EVAL_CONTEXT} && ${ZSH_EVAL_CONTEXT} =~ :file$ ]] ||
 [[ -n ${BASH_VERSION} ]] && (return 0 2>/dev/null)) && SOURCED=true || SOURCED=false
if ! ${SOURCED}; then
  set -o errexit # same as set -e
  set -o nounset # same as set -u
  set -o errtrace # same as set -E
  set -o pipefail
  set -o posix
  #set -o xtrace # same as set -x, turn on for debugging

  shopt -s extdebug
  IFS=$(printf '\n\t')
fi
# END Bash scrict mode

### START: Verification Functions

# Fix this, if connection test fails, try and prompt the user for how they wish to connect (usually wifi, so a SSID and password?).
check_network_connection() {
  print_info "Checking network connectivity..."

  XPINGS=$((XPINGS + 1))
  connection_test() {
    ping -q -w 1 -c 1 "$(ip r | grep default | awk 'NR==1 {print $3}')" &>/dev/null && return 1 || return 0
  }

  set +o pipefail
  WIRED_DEV=$(ip link | grep "ens\|eno\|enp" | awk '{print $2}' | sed 's/://' | sed '1!d')
  write_log "Wired device: ${WIRED_DEV}"

  WIRELESS_DEV=$(ip link | grep wlp | awk '{print $2}' | sed 's/://' | sed '1!d')
  write_log "Wireless device: ${WIRELESS_DEV}"
  set -o pipefail

  if connection_test; then
    print_warning "ERROR! Connection not Found."
    print_info "Network Setup"
    local _connection_opts=("Wired Automatic" "Wired Manual" "Wireless" "Skip")
    PS3="Enter your option: "
    # shellcheck disable=SC2034
    select CONNECTION_TYPE in "${_connection_opts[@]}"; do
      case "${REPLY}" in
      1)
        systemctl start "dhcpcd@${WIRED_DEV}.service"
        break
        ;;
      2)
        systemctl stop "dhcpcd@${WIRED_DEV}.service"
        read -rp "IP Address: " IP_ADDR
        read -rp "Submask: " SUBMASK
        read -rp "Gateway: " GATEWAY
        ip link set "${WIRED_DEV}" up
        ip addr add "${IP_ADDR}/${SUBMASK}" dev "${WIRED_DEV}"
        ip route add default via "${GATEWAY}"
        break
        ;;
      3)
        wifi-menu "${WIRELESS_DEV}"
        break
        ;;
      4)
        error_msg "No network setup, exiting."
        break
        ;;
      *)
        invalid_option
        ;;
      esac
    done
    if [[ ${XPINGS} -gt 2 ]]; then
      error_msg "Can't establish connection. exiting..."
    fi
    [[ ${REPLY} -ne 5 ]] && check_network_connection
  else
    print_info "Connection found."
  fi
}

### END: Verification Functions

echo -e "ERROR: This script is not yet implemented."
exit 1
