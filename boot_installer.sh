
#!/bin/bash
vm_name=""
vm_img_path=""
qcow2_path=""
vm_ip=""
vm_ram=0
img_name=cpi_installer.vdi
vm_priv_ip=""

qemu_img_convert_qcow2_vdi(){
       

        if [ -z $qcow2_path ]; then
		failure_msg "[$LINENO] qcow2 image  missing"
        else
          echo "qcow2 : $qcow2_path"
        fi
        if [ ! -f $qcow2_path ] ; then 
		failure_msg "[$LINENO] qcow2 img can't be found at $qcow2_path"
        fi
        if [ ! -f $vm_img_path/$img_name ]; then 
        echo " creating vdi image from qcow2........ "
        chmod 777 $vm_img_path/$img_name 
	qemu-img convert -f qcow2 $qcow2_path -O vdi $vm_img_path/$img_name
        if [ $? -ne 0 ]; then failure_msg "failed to convert qcow2-->vdi"; else echo "vdi image $vm_img_path/$img_name created"; fi
        fi
        chmod 777 $vm_img_path/$img_name
}
   

usage() { echo "Usage: $0 [-v <string>] [-p <string>] [-i <string>] [-r <integer>]" 1>&2; exit 1; }

#parse cli arguments
cli_parser(){
	while getopts ":v:p:q:i:t:r:" opt; do
		case $opt in 
		v)   #vm name
			if [ $OPTARG = -* ]; then
				((OPTIND--))
				continue
			fi
		vm_name=$OPTARG
		;; 
		p) #vdi image path
			if [ $OPTARG = -* ]; then
				((OPTIND--))
				continue
			fi
		vm_img_path=$OPTARG
		;;
		q) #qcow2 image path
			if [ $OPTARG = -* ]; then
				((OPTIND--))
				continue
			fi
		qcow2_path=$OPTARG
		;;
		i) #ip address
			if [ $OPTARG = -* ]; then
				((OPTIND--))
				continue
			fi
		vm_ip=$OPTARG
		;;
		t) #private ip address
			if [ $OPTARG = -* ]; then
				((OPTIND--))
				continue
			fi
		vm_priv_ip=$OPTARG
		;;
		r) #memory
			if [ $OPTARG = -* ]; then
				((OPTIND--))
				continue
			fi
		vm_ram=$((OPTARG))
		;;
		\?)
			echo "invalid opt"
			exit
		;;
esac
done
}

#dispaly failure message on console
failure_msg() {
	echo " $* : exiting....."
		exit
}

#validate CLI args
input_managr(){
        if [ -z $vm_img_path ]; then
		failure_msg "vm image path missing"
        else
          echo "vm image path : $vm_img_path"
        fi
	if [ ! -f $vm_img_path/$img_name ] ; then 
		failure_msg "[$LINENO] vdi img can't be found at $vm_img_path/$img_name"
	fi
        if [ -z $vm_name ]; then
		failure_msg "[$LINENO] vm name missing"
        else
          echo "vm name : $vm_name"
        fi
        if [ -z $vm_ip ]; then
                 failure_msg "[$LINENO] vm_ip missing"
        else 
          echo "vm ip address : $vm_ip"
        fi
        if [ -z $vm_priv_ip ]; then
                 failure_msg "[$LINENO] vm_priv_ip missing"
        else 
          echo "vm private ip address : $vm_priv_ip"
        fi
        if [ $vm_ram -eq 0 ] ; then
                failure_msg "[$LINENO] vm_ram missing"
        else 
          echo "vm memory : $vm_ram"
        fi
}

#	if [ $? -ne 0 ] ; then  failure_msg "[$LINENO] ip addr flush dev enp0s3"; fi
#	if [ $? -ne 0 ] ; then  failure_msg "[$LINENO] ip addr add dev enp0s3"; else echo "instller ready to use IP addr: '$vm_ip'" ;fi
#assign ip addr on enp0s9
ip_manager() {
	sshpass -p "deploy" ssh -p 2222 -t deploy@localhost -t <<EOF
        if [ -e /etc/sysconfig/network-scripts/ifcfg-enp0s3 ]; then
           sudo rm -f /etc/sysconfig/network-scripts/ifcfg-enp0s3
        fi
        echo "DEVICE=enp0s3" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-enp0s3
        echo "ONBOOT=yes" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-enp0s3
        echo "TYPE=Ethernet" | sudo tee -a  /etc/sysconfig/network-scripts/ifcfg-enp0s3
        echo "IPADDR=$vm_ip" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-enp0s3
        echo "PREFIX=24" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-enp0s3
        sudo ifdown enp0s3
        sudo ifup enp0s3

        if [ -e /etc/sysconfig/network-scripts/ifcfg-enp0s9 ]; then
           sudo rm -f /etc/sysconfig/network-scripts/ifcfg-enp0s9
        fi
        echo "DEVICE=enp0s9" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-enp0s9
        echo "ONBOOT=yes" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-enp0s9
        echo "TYPE=Ethernet" | sudo tee -a  /etc/sysconfig/network-scripts/ifcfg-enp0s9
        echo "IPADDR=$vm_priv_ip" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-enp0s9
        echo "PREFIX=24" | sudo tee -a /etc/sysconfig/network-scripts/ifcfg-enp0s9
        sudo ifdown enp0s9
        sudo ifup enp0s9
        exit
EOF
}

#main function ...everything will be start from here only
main() {
        #call cli_parser to parse cli args
        echo "-----------------------------------------------------------------------------"
        echo "            nTI cONTINUOUS iNTEGRATION sERVER @deploymachine                                    "
        echo "-----------------------------------------------------------------------------"
        cli_parser $*
        qemu_img_convert_qcow2_vdi
        input_managr

        #create vm
	VBoxManage createvm --name $vm_name --ostype "RedHat_64" --register
        if [ $? -ne 0 ]; then 
		failure_msg "[$LINENO] create vm failure"
        fi 
        #@ttach controller 'SATA'
	VBoxManage storagectl  $vm_name --name "SATA Controller" --add sata --controller IntelAHCI
	if [ $? -ne 0 ]; then 
		failure_msg "[$LINENO] storagectl failure" 
	fi 
        #@ttach img path
 	VBoxManage storageattach $vm_name  --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $vm_img_path/$img_name
	if [ $? -ne 0 ] ; then 
		failure_msg "[$LINENO] storageattach failure" 
	fi 
        #config memory
 	VBoxManage modifyvm $vm_name --memory $vm_ram --vram 128
	if [ $? -ne 0 ]; then
		failure_msg "[$LINENO] modifyvm --memory $vm_ram --vram 128" 
	fi 
<<cmt
        #$et nat port forwarding
 	VBoxManage modifyvm $vm_name --natpf1 "host2guest-ssh,tcp,,2222,,22"
	if [ $? -ne 0 ]; then 
		failure_msg "[$LINENO] failed to port forwarding on NAT"
	fi
cmt
        #@create a bridge n/w on eth0
	VBoxManage modifyvm $vm_name --bridgeadapter1 eth0 
	if [ $? -ne 0 ]; then
		failure_msg "[$LINENO] failed on creating bridge adapter on eth0"
	fi
	VBoxManage modifyvm $vm_name --nic1 bridged
	if [ $? -ne 0 ]; then
		failure_msg "[$LINENO] failed on creating bridge adapter on eth0"
	fi

        #@create a host only n/w on nic3 
	VBoxManage modifyvm $vm_name --hostonlyadapter3 vboxnet1
	if [ $? -ne 0 ]; then
		failure_msg "[$LINENO] failed on creating host-only adapter on NIC3"
	fi
	VBoxManage modifyvm $vm_name --nic3 hostonly
	if [ $? -ne 0 ]; then
		failure_msg "[$LINENO] failed on creating host-only adapter on NIC3"
	fi

        #@create a nat nw on nic2
        VBoxManage modifyvm $vm_name --nic2 nat --nictype2 82540EM --cableconnected1 on
	if [ $? -ne 0 ]; then
		failure_msg "[$LINENO] failed on creating nat adapter on NIC2"
	fi
 	VBoxManage modifyvm $vm_name --natpf2 "host2guest-ssh,tcp,,2222,,22"
	if [ $? -ne 0 ]; then
		failure_msg "[$LINENO] failed on creating nat adapter on NIC2"
	fi
 	#VBoxManage startvm $vm_name
 	VBoxManage startvm $vm_name --type headless
	if [ $? -ne 0 ]; then
		failure_msg "[$LINENO] failed to start vm" 
	fi 
	#wait for some time and then assign IP on eth1
<<cmt
        printf "booting.. "
        for i in `seq 1 60`
        do
        printf "."
	sleep 1
        done
        echo ""
cmt
#	vboxmanage hostonlyif ipconfig vboxnet0 --ip 192.168.100.100 --netmask 255.255.255.0
#	vboxmanage controlvm $vm_name nic2 bridged vboxnet0
	#ip_manager 
#	sshpass -p "deploy" ssh -p 2222 -t deploy@localhost -t "sudo ip addr flush dev enp0s3"
#	sleep 1
#	sshpass -p "deploy" ssh -p 2222 -t deploy@localhost -t  "sudo ip addr add $vm_ip dev enp0s3"
#	sshpass -p "deploy" ssh -p 2222 -t deploy@localhost 'bash -s' < ./temp.sh

} 
main $* 
        i=1
        echo "booting  $vm_name ....."
        while [ $i -ne 0 ] ; do
        sshpass -p "deploy" ssh -p 2222 -t deploy@localhost -t "exit" 
        i=$?
        sleep 1
        done

	ip_manager 
	#sshpass -p "deploy" ssh -p 2222 -t deploy@localhost -t "sudo ip addr flush dev enp0s3"

