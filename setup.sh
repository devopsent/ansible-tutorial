#!/bin/bash
# vim: ts=4 sw=4 et
ve_name="${ve_name:-"ansible-poc"}"
# TODO: on a non default setup (with SCL or more advanced versions of python - adjust accordingly
py_exec="${py_exec:-"$( command -v python2.7 )"}"
vault_passwd_file_default="./vault_password"
cfg_url_default="https://raw.githubusercontent.com/ansible/ansible/devel/examples/ansible.cfg"
vmw_sdk_url_default="https://github.com/vmware/vsphere-automation-sdk-python"
vmw_ansible_inventory_default="inventory.vmware.yml"
ansible_remote_user_default="root"
ansible_remote_user="${ansible_remote_user:-"${ansible_remote_user_default}"}"

function ensure_distribution() {
    local \
        opsys \
        distribution
    opsys="$( uname -s )"
    distribution="$( lsb_release -is )"
    if [[ "${opsys}" = "Darwin" ]]; then
        echo "INFO: on supported operating system ${opsys}"
        return 0
    fi
    case "${distribution}" in
        "CentOS")
            echo "INFO: on supported operating system: ${opsys} distribution: ${distribution}"
        ;;
        *)
            echo "FATAL: unsupported operating system: ${opsys} distribution: ${distribution}"
            exit 1
        ;;
    esac
}

function setup_virtualenv() {
    local \
        ve_name \
        py_exec \
        count
    ve_name="${1?cannot continue without ve_name}"
    py_exec="${2?cannot continue without py_exec}"
    # shellcheck disable=1094
    source "$( command -v virtualenvwrapper.sh )" || {
        echo "FATAL: cannot find virtualenvwrapper.sh, please install package python-virtualenvwrapper";
        exit 1;
    }
    count="$( lsvirtualenv -b | grep -w -c "${ve_name}" || /bin/true )"
    if [[ "${count}" -ne 0 ]]; then
        echo "INFO: virtualenv ${ve_name} already installed"
        return 0
    fi
    echo "DEBUG: ve_name=${ve_name}, py_exec=${py_exec}"
    mkvirtualenv "${ve_name}" -p "${py_exec}"
    workon "${ve_name}"
    return $?
}

function setup_ansible() {
    local ve_name="${1?cannot continue without ve_name}"
    [ -n "${VIRTUAL_ENV}" ] || workon "${ve_name}"
    pip install -r requirements.txt
    return $?
}

function setup_ansible_cfg() {
    local \
        cfg_url \
        cfg \
        inventory \
        remote_user
    cfg_url="${1?cannot continue cfg_url}"
    inventory="${2:-"/etc/ansible/hosts"}"
    remote_user="${3:-"root"}"
    cfg="${cfg_url##*/}"
    cfg_default="default_${cfg}"
    if [[ -r "${cfg}" ]]; then
        echo "INFO: ${cfg} already exists, to re-download - delete it first and re-run"
        return 0
    fi
    echo "INFO: downloading default ${cfg} from github.com"
    wget -O "${cfg_default}" "${cfg_url}"
    cat > "${cfg_url##*/}" << _EOF
[defaults]
roles_path    = roles
host_key_checking = False
vault_password_file=vault_password
remote_user = ${remote_user}
inventory = ${inventory}
log_path = ansible.log

[paramiko_connection]
record_host_keys = True
host_key_auto_add = True

#[inventory]
#enable_plugins = vmware_vm_inventory
#cache = True
#cache_plugin = jsonfile
#cache_connection = ~/.cache/ansible

[privilege_escalation]

_EOF
    return $?
}

function setup_pyvmomi() {
    local \
        vmw_sdk_url \
        local_dir
    vmw_sdk_url="${1?cannot continue without vmw_sdk_url}"
    local_dir="${vmw_sdk_url##*/}"
    local_dir="${local_dir%.*}"
    [ -n "${VIRTUAL_ENV}" ] || workon "${ve_name}"
    echo "INFO: current python: $( command -v python )"
    need_install=3
    if python -c 'from pyVmomi import vim' 2> /dev/null 1> /dev/null; then
        echo "INFO: pyVmomi already installed for this python"
        need_install=$(( need_install - 1 ))
    fi
    if python -c 'from vmware.vapi.lib.connect import get_requests_connector' 2> /dev/null 1> /dev/null; then
        echo "INFO: vcenter stuff is already installed for this python"
        need_install=$(( need_install - 1 ))
    fi
    if python -c 'from vmware.vapi.stdlib.client.factories import StubConfigurationFactory' 2> /dev/null 1> /dev/null; then pushd "${PWD}"
        echo "INFO: vsphere stuff is already installed for this python"
        need_install=$(( need_install - 1 ))
    fi
    if [[ "${need_install}" -eq 0 ]]; then
        echo "DEBUG: no need to install anything"
        return 0
    fi
    pushd "${PWD}"
    cd ../
    echo "INFO: installing ${local_dir}"
    git clone "${vmw_sdk_url}"
    cd "${local_dir}"
    pip install \
        --upgrade \
        --force-reinstall \
        -r requirements.txt \
        --extra-index-url "file://$( realpath "${PWD}")/lib"
    popd
    return $?
}

function setup_ansible_vault_passwd() {
    local ansible_vault_passwd_file="${1?cannot continue without ansible_vault_passwd_file}"
    if [[ -r "${ansible_vault_passwd_file}" ]]; then
        echo "INFO: ansible vault password file already exists: ${ansible_vault_passwd_file}"
        return 0
    fi
    echo "INFO: going to use ansible vault password file name: ${ansible_vault_passwd_file}"
    read -s -p "Please enter ansible vault password:" ansible_vault_password
    echo -n "${ansible_vault_password}" > "${ansible_vault_passwd_file}"
    return $?
}

function setup_ansible_inventory_config() {
    local \
        vcenter_hostname \
        vcenter_username \
        vcenter_password \
        ansible_inventory \
        vault
    ansible_inventory="${1?cannot continue without ansible_inventory}"
    vault="${2:-"vault.yml"}"
    if [[ -r "${ansible_inventory}" ]]; then
        echo "INFO: Ansible inventory ${ansible_inventory} already exists"
        return 0
    fi
    [ -n "${VIRTUAL_ENV}" ] || workon "${ve_name}"
    echo "INFO: Ansible inventory ${ansible_inventory} missing, creating it"
    echo "Please prepare the following information for the next step:"
    echo "  VCenter hostname"
    echo "  VCenter username"
    echo "  VCenter password"
    # shellcheck disable=SC2034
    read -p "Press ENTER when ready" x
    read -p "Please enter VCenter hostname: " vcenter_hostname
    read -p "Please enter VCenter username: " vcenter_username
    read -s -p "Please enter VCenter password: " vcenter_password
    cat > "${ansible_inventory}" << _EOF
# vim: ts=2 sw=2 ft=ansible.yaml
---
plugin: vmware_vm_inventory
strict: False
validate_certs: False
with_tags: True
hostname: '${vcenter_hostname}'
username: '${vcenter_username}'
password: '${vcenter_password}'
_EOF
    ansible-vault encrypt "${ansible_inventory}"
    test "$?" -eq 0 || { echo "FATAL: failed to encrypt ansible dynamic inventory"; exit 1; }
    echo "INFO: created encrypted ansible inventory script ${ansible_inventory}"
    cat > "${vault}" << _EOF2
# vim: ts=2 sw=2 ft=ansible.yaml
---
vcenter_hostname: '${vcenter_hostname}'
vcenter_username: '${vcenter_username}'
vcenter_password: '${vcenter_password}'
_EOF2
    ansible-vault encrypt "${vault}"
    test "$?" -eq 0 || { echo "FATAL: failed to encrypt ansible vault"; exit 1; }
    echo "INFO: created encrypted ansible vault ${vault}"
}


function main() {
    ensure_distribution
    setup_virtualenv "${ve_name}" "${py_exec}"
    #setup_pyvmomi "${vmw_sdk_url_default}"
    setup_ansible "${ve_name}"
    setup_ansible_vault_passwd "${vault_passwd_file_default}"
    setup_ansible_inventory_config "${vmw_ansible_inventory_default}"
    setup_ansible_cfg \
        "${cfg_url_default}" \
        "${vmw_ansible_inventory_default}" \
        "${ansible_remote_user}"
    mkdir -p roles
    mkdir -p playbooks
    mkdir -p group_vars
    return $?
}


if ! [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    main "${@}"
    exit $?
fi
