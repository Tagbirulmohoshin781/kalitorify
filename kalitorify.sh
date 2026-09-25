#!/usr/bin/env bash

################################################################################
#                                                                              #
# kalitorify.sh                                                                #
#                                                                              #
# version: 1.30.0                                                              #
#                                                                              #
# Kali Linux - Transparent proxy through Tor                                   #
#                                                                              #
# Copyright (C) 2015-2022 brainf+ck                                            #
# Copyright (C) 2026 Tagbirulmohoshin781 & contributors                        #
#                                                                              #
# Kalitorify is KISS version of Parrot AnonSurf Module of Parrot OS:           #
# - https://www.parrotsec.org                                                  #
# - https://nest.parrot.sh/packages/tools/anonsurf                             #
#                                                                              #
# GNU GENERAL PUBLIC LICENSE                                                   #
#                                                                              #
# This program is free software: you can redistribute it and/or modify         #
# it under the terms of the GNU General Public License as published by         #
# the Free Software Foundation, either version 3 of the License, or            #
# (at your option) any later version.                                          #
#                                                                              #
# This program is distributed in the hope that it will be useful,              #
# but WITHOUT ANY WARRANTY; without even the implied warranty of               #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                #
# GNU General Public License for more details.                                 #
#                                                                              #
# You should have received a copy of the GNU General Public License            #
# along with this program.  If not, see <http://www.gnu.org/licenses/>.        #
#                                                                              #
################################################################################

## Program information
readonly prog_name="kalitorify"
readonly version="1.30.0"
readonly signature="Copyright (C) 2026 Tagbirulmohoshin781 & contributors"
readonly git_url="https://github.com/Tagbirulmohoshin781/kalitorify"

## Terminal colors setup (safe detection)
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    ncolors=$(tput colors 2>/dev/null || echo 0)
    if [[ -n "${ncolors}" && "${ncolors}" -ge 8 ]]; then
        red="$(tput setaf 1)"
        green="$(tput setaf 2)"
        blue="$(tput setaf 4)"
        yellow="$(tput setaf 3)"
        white="$(tput setaf 7)"
        b="$(tput bold)"
        reset="$(tput sgr0)"
    else
        red="" green="" blue="" yellow="" white="" b="" reset=""
    fi
else
    red="" green="" blue="" yellow="" white="" b="" reset=""
fi

export red green blue yellow white b reset

## Directories
readonly data_dir="/usr/share/kalitorify/data"      # config files
readonly backup_dir="/var/lib/kalitorify/backups"   # backups

## Network settings
readonly trans_port="9040"
readonly dns_port="5353"
readonly virtual_address="10.192.0.0/10"
readonly non_tor="127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"

# State tracking for rollback trap
is_starting=0

## Show program banner
banner() {
    printf "${b}${white}
 _____     _ _ _           _ ___
|  |  |___| |_| |_ ___ ___|_|  _|_ _
|    -| .'| | |  _| . |  _| |  _| | |
|__|__|__,|_|_|_| |___|_| |_|_| |_  |
                                |___| v${version}

=[ Transparent proxy through Tor
=[ Security & Privacy Toolkit
${reset}\\n\\n"
}

## Print an error message and exit with (1)
die() {
    printf "${red}%s${reset}\\n" "[ERROR] $*" >&2
    exit 1
}

## Print warning
warn() {
    printf "${yellow}%s${reset} %s\\n" "[!]" "${*}"
}

## Print information
info() {
    printf "${b}${blue}%s${reset} ${b}%s${reset}\\n" "::" "${@}"
}

## Print OK messages
msg() {
    printf "${b}${green}%s${reset} %s\\n\\n" "[OK]" "${@}"
}

## Check if running with root privileges
check_root() {
    if [[ "${UID}" -ne 0 ]]; then
        die "Please run this program as root! (sudo ${prog_name})"
    fi
}

## Detect Tor system user dynamically without emitting errors
get_tor_uid() {
    local candidate_users=("debian-tor" "tor" "_tor")
    for user in "${candidate_users[@]}"; do
        if id -u "${user}" >/dev/null 2>&1; then
            id -u "${user}"
            return 0
        fi
    done

    # Fallback to checking active tor daemon process UID if available
    local proc_uid
    proc_uid="$(ps -C tor -o uid= 2>/dev/null | head -n1 | tr -d ' ')"
    if [[ -n "${proc_uid}" ]]; then
        echo "${proc_uid}"
        return 0
    fi

    return 1
}

## Display program version and License
print_version() {
    printf "%s\\n" "${prog_name} ${version}"
    printf "%s\\n" "${signature}"
    printf "%s\\n" "License GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>"
    printf "%s\\n" "This is free software: you are free to change and redistribute it."
    printf "%s\\n" "There is NO WARRANTY, to the extent permitted by law."
    exit 0
}

## Configure general settings and backups
setup_general() {
    info "Check program settings and dependencies"

    # Verify dependencies
    local dependencies=('tor' 'curl' 'iptables')
    for package in "${dependencies[@]}"; do
        if ! command -v "${package}" >/dev/null 2>&1; then
            die "'${package}' is not installed! Please run 'sudo apt install ${package}'."
        fi
    done

    # Ensure backup directory exists
    if [[ ! -d "${backup_dir}" ]]; then
        mkdir -p "${backup_dir}" 2>/dev/null || die "Cannot create backup directory '${backup_dir}', run 'sudo make install' first!"
    fi

    # Verify data directory and custom torrc file exist
    if [[ ! -d "${data_dir}" ]]; then
        die "Directory '${data_dir}' does not exist, run 'sudo make install' first!"
    fi

    if [[ ! -f "${data_dir}/torrc" ]]; then
        die "Data file '${data_dir}/torrc' does not exist, run 'sudo make install' first!"
    fi

    # Replace /etc/tor/torrc file safely
    if [[ ! -f /etc/tor/torrc ]]; then
        die "/etc/tor/torrc file does not exist. Check Tor package installation."
    fi

    printf "%s\\n" "Backup and set /etc/tor/torrc"
    if ! cp -f /etc/tor/torrc "${backup_dir}/torrc.backup"; then
        die "Failed to backup '/etc/tor/torrc'"
    fi

    if ! cp -f "${data_dir}/torrc" /etc/tor/torrc; then
        die "Failed to copy new '/etc/tor/torrc'"
    fi

    # Configure DNS settings in /etc/resolv.conf
    printf "%s\\n" "Configure resolv.conf to route DNS queries to Tor DNSPort"

    if [[ -f /etc/resolv.conf ]]; then
        if ! cp -f /etc/resolv.conf "${backup_dir}/resolv.conf.backup"; then
            die "Failed to backup '/etc/resolv.conf'"
        fi
    fi

    # Overwrite / write new nameserver redirecting to local Tor DNS port
    printf "%s\\n" "nameserver 127.0.0.1" > /etc/resolv.conf 2>/dev/null || {
        # If /etc/resolv.conf is a symlink or read-only, handle via temp file
        cat << 'EOF' > /tmp/resolv.conf.tmp
nameserver 127.0.0.1
EOF
        cp -f /tmp/resolv.conf.tmp /etc/resolv.conf
        rm -f /tmp/resolv.conf.tmp
    }

    # Reload systemd daemons if systemd is active
    if command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
        printf "%s\\n" "Reload systemd daemons"
        systemctl --system daemon-reload >/dev/null 2>&1 || true
    fi
}

## iptables settings
#
# Usage: setup_iptables <tor_proxy|default>
setup_iptables() {
    local target_mode="$1"

    case "${target_mode}" in
        tor_proxy)
            printf "%s\\n" "Set iptables transparent proxy rules"

            local tor_uid
            tor_uid="$(get_tor_uid)"
            if [[ -z "${tor_uid}" ]]; then
                die "Could not identify Tor user UID (checked debian-tor, tor, _tor). Is Tor properly installed?"
            fi

            ## Flush current iptables rules
            iptables -F
            iptables -X
            iptables -t nat -F
            iptables -t nat -X
            iptables -P INPUT ACCEPT
            iptables -P FORWARD ACCEPT
            iptables -P OUTPUT ACCEPT

            ## *nat OUTPUT (For local redirection)
            # Redirect .onion addresses
            iptables -t nat -A OUTPUT -d ${virtual_address} -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j REDIRECT --to-ports ${trans_port}

            # Redirect local DNS requests to Tor DNSPort
            iptables -t nat -A OUTPUT -d 127.0.0.1/32 -p udp -m udp --dport 53 -j REDIRECT --to-ports ${dns_port}

            # Don't nat the Tor process, loopback, or private local LAN networks
            iptables -t nat -A OUTPUT -m owner --uid-owner "${tor_uid}" -j RETURN
            iptables -t nat -A OUTPUT -o lo -j RETURN

            for lan in ${non_tor}; do
                iptables -t nat -A OUTPUT -d "${lan}" -j RETURN
            done

            # Redirect all other outbound TCP traffic to Tor TransPort
            iptables -t nat -A OUTPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j REDIRECT --to-ports ${trans_port}

            ## *filter INPUT
            iptables -A INPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT 2>/dev/null || iptables -A INPUT -m state --state ESTABLISHED -j ACCEPT
            iptables -A INPUT -i lo -j ACCEPT
            iptables -A INPUT -j DROP

            ## *filter FORWARD
            iptables -A FORWARD -j DROP

            ## *filter OUTPUT
            # Prevent kernel transproxy packet leaks
            iptables -A OUTPUT -m conntrack --ctstate INVALID -j DROP 2>/dev/null || iptables -A OUTPUT -m state --state INVALID -j DROP
            iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT 2>/dev/null || iptables -A OUTPUT -m state --state ESTABLISHED -j ACCEPT

            # Allow Tor daemon outbound process
            iptables -A OUTPUT -m owner --uid-owner "${tor_uid}" -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -m conntrack --ctstate NEW -j ACCEPT 2>/dev/null || \
                iptables -A OUTPUT -m owner --uid-owner "${tor_uid}" -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -m state --state NEW -j ACCEPT

            # Allow loopback output
            iptables -A OUTPUT -d 127.0.0.1/32 -o lo -j ACCEPT

            # Allow local access to Tor TransPort
            iptables -A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport "${trans_port}" --tcp-flags FIN,SYN,RST,ACK SYN -j ACCEPT

            # Drop everything else
            iptables -A OUTPUT -j DROP

            ## Set default policies to DROP
            iptables -P INPUT DROP
            iptables -P FORWARD DROP
            iptables -P OUTPUT DROP
            ;;

        default)
            printf "%s\\n" "Restore default iptables rules (clearnet)"

            # Flush all iptables rules and reset default ACCEPT policies
            iptables -F
            iptables -X
            iptables -t nat -F
            iptables -t nat -X
            iptables -P INPUT ACCEPT
            iptables -P FORWARD ACCEPT
            iptables -P OUTPUT ACCEPT
            ;;
        *)
            die "Invalid argument to setup_iptables: ${target_mode}"
            ;;
    esac
}

## Check public IP address with timeouts and reliable fallback services
check_ip() {
    info "Check public IP address"

    local url_list=(
        'https://checkip.amazonaws.com'
        'https://icanhazip.com'
        'https://api.ipify.org'
        'https://ifconfig.me/ip'
        'https://ipinfo.io/ip'
    )

    local found_ip=""
    for url in "${url_list[@]}"; do
        local request
        request="$(curl -s --connect-timeout 8 --max-time 12 "${url}" 2>/dev/null | tr -d '[:space:]')"
        # Validate that the response resembles an IPv4 address
        if [[ "${request}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            found_ip="${request}"
            break
        fi
    done

    if [[ -n "${found_ip}" ]]; then
        printf "${b}${green}%s${reset} Public IP: %s\\n" "[*]" "${found_ip}"
    else
        warn "Could not retrieve public IP address from external APIs (check internet connection or Tor circuits)"
    fi
}

## Check status of Tor service and connectivity
check_status() {
    info "Check current status of Tor service"

    if systemctl is-active tor.service >/dev/null 2>&1; then
        msg "Tor service is active"
    else
        die "Tor service is not running! Exit"
    fi

    info "Check Tor network connection"

    local hostport="localhost:9050"
    local is_tor=0

    # First check via the official Tor Project JSON API
    local api_res
    api_res="$(curl --socks5-hostname "${hostport}" -s --connect-timeout 10 --max-time 15 "https://check.torproject.org/api/ip" 2>/dev/null)"
    if echo "${api_res}" | grep -q '"IsTor":true'; then
        is_tor=1
    elif curl --socks5-hostname "${hostport}" -s --connect-timeout 10 --max-time 15 "https://check.torproject.org/" 2>/dev/null | grep -q "Congratulations"; then
        is_tor=1
    fi

    if [[ "${is_tor}" -eq 1 ]]; then
        msg "Your system is configured to use Tor"
    else
        printf "${red}%s${reset}\\n\\n" "Your system is not using Tor!"
        printf "%s\\n" "Try renewing your Tor circuit with '${prog_name} --restart' or verify Tor logs."
        return 1
    fi

    check_ip
    return 0
}

## Cleanup handler for interrupted starts
start_cleanup() {
    if [[ "${is_starting}" -eq 1 ]]; then
        printf "\\n${yellow}%s${reset}\\n" "[!] Start interrupted or failed. Rolling back network settings to clearnet..."
        setup_iptables default
        if [[ -f "${backup_dir}/resolv.conf.backup" ]]; then
            cp -f "${backup_dir}/resolv.conf.backup" /etc/resolv.conf 2>/dev/null || true
        fi
        if [[ -f "${backup_dir}/torrc.backup" ]]; then
            cp -f "${backup_dir}/torrc.backup" /etc/tor/torrc 2>/dev/null || true
        fi
        sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null 2>&1 || true
        sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null 2>&1 || true
        systemctl stop tor.service >/dev/null 2>&1 || true
        die "Aborted. Restored clearnet settings."
    fi
}

## Start transparent proxy through Tor
start() {
    check_root

    # Exit if tor.service is already active
    if systemctl is-active tor.service >/dev/null 2>&1; then
        die "Tor service is already active, stop it first ('sudo ${prog_name} --clearnet')"
    fi

    banner
    sleep 1

    # Register safety trap in case of interrupt or setup failure
    is_starting=1
    trap start_cleanup INT TERM

    setup_general

    printf "\\n"
    info "Starting Transparent Proxy"

    # Disable IPv6 to prevent IPv6 traffic leaks outside Tor
    printf "%s\\n" "Disable IPv6 with sysctl"
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1

    # Start tor.service
    printf "%s\\n" "Start Tor service"
    if ! systemctl start tor.service >/dev/null 2>&1; then
        start_cleanup
        die "Failed to start Tor service! Exit."
    fi

    # Set new iptables rules
    setup_iptables tor_proxy

    # Verify Tor network connectivity
    printf "\\n"
    if ! check_status; then
        start_cleanup
        die "Tor connectivity verification failed. Cleaned up network configuration."
    fi

    # Startup succeeded, clear trap
    is_starting=0
    trap - INT TERM

    printf "\\n${b}${green}%s${reset} %s\\n" \
            "[OK]" "Transparent Proxy activated, your system is under Tor"
}

## Stop transparent proxy and restore clearnet
#
# Resilient: Always resets iptables and DNS even if tor.service was stopped or crashed
stop() {
    check_root

    info "Stopping Transparent Proxy"

    # 1. Reset iptables to default ACCEPT policies
    setup_iptables default

    # 2. Stop tor service if running
    if systemctl is-active tor.service >/dev/null 2>&1; then
        printf "%s\\n" "Stop Tor service"
        systemctl stop tor.service
    else
        warn "Tor service was not running, continuing system network restore..."
    fi

    # 3. Restore DNS configuration
    printf "%s\\n" "Restore default DNS"
    if command -v resolvconf >/dev/null 2>&1; then
        resolvconf -u 2>/dev/null || true
    fi

    if [[ -f "${backup_dir}/resolv.conf.backup" ]]; then
        cp -f "${backup_dir}/resolv.conf.backup" /etc/resolv.conf 2>/dev/null || true
    fi

    # 4. Re-enable IPv6
    printf "%s\\n" "Enable IPv6"
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null 2>&1

    # 5. Restore default torrc
    if [[ -f "${backup_dir}/torrc.backup" ]]; then
        printf "%s\\n" "Restore default /etc/tor/torrc"
        cp -f "${backup_dir}/torrc.backup" /etc/tor/torrc 2>/dev/null || true
    fi

    # Reload systemd daemons
    if command -v systemctl >/dev/null 2>&1 && systemctl is-system-running >/dev/null 2>&1; then
        systemctl --system daemon-reload >/dev/null 2>&1 || true
    fi

    printf "\\n${b}${green}%s${reset} %s\\n" "[-]" "Transparent Proxy stopped. System returned to clearnet."
    exit 0
}

## Restart tor service to renew circuit / exit node
restart() {
    check_root

    if systemctl is-active tor.service >/dev/null 2>&1; then
        info "Requesting new Tor circuit / IP address"

        # Signal Tor to rebuild circuits
        killall -HUP tor 2>/dev/null || systemctl reload tor.service 2>/dev/null || systemctl restart tor.service

        # Allow circuit negotiation
        sleep 2
        check_ip
        exit 0
    else
        die "Tor service is not running! Start it first with '${prog_name} --tor'"
    fi
}

## Show help menu
usage() {
    printf "%s\\n" "${prog_name} ${version}"
    printf "%s\\n" "Kali Linux - Transparent proxy through Tor"
    printf "%s\\n\\n" "${signature}"

    printf "%s\\n\\n" "Usage: sudo ${prog_name} [option]"

    printf "%s\\n\\n" "Options:"
    printf "%s\\n" "  -h, --help       Show this help message and exit"
    printf "%s\\n" "  -t, --tor        Start transparent proxy through Tor"
    printf "%s\\n" "  -c, --clearnet   Reset iptables and return to clearnet navigation"
    printf "%s\\n" "  -s, --status     Check status of Tor service and network settings"
    printf "%s\\n" "  -i, --ipinfo     Display current public IP address"
    printf "%s\\n" "  -r, --restart    Renew Tor circuit and change public IP address"
    printf "%s\\n" "  -v, --version    Display program version and exit"
    printf "\\n"
    printf "%s\\n" "Project URL: ${git_url}"
    printf "%s\\n" "Report bugs: ${git_url}/issues"

    exit 0
}

## Main entrypoint
main() {
    if [[ "$#" -eq 0 ]]; then
        printf "%s\\n" "${prog_name}: Argument required"
        printf "%s\\n" "Try '${prog_name} --help' for more information."
        exit 1
    fi

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -t | --tor)
                start
                ;;
            -c | --clearnet)
                stop
                ;;
            -r | --restart)
                restart
                ;;
            -s | --status)
                check_status
                exit $?
                ;;
            -i | --ipinfo)
                check_ip
                exit 0
                ;;
            -v | --version)
                print_version
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *)
                printf "%s\\n" "${prog_name}: Invalid option '$1'"
                printf "%s\\n" "Try '${prog_name} --help' for more information."
                exit 1
                ;;
        esac
    done
}

# Execute main
main "${@}"
