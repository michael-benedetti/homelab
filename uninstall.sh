/usr/local/bin/k3s-uninstall.sh
sudo rm -rf /var/lib/rancher/k3s/
#sudo find /var/lib/rancher/k3s -maxdepth 1 ! -name storage ! -name k3s -exec rm -rf {} \;
