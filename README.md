This Repo has the required files to be added in Centos image to automate the installation of the OS along with Kubekernetes V1.22.1 and a running timescaleDB pod in a running state in an offline environment/machine.

If you are not using the same Centos OS version, the recommended approach to creating Kickstart files is to perform a manual installation on one system first. After the installation completes, all choices made during the installation are saved into a file named anaconda-ks.cfg, located in the /root/ directory on the installed system. You can then copy this file, make any changes you need, and use the resulting configuration file in further installations.

Procedures :

1-	Download the DVD ISO file (CentOS-8.4.2105-x86_64-dvd1.iso).

2-	Login to the server we will customize the ISO image in as root (alternatively you can use sudo in the following commands).

3-	Upload the downloaded ISO file to any location in the server (ensure to have sufficient storage in the server as the Centos ISO image is around 9GB in size). Following I will assume we placed the file in (/tmp).

4-	Mount the Iso file.

a.	Create mount point.
> mkdir -p /mnt/centos

b.	Mount the iso to the mountpoint.
> mount -o loop /tmp/CentOS-8.4.2105-x86_64-dvd1.iso /mnt/centos

c.	Ensure the iso image is mounted.
> df -h

**Filesystem                     Size  Used    Avail   Use%    Mounted on**

/tmp/CentOS-8.4.2105-x86_64-dvd1.iso 9.3G  9.3G     0       100%    /mnt/centos


5-	Create another directory to be the working directory to customize the ISO Image
> mkdir -p /data/custom_iso

6-	Copy everything from the ISO image to the working directory (except the RPM directories).

> rsync -av --progress /mnt/ /data/custom_iso/

7- copy the hidden files as well 

> cp -vf /mnt/.??* /data/custom_iso/

8- create extras drectory under the custom_iso directory

> mkdir /data/custom_iso/extras

9- Add the ks.cfg under /data/custom_iso/ dir.

10- Add the runonce.sh under extras dir.

11- under extras we have to add mutiple directories to hold the binaries required to downloaded ( i.e. RPMs, images ..etc.).

 1. RPMs repo :
 
	a- create containerdRepo/Packages dir under extra directory and add all the required containerd RPMs under it.
		- I get the required RPMs by running following command 
			> yumdownloader --assumeyes --destdir=/data/custom_iso/extras/containerdRepo/Packages --resolve containerd
		- create the repo to be used during the installation :
				> cd /data/custom_iso/extras/containerdRepo/Packages && createrepo -dpo .. .
		  
	b- create k8sRepo/Packages dir under extra directory and add all the required containerd RPMs under it.
		- I get the required RPMs by running following command
			> yumdownloader --assumeyes --destdir=/data/custom_iso/extras/k8sRepo/Packages --resolve yum-utils kubeadm-1.22.1
		- create the repo to be used during the installation :
			> cd /data/custom_iso/extras/containerdRepo/Packages && createrepo -dpo .. .
	
 2. Images :
 
	a- below images required for kubernetes 1.22.1 and flannel as a CNI plugin .. instead you can run the following command to get all the required kuberenets images from any machine has kubeadm instaled. => kubeadm config images list
		kube-apiserver-v1.22.1.tar
		kube-controller-manager-v1.22.1.tar
		kube-scheduler-v1.22.1.tar
		kube-proxy-v1.22.1.tar
		pause:3.5.tar
		flannel-v0.14.0.tar
		etcd:3.5.0-0.tar
		coredns-v1.8.4.tar
		timescaledb-latest-pg11.tar
	
3. the containerd utilities under extras dir (to be able to deal with the conatinerd i.e. ctr tool), the one used in the script is containerd-1.5.4-linux-amd64.tar.gz.

4. Yaml dir: this will have the flannel and timescaledb yml files.

12- change the isolinux/isolinux.cfg comment the existing append command to be as below to froce execute the kickstart file.
```
label linux

  menu label ^Auto Install CentOS Linux 8 with k8s
  
  kernel vmlinuz
\# add below line to point to the kickstart file  
  append initrd=initrd.img inst.repo=cdrom ks=cdrom:/ks.cfg quiet
\#comment below line  
\# append initrd=initrd.img inst.stage2=hd:LABEL=CentOS-8-4-2105-x86_64-dvd quiet
```
13- recreate the iso image.

> cd /data/custom_iso
> mkisofs -o <location of the new iso>/customCentos.iso -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -V "custom CentOS 8 x86_64" -R -J -v -T isolinux/. .
		
