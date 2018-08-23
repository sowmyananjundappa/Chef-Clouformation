#!/bin/bash
yum update all
yum install aws-cli -y
yum install wget -y

chef_server_url=$1

# create downloads directory
if [ ! -d /downloads ]; then
  mkdir /downloads
fi

# download the Chef Automate package
if [ ! -f /downloads/automate-1.8.68-1.el7.x86_64.rpm ]; then
  echo "Downloading the Chef Automate package..."
  wget -nv -P /downloads https://packages.chef.io/files/stable/automate/1.8.68/el/7/automate-1.8.68-1.el7.x86_64.rpm
fi

# install Chef Automate
if [ ! $(which automate-ctl) ]; then

  echo "Installing Chef Automate..."
  rpm -ivh /downloads/automate-1.8.68-1.el7.x86_64.rpm

  # run preflight check
  automate-ctl preflight-check

  #sleep to Automate service to come up
  sleep 120

  # run setup
  automate-ctl setup --license /root/automate.license  --key /etc/delivery/delivery.pem  --server-url  https://$chef_server_url/organizations/orgnizationname --fqdn $(hostname) --enterprise orgnizationname --configure --no-build-node
  automate-ctl reconfigure

  # wait for all services to come online
  echo "Waiting for services..."
  until (curl --insecure -D - https://localhost/api/_status) | grep "200 OK"; do sleep 1m && automate-ctl restart; done
  while (curl --insecure https://localhost/api/_status) | grep "fail"; do sleep 15s; done

  # create an initial user
  echo "Creating chefadmin user..."
  automate-ctl create-user orgnizationname delivery --password password --roles "admin"
fi

echo "Your Chef Automate server is ready!"
