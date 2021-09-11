#!/bin/bash

if [ -e /tmp/runonce ]
then

   touch /tmp/runonce.log
   rm -f /tmp/runonce
   echo "**** installing bind ****" >> /tmp/runonce.log

   yum install -y --cacheonly --disablerepo=* /root/extras/bindRepo/Packages/*.rpm

   echo "**** installing k8s ****" >> /tmp/runonce.log

   yum install -y --cacheonly --disablerepo=* /root/extras/k8sRepo/Packages/*.rpm

   yum remove -y runc

   echo "**** installing containerd ****" >> /tmp/runonce.log
#   yum install -y --cacheonly --disablerepo=* /root/extras/dockerCeRepo/Packages/*.rpm
   yum install -y --cacheonly --disablerepo=* /root/extras/dockerCeCliRepo/Packages/*.rpm
#   yum remove -y runc
   yum install -y --cacheonly --disablerepo=* /root/extras/containerdRepo/Packages/*.rpm
   
   echo "**** configuring containerd ****" >> /tmp/runonce.log

   cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
   overlay
   br_netfilter
EOF

   sudo modprobe overlay
   sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
   cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
   net.bridge.bridge-nf-call-iptables  = 1
   net.ipv4.ip_forward                 = 1
   net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
   sudo sysctl --system

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# enforce containerd to use same cgroup as k8s
sed -i "/.containerd\.runtimes\.runc\.options/ a \\\t\t\tSystemdCgroup = true" /etc/containerd/config.toml


systemctl enable containerd
systemctl start containerd

echo "***** containerd started *****" >> /tmp/runonce.log

cd /root/extras
tar -xvf /root/extras/containerd-1.5.4-linux-amd64.tar.gz


/root/extras/bin/ctr i import /root/extras/images/apiServer-v1.22.1.tar
/root/extras/bin/ctr i import /root/extras/images/kubeProxy-v1.22.1.tar
/root/extras/bin/ctr i import /root/extras/images/coredns-v1.8.4.tar 
/root/extras/bin/ctr i import /root/extras/images/pause-3.5.tar
/root/extras/bin/ctr i import /root/extras/images/flannel-v0.14.0.tar 
/root/extras/bin/ctr i import /root/extras/images/controllerManager-v1.22.1.tar
/root/extras/bin/ctr i import /root/extras/images/kubeSchedular-v1.22.1.tar
/root/extras/bin/ctr i import /root/extras/images/etcd-3.5.0-0.tar
/root/extras/bin/ctr i import /root/extras/images/timescaledb-latest-pg11.tar

echo "**** images uploaded ****" >> /tmp/runonce.log

systemctl start named

echo "**** DNS component started ****" >> /tmp/runonce.log

sed -i 's/listen-on\ port\ 53/\/\/listen-on\ port\ 53/' /etc/named.conf
sed -i  's/listen-on-v6\ port/\/\/listen-on-v6 port/' /etc/named.conf
sed -i  's/localhost/localhost\;192\.168\.1\.0\/24/g' /etc/named.conf

echo "**** DNS configurations are done****" >> /tmp/runonce.log

cat <<EOF >>  /etc/named.conf
//Forward Zone
zone "aggreko.local" IN { 

           type master;  
           file "aggreko.local.db"; 
           allow-update { none; };  

};

//Reverse Zone
zone "1.168.192.in-addr.arpa" IN { 

             type master;  
             file "192.168.1.db";             
             allow-update { none; };

};
EOF


touch /var/named/aggreko.local.db
cat <<EOF >/var/named/aggreko.local.db
\$TTL 86400
@   IN  SOA     ns1.aggreko.local. root.aggreko.local. (
                                              3           ;Serial
                                              3600        ;Refresh
                                              1800        ;Retry
                                              604800      ;Expire
                                              86400       ;Minimum TTL
)

;Name Server Information
@       IN  NS      ns1.aggreko.local.

;IP address of Name Server
ns1       IN  A       192.168.1.100

;A - Record HostName To Ip Address
www     IN  A       192.168.1.101

;CNAME record
ftp     IN CNAME        www.aggreko.local.
EOF


touch /var/named/192.168.1.db
cat <<EOF >/var/named/192.168.1.db
\$TTL 86400
@   IN  SOA     ns1.aggreko.local. root.aggreko.local. (
                                       3           ;Serial
                                       3600        ;Refresh
                                       1800        ;Retry
                                       604800      ;Expire
                                       86400       ;Minimum TTL
)

;Name Server Information
@         IN      NS         ns1.aggreko.local.

;Reverse lookup for Name Server
100       IN  PTR     ns1.aggreko.local.

;PTR Record IP address to HostName
101      IN  PTR     www.aggreko.local.

EOF



systemctl restart named

echo "**** DNS component restarted ****" >> /tmp/runonce.log

swapoff -a
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

echo "**** setting up K8s via kubeadm tool ****" >> /tmp/runonce.log

nmcli connection up enp0s3

swapoff -a

kubeadm init --pod-network-cidr=10.244.0.0/16 --cri-socket /run/containerd/containerd.sock

echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> ~/.bashrc

source ~/.bashrc

kubectl taint nodes --all node-role.kubernetes.io/master-

kubectl apply -f /root/extras/yamls/kube-flannel.yml
kubectl apply -f /root/extras/yamls/timescaledb.yml

echo "Done !" >> /tmp/runonce.log

 
fi

exit
