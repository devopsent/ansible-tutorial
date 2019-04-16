# Ansible Control Node Setup

This folder contains system setup script to prepare a machine to setup Ansible
## Requirements:

1. Supported Operating Systems:
    * CentOS 7.x
1. OS packages installed:
    * CentOS:
        * redhat-lsb-core
1. Login as regular user capable to become `root`

## End result:

1. The system is set up with required software to setup Ansible on this machine

## Setup

1. Clone this repository under `${HOME}/src/ansible-tutorial`
1. Login as `root` in its root repository and run:
        
        export FULL_NAME="Full Name"
        export EMAIL_ADDR="your@mail.com" 
        cd system
        ./setup_acn.sh

1. Run ansible virtualenv and other installation:
        
        cd ../
        ./setup.sh
