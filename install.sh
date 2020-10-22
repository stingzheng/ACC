#!/bin/bash
set -x
apt update

apt install -y jq mesa-opencl-icd ocl-icd-opencl-dev ntpdate ubuntu-drivers-common

ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
ntpdate ntp.aliyun.com


#ulimit -n 1048576
#sed -i "/nofile/d" /etc/security/limits.conf
#echo "* hard nofile 1048576" >> /etc/security/limits.conf
#echo "* soft nofile 1048576" >> /etc/security/limits.conf
#echo "root hard nofile 1048576" >> /etc/security/limits.conf
#echo "root soft nofile 1048576" >> /etc/security/limits.conf

if [ ! -d /ssd  ];then
  mkdir /ssd
fi
if [ ! -d /hdd  ];then
  mkdir /hdd
fi



SWAPSIZE=`swapon --show | awk 'NR==2 {print $3}'`
if [ "$SWAPSIZE" != "120G" ]; then
	OLDSWAPFILE=`swapon --show | awk 'NR==2 {print $1}'`
	NEWSWAPFILE="/swapfile"
	if [ -n "$OLDSWAPFILE" ]; then
		swapoff -v $OLDSWAPFILE
		rm $OLDSWAPFILE
		sed -i "/\\$OLDSWAPFILE/d" /etc/fstab
		NEWSWAPFILE=$OLDSWAPFILE
	fi
	fallocate -l 120GiB $NEWSWAPFILE
	chmod 600 $NEWSWAPFILE
	mkswap $NEWSWAPFILE
	swapon $NEWSWAPFILE
	echo "$NEWSWAPFILE none swap sw 0 0" >> /etc/fstab
	sysctl vm.swappiness=1
	sed -i "/swappiness/d" /etc/sysctl.conf
	echo "vm.swappiness=1" >> /etc/sysctl.conf
fi


function setenv(){
	sed -i "/$1/d" /etc/profile
	echo "export $1=$2" >> /etc/profile
}
setenv LOTUS_PATH /ssd/lotus
setenv LOTUS_STORAGE_PATH /ssd/lotusminer
setenv WORKER_PATH /ssd/lotusworker
setenv FIL_PROOFS_PARAMETER_CACHE /ssd/filecoin-proof-parameters
setenv FIL_PROOFS_SDR_PARENTS_CACHE_SIZE 107374182
setenv RUST_BACKTRACE full
setenv RUST_LOG debug

source /etc/profile


#wget http://proofs.file.cash:8080/ipfs/QmQBk469zScLykUmbcGjMcn92gxS7e22ifnLLkdfSyWadj/intel-filecash-0.7.0-fix.tar.gz
#tar -xvf intel-filecash-0.7.0-fix.tar.gz -C /usr/local/bin/

#wget http://proofs.file.cash:8080/ipfs/QmQBk469zScLykUmbcGjMcn92gxS7e22ifnLLkdfSyWadj/amd-filecash-0.7.0-fix.tag.gz
#tar -xvf amd-filecash-0.7.0-fix.tag.gz -C /usr/local/bin/


wget https://gitee.com/bill080307/filecash-deploy/raw/master/service/lotus.service -O /lib/systemd/system/lotus.service
wget https://gitee.com/bill080307/filecash-deploy/raw/master/service/lotus-miner.service -O /lib/systemd/system/lotus-miner.service
systemctl daemon-reload




systemctl enable lotus
systemctl start lotus
sleep 300
lotus sync wait

owner=`lotus wallet default`

echo $owner
echo "http://faucet.testnet.file.cash/"

lotus wallet balance $owner

read -s -n1 -p "please goto http://faucet.testnet.file.cash/ request FIC and press any key to continue ... "
lotus wallet balance $owner


lotus-miner init --owner=$owner --sector-size=4GiB

sed -i "s/\"CanStore\": true/\"CanStore\": false/" ${LOTUS_STORAGE_PATH}/sectorstore.json

systemctl enable lotus-miner
systemctl start lotus-miner
sleep 300
lotus-miner storage attach --init  --store  /hdd/Store01/
