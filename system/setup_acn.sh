#!/bin/bash
# vim: ts=4 sw=4 et
source ./lib.bash

function main() {
    setup_ansible_control_node
}

if ! [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    main "${@}"
    exit $?
fi
