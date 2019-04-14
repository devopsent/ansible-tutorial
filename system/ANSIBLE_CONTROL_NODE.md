# Ansible Control Node Setup

## Assumptions:

1. CentOS 7.x operating system
1. Login as regular user
1. User can run commands as `root`: `sudo whoami`

## End result:

1. system is set up with required software, including

1. Clone this repository from gitlab under `${HOME}/src/ansible-tutorial`
1. Login as `root` in its root repository and run:
        
        export FULL_NAME="Full Name"
        export EMAIL_ADDR="your@mail.com" 
        cd system
        ./setup_acn.sh

1. Run ansible virtualenv and other installation:
        
        cd ../
        ./setup.sh
