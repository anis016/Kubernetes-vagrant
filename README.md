# Kubernets Cluster Setup

Machine used: CentOS-7

1. Put the correct IP address of each machine in the `hosts.ini` file

2. If using windows WSL, then export the `ansible.cfg` config file manually

```bash
export ANSIBLE_CONFIG=$HOME/K8s/ansible.cfg
```

2. Run the `ansible-playbook` command

```bash
ansible-playbook playbook.yaml
```
