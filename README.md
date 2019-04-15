# Ansible tutorial

this repository contains ansible automation

Instructions follow


## Setup

1. Clone this repository to your ansible master node, under your regular user's home folder:
        
        mkdir -p ~/src/github.com/devopsent && cd ~/src/github.com/devopsent && git clone git@github.com:devopsent/ansible-tutorial.git
1. Follow [Ansible Master Setup](system/ANSIBLE_MASTER.md) to the end
1. Prepare the following information:
    * ansible vault password of your choice
    * VCenter Connection details:
        * hostname
        * username
        * password
1. run `./setup.sh`

## After you have finished

1. Ansible is installed in a virtualenv
1. Two encrypted (vault) files exist:
   1. `vault.yml` vCenter credentials

Now, you can:

1. use dynamically obtained inventory to address vCenter VMs from Ansible
1. perform vCenter actions using vmware modules from regular ansible tasks

## Usage

1. running ansible "ad-hoc" command is done as follows:
        
        # this will "ping" hosts in 'ansible' host group
        ansible ansible -m ping
        # this will run ansible module 'setup' on hosts in 'ansible' host group
        ansible ansible -m setup
1. running ansible playbooks as follows:
        
        # this will run playbook 'playbooks/pubkeys.yml'
        ansible-playbook -e vault.yml playbooks/pubkeys.yml

### Notes

The above commands assume specific ansible `inventory` and `remote_user` set up by previous steps
when you want to override them, add `-i <desired inventory> -u <desired remote_user>` after the commands.
Example:
```!bash
ansible -i myinventory -u myuser ansible -m ping
ansible-playbook -i myinventory -u myuser -e vault.yml playbooks/pubkeys.yml

```

