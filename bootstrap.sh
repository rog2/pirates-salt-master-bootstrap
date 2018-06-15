#!/bin/bash -e

REGION=cn-north-1

CONFIG_PATH=s3://pirates-ops/salt-master/bootstrap/

FORMULA_HOSTNAME=pirates-formula
FORMULA_KEY=s3://pirates-ops/salt-master/keys/git-formula
FORMULA_LOCAL_KEY=/etc/salt/ssh-keys/git-formula

PILLAR_HOSTNAME=pirates-pillar
PILLAR_KEY=s3://pirates-ops/salt-master/keys/git-pillar
PILLAR_LOCAL_KEY=/etc/salt/ssh-keys/git-pillar

if [ "$#" -lt 1 ]; then
  echo "Illegal number of parameters. Need to pass in env parameter as pillar root."
  exit 1
fi
pillar_root=$1
echo pillar_root=$pillar_root

echo Installing python-git...
apt-get install python-git -y

echo Downloading bootstrap config...
aws s3 cp $CONFIG_PATH . --recursive --exclude "bootstrap.sh" --region $REGION

echo Configurating repos...
echo Downloading formula git repo key...
aws s3 cp $FORMULA_KEY $FORMULA_LOCAL_KEY --region $REGION
chmod 600 $FORMULA_LOCAL_KEY

echo Downloading pillar git repo key...
aws s3 cp $PILLAR_KEY $PILLAR_LOCAL_KEY --region $REGION
chmod 600 $PILLAR_LOCAL_KEY

echo Doing ssh configuration...
sed -i "s@__PIRATES_FORMULA_HOSTNAME__@$FORMULA_HOSTNAME@g" ssh-config
sed -i "s@__PIRATES_FORMULA_KEY__@$FORMULA_LOCAL_KEY@g" ssh-config

sed -i "s@__PIRATES_PILLAR_HOSTNAME__@$PILLAR_HOSTNAME@g" ssh-config
sed -i "s@__PIRATES_PILLAR_KEY__@$PILLAR_LOCAL_KEY@g" ssh-config

cat ssh-config >> ~/.ssh/config

echo Configurating salt-master file server...
sed -i "s@__FORMULA_HOSTNAME__@$FORMULA_HOSTNAME@g" fileserver.conf
sed -i "s@__PILLAR_HOSTNAME__@$PILLAR_HOSTNAME@g" fileserver.conf
sed -i "s@__PILLAR_ROOT__@$pillar_root@g" fileserver.conf
cp fileserver.conf /etc/salt/master.d/

echo Adding known hosts...
cat known_hosts >> ~/.ssh/known_hosts

systemctl start salt-master.service
systemctl enable salt-master.service
