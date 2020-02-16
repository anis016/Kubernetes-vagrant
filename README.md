# Kubernets Cluster Setup

Machine used: CentOS-7

* Put the correct IP address of each machine in the `hosts.ini` file
* If using windows WSL, then export the `ansible.cfg` config file manually

```bash
export ANSIBLE_CONFIG=$HOME/K8s/ansible.cfg
```
* Run the `ansible-playbook` command

```bash
ansible-playbook playbook.yaml
```
* Setup the Ansible vault as follows

```bash
touch group_vars/all/vault
touch $HOME/.ansible-vault.txt | echo "mypassword" >> $HOME/.ansible-vault.txt 
```
Update the `vault` as follows:

```.env
---

ansible_user: <changeme>        # this local user, <changeme> can connect to the target machines

ansible_become: yes             # run all the tasks in the target machines as root
ansible_ssh_user: root          # target machines user. If not specified Ansible will try to connect with ansible_user as ssh user.
ansible_ssh_pass: <changeme>    # target machines password
```

Then encrypt the vault file
```bash
ansible-vault encrypt group_vars/all/vault
```