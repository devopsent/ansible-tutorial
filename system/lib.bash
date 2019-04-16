#!/bin/bash
# vim: ts=4 sw=4 et
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

declare -a docker_pkgs_rm=()
# shellcheck source=resources/packages.removed.bash
source "${SCRIPT_DIR}/resources/packages.removed.bash"
docker_pkgs_rm+=("${current_list[@]}")
declare -a normal_pkgs=()
# shellcheck source=resources/packages.normal.bash
source "${SCRIPT_DIR}/resources/packages.normal.bash"
normal_pkgs+=("${current_list[@]}")
declare -a python_pkgs=()
# shellcheck source=resources/packages.python.bash
source "${SCRIPT_DIR}/resources/packages.python.bash"
python_pkgs+=("${current_list[@]}")
declare -a repo_pkgs=()
# shellcheck source=resources/repo.packages.bash
source "${SCRIPT_DIR}/resources/repo.packages.bash"
repo_pkgs+=("${current_list[@]}")
declare -a repo_files=()
# shellcheck source=resources/repo.files.bash
source "${SCRIPT_DIR}/resources/repo.files.bash"
repo_files+=("${current_list[@]}")
declare -a docker_pkgs=()
# shellcheck source=resources/packages.docker.bash
source "${SCRIPT_DIR}/resources/packages.docker.bash"
docker_pkgs+=("${current_list[@]}")
declare -a softgroups_rm=()
# shellcheck source=resources/groups.removed.bash
source "${SCRIPT_DIR}/resources/groups.removed.bash"
softgroups_rm+=("${current_list[@]}")

docker_users_str="${docker_users:-"${SUDO_USER}"}"
IFS=',' read -r -a docker_users <<< "${docker_users_str}"
FULL_NAME="${FULL_NAME:-"User name"}"
EMAIL_ADDR="${EMAIL_ADDR:-"user@domain.com"}"

function join_by () { local IFS="$1"; shift; echo "$*"; }

function ensure_can_run() {
    local target_user="${1:-"root"}"
    local result="$( sudo -u "${target_user}" whoami)"
    if [[ "${result}" = "${target_user}" ]]; then
        echo "INFO: running as user $( whoami ) and can become ${target_user}"
        return 0
    fi
    echo "FATAL: ${0} running as $( whoami ). Cannot run operations as user ${target_user}"
    exit 1
}

function setup_repos() {
    local \
        repos \
        repo
    repos=("${@}")
    for repo in "${repos[@]}"; do
        if [[ "${repo}" =~ ^http.* ]]; then
            echo "DEBUG: using yum-config-manager, adding ${repo}"
            sudo yum-config-manager --add-repo "${repo}"
            continue
        fi
        echo "DEBUG: using yum, adding ${repo}"
        sudo yum install -y "${repo}"
    done
    yum makecache
}

function pkg_action() {
    local \
        action \
        packages
    action="${1}"
    shift 1
    packages=("${@}")
    if [[ "${#packages[@]}" -eq 0 ]]; then
        echo "WARN: empty packages list"
        return 0
    fi
    echo "INFO: running yum action ${action}"
    sudo yum "${action}" -y "${packages[@]}"
    return $?
}


function uninstall_packages() {
    packages=("${@}")
    pkg_action remove "${packages[@]}"
    return $?
}

function setup_packages() {
    local \
        packages
    packages=("${@}")
    pkg_action install "${packages[@]}"
    return $?
}

function setup_git() {
    local \
        email_addr \
        full_name
    email_addr="${1?cannot continue without email_addr}"
    shift 1 
    full_name="${*}"
    git config --global user.email "${email_addr}"
    if [[ "${#full_name}" -gt 0 ]]; then
        git config --global user.name "${full_name}"
    fi
    git config --global color.ui auto
    git config --global color.branch.current "yellow reverse"
    git config --global color.branch.local yellow
    git config --global color.branch.remote green
    git config --global color.diff.meta yellow bold
    git config --global color.diff.frag magenta bold
    git config --global color.diff.old red bold
    git config --global color.diff.new green bold
    git config --global color.status.added yellow
    git config --global color.status.changed green
    git config --global color.status.untracked cyan
}

function commit_etckeeper() {
    local msg="$*"
    pushd "${PWD}" || { echo "FATAL: failed to pushd of $PWD"; exit 1; }
    cd /etc || { echo "FATAL: failed to chdir to /etc"; exit 1; }
    if ! [[ -d ".git" ]]; then
        echo "INFO: etckeeper not initialized yet"
        sudo etckeeper init
        msg="initial import"
    fi
    sudo git add .
    sudo etckeeper commit -s -m "${msg}"
    popd || { echo "FATAL: failed to get back pushed directory"; exit 1; }
}

function setup_etckeeper() {
    setup_git
}

function setup_docker() {
    uninstall_packages "${docker_pkgs_rm[@]}"
    setup_packages "${docker_pkgs[@]}"
    for docker_user in "${docker_users[@]}"; do
        sudo usermod -aG docker "${docker_user}"
    done
    sudo systemctl enable docker
    sudo systemctl start docker
    commit_etckeeper "post docker install"
    return $?
}

function setup_python() {
    setup_packages "${python_pkgs[@]}"
    return $?
}


function cleanup_software_groups() {
    local -a groups_rm=("${@}")
    sudo yum groups mark convert
    for softgrp in "${groups_rm[@]}"; do 
        sudo yum groupremove -y "${softgrp}"
    done
}

function setup_base() {
    local -a curr_repos
    local -a curr_packages
    ensure_can_run
    curr_repos=()
    curr_repos+=("${repo_pkgs[@]}")
    curr_repos+=("${repo_files[@]}")
    curr_packages=()
    curr_packages+=("${normal_pkgs[@]}")
    cleanup_software_groups "${softgroups_rm[@]}"
    setup_repos "${curr_repos[@]}"
    setup_packages "${curr_packages[@]}"
    setup_git "${EMAIL_ADDR}" "${FULL_NAME}"
    setup_docker
}

function setup_ansible_control_node() {
    setup_base
    setup_packages "${python_pkgs[@]}"
}

