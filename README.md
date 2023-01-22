# Kubernetes

## Installation

> `Ansible` and `Vagrant` needs to be pre-installed in the local machine
 
1. `Vagrant` for provisioning the virtual machines
2. `Docker` for the container management
3. `Kubernetes (k8s)` for the container orchestration

|Role|FQDN|IP|OS|RAM|CPU|
|----|----|----|----|----|----|
|Master|kmaster1.example.com|192.168.56.51|CentOS 7|2G|2|
|Worker|kworker1.example.com|192.168.56.81|CentOS 7|2G|2|

## Provision K8s Cluster

Provisioning the VM's using the Vagrant. Update the `Vagrantfile` as following

```sh
MASTER_NODE_COUNT = 1
WORKER_NODE_COUNT = 1
```

Run the following commands to provision VM's and generate `hosts.ini` file

```sh
$ vagrant up
$ bash generate-host-file.sh -m 1 -w 1
```

Provision the machines using the below command

```sh
$ ansible-playbook provision.yml
```

> Below packages were installed on all of the machines:
>
> `kubeadm`: the command to bootstrap the cluster.
> `kubelet`: the component that runs on all of the machines in the cluster and does things like starting pods and containers.
> `kubectl`: the command line util to talk to the cluster.

### On The Master Machine

Restart the `containerd`

Initialize the machine that will run the control plane components which includes etcd (the cluster database) and the API Server. Pull container images:

```sh
$ sudo kubeadm config images pull

[config/images] Pulled registry.k8s.io/kube-apiserver:v1.25.0
[config/images] Pulled registry.k8s.io/kube-controller-manager:v1.25.0
[config/images] Pulled registry.k8s.io/kube-scheduler:v1.25.0
[config/images] Pulled registry.k8s.io/kube-proxy:v1.25.0
[config/images] Pulled registry.k8s.io/pause:3.8
[config/images] Pulled registry.k8s.io/etcd:3.5.4-0
[config/images] Pulled registry.k8s.io/coredns/coredns:v1.9.3
```

Bootstrap the cluster

> `--control-plane-endpoint`: Set the shared endpoint (f.e. loadbalancer) for all control-plane nodes. Can be DNS/IP
> `--pod-network-cidr`: Used to set a Pod network add-on CIDR (depends on the CNI that we will be using)
> `--cri-socket`: Use if have more than one container runtime to set runtime socket path
> `--apiserver-advertise-address`: Set advertise address for this particular control-plane node's API server, needs to be an interface IP address which has active internet access

```sh
$ sudo kubeadm init --apiserver-advertise-address=192.168.56.51 --pod-network-cidr=192.168.0.0/16

....
....
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.56.51:6443 --token jiuo9y.mz2n3acn5j6v4ytz \
	--discovery-token-ca-cert-hash sha256:852531864577184c9d5dd52a941f26c2f8b62cec1997d3444f31e626032fa7e9 
```

Configure `kubectl` commands to run as non-root user, then as a non-root user perform below commands

```sh
[vagrant@master1 ~]$ mkdir -p $HOME/.kube
[vagrant@master1 ~]$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
[vagrant@master1 ~]$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Check cluster status

```sh
$ kubectl cluster-info

Kubernetes control plane is running at https://192.168.56.51:6443
CoreDNS is running at https://192.168.56.51:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

Deploy Calico network and wait until each pod has the `STATUS` of `Running`

```sh
$ kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/tigera-operator.yaml
$ kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/custom-resources.yaml
$ watch kubectl get pods -n calico-system
```

Confirm that all of the pods are running

```sh
$ kubectl get pods --all-namespaces

NAMESPACE          NAME                                          READY   STATUS    RESTARTS   AGE
calico-apiserver   calico-apiserver-67bb6b5d65-r22nq             1/1     Running   0          71s
calico-apiserver   calico-apiserver-67bb6b5d65-xw8r6             1/1     Running   0          71s
calico-system      calico-kube-controllers-5b8957ccd7-77hhc      1/1     Running   0          2m49s
calico-system      calico-node-s4qh5                             1/1     Running   0          2m49s
calico-system      calico-typha-dbb965f86-n2dq2                  1/1     Running   0          2m50s
calico-system      csi-node-driver-xw5nt                         2/2     Running   0          2m49s
kube-system        coredns-6d4b75cb6d-lknmt                      1/1     Running   0          8m18s
kube-system        coredns-6d4b75cb6d-t66xk                      1/1     Running   0          8m18s
kube-system        etcd-master1.example.com                      1/1     Running   0          8m33s
kube-system        kube-apiserver-master1.example.com            1/1     Running   0          8m33s
kube-system        kube-controller-manager-master1.example.com   1/1     Running   0          8m33s
kube-system        kube-proxy-rrkh5                              1/1     Running   0          8m19s
kube-system        kube-scheduler-master1.example.com            1/1     Running   0          8m33s
tigera-operator    tigera-operator-6bb888d6fc-j457m              1/1     Running   0          3m
```

Check the master status and the status should be `Ready` before moving further

```sh
$ kubectl get nodes

NAME                  STATUS   ROLES           AGE   VERSION
master1.example.com   Ready    control-plane   12m   v1.25.0

$ kubectl get nodes -o wide

NAME                  STATUS   ROLES           AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION                CONTAINER-RUNTIME
master1.example.com   Ready    control-plane   9m13s   v1.24.0   192.168.56.51   <none>        CentOS Linux 7 (Core)   3.10.0-1160.76.1.el7.x86_64   containerd://1.6.8
```

Get the cluster join command to join the worker nodes

```sh
$ kubeadm token create --print-join-command

kubeadm join 192.168.56.51:6443 --token 3bnf1c.91vljs1sofy1knsr --discovery-token-ca-cert-hash sha256:1fe4cb0fcb0c8fd7cfeade363d5bd4eda1e6d0970facd7277142029535b90aef 
```

### On The Worker Machines

Join the cluster. Use the output from `kubeadm token create --print-join-command` command in the `Master` step from the master server and run here.

```sh
$ sudo kubeadm join 192.168.56.51:6443 --token 3bnf1c.91vljs1sofy1knsr --discovery-token-ca-cert-hash sha256:1fe4cb0fcb0c8fd7cfeade363d5bd4eda1e6d0970facd7277142029535b90aef
```

Run `kubectl get nodes` on the control-plane (Master) to see this node joined to the cluster

```sh
[vagrant@master1 ~]$ kubectl get nodes

NAME                  STATUS   ROLES           AGE    VERSION
master1.example.com   Ready    control-plane   19m    v1.25.0
worker1.example.com   Ready    <none>          119s   v1.25.0
```

### Verify the cluster (On The Master Machine)

Get Nodes status

```sh
$ kubectl get nodes

NAME                  STATUS   ROLES           AGE    VERSION
master1.example.com   Ready    control-plane   26m    v1.25.0
worker1.example.com   Ready    <none>          9m2s   v1.25.0

$ kubectl get nodes -o wide

NAME                  STATUS   ROLES           AGE     VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION                CONTAINER-RUNTIME
master1.example.com   Ready    control-plane   27m     v1.25.0   192.168.56.51   <none>        CentOS Linux 7 (Core)   3.10.0-1160.76.1.el7.x86_64   containerd://1.6.8
worker1.example.com   Ready    <none>          9m18s   v1.25.0   192.168.56.81   <none>        CentOS Linux 7 (Core)   3.10.0-1160.76.1.el7.x86_64   containerd://1.6.8
```

Get the component status (cs)

```sh
$ kubectl get cs

Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE                         ERROR
controller-manager   Healthy   ok                              
scheduler            Healthy   ok                              
etcd-0               Healthy   {"health":"true","reason":""}   
```

### On The Host Machine

If we plan to run the `kubectl` commands from the host machine then copy the `~/.kube/config` file from the master machine to the host machine

```sh
$ curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
$ sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
$ scp vagrant@master1.example.com:~/.kube/config $HOME/.kube/config
$ kubectl cluster-info
$ kubectl get nodes
```

### Testing

Test deploying `nginx` in the k8s cluster

```sh
$ kubectl create deployment nginx --image nginx
$ kubectl get deployment
$ kubectl expose deploy nginx --port 80 --type NodePort
$ kubectl get service

NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP   10.96.0.1      <none>        443/TCP        14m
nginx        NodePort    10.96.174.96   <none>        80:30000/TCP   4s
```

To browse the `nginx` Web page, use `http://master1.example.com:30000/`

### K8s Dashboard UI

Download the `recommended.yaml` and add the port for the NodePort

```sh
$ wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.6.1/aio/deploy/recommended.yaml

# modify as follows to inlcude the NodePort for the Service
$ vi recommended.yaml

---
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  type: NodePort
  ports:
    - port: 443
      targetPort: 8443
      nodePort: 30001
  selector:
    k8s-app: kubernetes-dashboard
```

Deploy the control panel

```sh
$ kubectl create -f dashboard-ui/recommended.yaml
namespace/kubernetes-dashboard created
serviceaccount/kubernetes-dashboard created
service/kubernetes-dashboard created
secret/kubernetes-dashboard-certs created
secret/kubernetes-dashboard-csrf created
secret/kubernetes-dashboard-key-holder created
configmap/kubernetes-dashboard-settings created
role.rbac.authorization.k8s.io/kubernetes-dashboard created
clusterrole.rbac.authorization.k8s.io/kubernetes-dashboard created
rolebinding.rbac.authorization.k8s.io/kubernetes-dashboard created
clusterrolebinding.rbac.authorization.k8s.io/kubernetes-dashboard created
deployment.apps/kubernetes-dashboard created
service/dashboard-metrics-scraper created
deployment.apps/dashboard-metrics-scraper created

# check the status
$ kubectl get all -n kubernetes-dashboard
NAME                                            READY   STATUS    RESTARTS   AGE
pod/dashboard-metrics-scraper-8c47d4b5d-p569n   1/1     Running   0          43s
pod/kubernetes-dashboard-6c75475678-7w6sm       1/1     Running   0          43s

NAME                                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)         AGE
service/dashboard-metrics-scraper   ClusterIP   10.110.163.77    <none>        8000/TCP        43s
service/kubernetes-dashboard        NodePort    10.100.101.238   <none>        443:30001/TCP   43s

NAME                                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/dashboard-metrics-scraper   1/1     1            1           43s
deployment.apps/kubernetes-dashboard        1/1     1            1           43s

NAME                                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/dashboard-metrics-scraper-8c47d4b5d   1         1         1       43s
replicaset.apps/kubernetes-dashboard-6c75475678       1         1         1       43s

# get the kubernetes-dashboard service and we can see the kubernetes-dashboard service type is NodePort
$ kubectl -n kubernetes-dashboard get svc
NAME                        TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)         AGE
dashboard-metrics-scraper   ClusterIP   10.110.163.77    <none>        8000/TCP        18m
kubernetes-dashboard        NodePort    10.100.101.238   <none>        443:30001/TCP   18m

# check the kubernetes-dashboard service
$ kubectl -n kubernetes-dashboard describe svc kubernetes-dashboard
Name:                     kubernetes-dashboard
Namespace:                kubernetes-dashboard
Labels:                   k8s-app=kubernetes-dashboard
Annotations:              <none>
Selector:                 k8s-app=kubernetes-dashboard
Type:                     NodePort
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.100.101.238
IPs:                      10.100.101.238
Port:                     <unset>  443/TCP
TargetPort:               8443/TCP
NodePort:                 <unset>  30001/TCP
Endpoints:                192.168.102.144:8443
Session Affinity:         None
External Traffic Policy:  Cluster
Events:                   <none>
```

Deploy ServiceAccount for Admin account with ClusterRoleBinding

```sh
$ kubectl create -f dashboard-ui/sa_cluster_admin.yaml

# check the service acccount
$ kubectl get sa -n kubernetes-dashboard
NAME                   SECRETS   AGE
admin-user             0         96s
default                0         42m
kubernetes-dashboard   0         42m

# check the secret for the admin-user
$ kubectl get secret -n kubernetes-dashboard
NAME                              TYPE                                  DATA   AGE
admin-user-secret                 kubernetes.io/service-account-token   3      4s
kubernetes-dashboard-certs        Opaque                                0      40m
kubernetes-dashboard-csrf         Opaque                                1      40m
kubernetes-dashboard-key-holder   Opaque                                2      40m
```

Deploy metrics for the Kubernetes dashboard

```sh
$ kubectl create -f dashboard-ui/components.yaml
```

Get the token to login to the dashboard UI

```sh
$ kubectl describe secret admin-user-secret -n kubernetes-dashboard
```

Access the dashboard UI using `https://worker1.example.com:30001/` and put the token found for the `admin-user-secret`

![UI Dashboard](./images/token-ui-dashboard.png?raw=true "UI Dashboard")
<p align = "center"> UI Dashboard </p>

### Restart K8s cluster

Stopping the nodes

1. Stop the Worker nodes
2. Stop the Master nodes

Starting the nodes

1. Stop the Master nodes
2. Stop the Worker nodes

Check that the cluster has started properly

```sh
$ kubectl get node -o wide
$ kubectl get pods -n kube-system -o wide
```

Read more:

* https://computingforgeeks.com/deploy-kubernetes-cluster-on-ubuntu-with-kubeadm/
* https://projectcalico.docs.tigera.io/getting-started/kubernetes/quickstart
* https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

## Learning Goal

* Essential knowledge on k8s (deployments, services, volumes, claims, service accounts, secrets, helm charts).
* Deploy different cloud-native apps securely on k8s as the underlying platform.
* Deploy and secure apps using Microservices Mesh technologies (Istio). 
* Authentication
  * For human users, OpenID Connect (jwt tokens)
  * For services, mutual TLS using certificates 
* Authorization
  * RBAC approach
* Reverse proxy server as a central secured gateway for the infrastructure.
* CI-CD (Jenkins in k8s) to automate the whole process.
