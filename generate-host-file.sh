#!/usr/bin/env bash
#
# bash generate-host-files.h -m 1 -w 2
#

function usage() {
    echo "Usage: $0 -m <number-of-master-servers> -w <number-of-worker-servers>" 1>&2
    exit 1
}

while getopts ":m:w:" option; do
    case "${option}" in
    m)
        masters=${OPTARG}
        ;;
    w)
        workers=${OPTARG}
        ;;
    *)
        usage
        ;;
    esac
done

if [[ -z ${masters} || -z ${workers} ]]; then
    usage
fi

function trim() {
  awk '{$1=$1};1'
}

HOST_FILE_NAME="hosts.ini"

rm -rf "${HOST_FILE_NAME}"

echo "[masters]" >>"${HOST_FILE_NAME}"
for i in $(seq 1 $masters); do
    master_name="master${i}"

    _ip_addr=$(vagrant ssh -c "ip addr" "${master_name}" 2>/dev/null)
    master_ip=$(echo -n "${_ip_addr}" | grep -E -o "(192.168.56.[0-9]{1,3})/[0-9]{1,2}" | awk -F '/' '{print $1}')
    master_hostname=$(vagrant ssh -c "hostname -f | tr -d '\n'" "${master_name}" 2>/dev/null)
    master_port=$(vagrant ssh-config "${master_name}" 2>/dev/null | grep 'Port' | awk '{print $NF}')

    if [[ ! -z ${master_ip} ]]; then
        line="${master_hostname} ansible_port=${master_port} \
                host__ip_address=${master_ip} \
                ansible_ssh_private_key_file='.vagrant/machines/${master_name}/virtualbox/private_key'"
        echo "${line}" | trim >>"${HOST_FILE_NAME}"
        echo "generated ansible connection for ${master_name}"
    fi
done

echo "" >>"${HOST_FILE_NAME}"
echo "[workers]" >>"${HOST_FILE_NAME}"
for i in $(seq 1 $workers); do
    worker_name="worker${i}"

    _ip_addr=$(vagrant ssh -c "ip addr" "${worker_name}" 2>/dev/null)
    worker_ip=$(echo -n "${_ip_addr}" | grep -E -o "(192.168.56.[0-9]{1,3})/[0-9]{1,2}" | awk -F '/' '{print $1}')
    worker_hostname=$(vagrant ssh -c "hostname -f | tr -d '\n'" "${worker_name}" 2>/dev/null)
    worker_port=$(vagrant ssh-config "${worker_name}" 2>/dev/null | grep 'Port' | awk '{print $NF}')

    if [[ ! -z ${worker_ip} ]]; then
        line="${worker_hostname} ansible_port=${worker_port} \
                host__ip_address=${worker_ip} \
                ansible_ssh_private_key_file='.vagrant/machines/${worker_name}/virtualbox/private_key'"
        echo "${line}" | trim >>"${HOST_FILE_NAME}"
        echo "generated ansible connection for ${worker_name}"
    fi
done


cat << EOF >> "${HOST_FILE_NAME}"

[all:vars]
ansible_host=127.0.0.1
ansible_user=vagrant
ansible_become=yes
EOF
