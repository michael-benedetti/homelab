# CA setup
if [ ! -f secrets/wildcard.bluefootedboobie.com.crt ]; then
  mkdir secrets
  cd secrets
  openssl genrsa -des3 -out root.key 2048
  openssl req -x509 -new -nodes -key root.key -sha256 -days 36500 -subj "/C=US/ST=MD/L=Severna Park/O=Dis/CN=Private Homelab Authority" -out root.crt

  openssl genrsa -out wildcard.bluefootedboobie.com.key 2048
  openssl req -new -out wildcard.bluefootedboobie.com.csr \
  -key wildcard.bluefootedboobie.com.key \
  -config ../config/opensslsan.cnf

  openssl x509 -req -in wildcard.bluefootedboobie.com.csr \
  -CA root.crt \
  -CAkey root.key \
  -CAcreateserial \
  -out wildcard.bluefootedboobie.com.crt \
  -days 36500 \
  -sha256 \
  -extensions v3_req \
  -extfile ../config/opensslsan.cnf

  sudo mkdir /usr/local/share/ca-certificates/homelab
  sudo cp root.crt /usr/local/share/ca-certificates/homelab/homelab.crt
  sudo chmod 644 /usr/local/share/ca-certificates/homelab/homelab.crt
  sudo update-ca-certificates

  cd ..
fi

# k3s install
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --disable traefik --disable servicelb" sh - 
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chmod 600 ~/.kube/config

while kubectl get node | grep NotReady; do echo "Waiting for k3s..."; sleep 1; done

# reconfigure default storageClass
kubectl patch storageClass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl apply -f yaml/default-storageClass.yaml

# metallb install
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl apply -f yaml/metallb-config.yaml

# unifi-controller
echo "Deploying unifi-controller..."
kubectl create namespace unifi
while ! kubectl -n unifi get serviceaccount | grep default; do echo "Waiting for service account to be ready..."; sleep 1; done
kubectl apply -f yaml/unifi-controller/unifi-controller.yaml --namespace=unifi

# heimdall
echo "Deploying heimdall..."
kubectl create namespace heimdall
while ! kubectl -n heimdall get serviceaccount | grep default; do echo "Waiting for service account to be ready..."; sleep 1; done
kubectl apply -f yaml/heimdall/heimdall.yaml --namespace=heimdall

# prometheus/grafana
kubectl create namespace prometheus
while ! kubectl -n prometheus get serviceaccount | grep default; do echo "Waiting for service account to be ready..."; sleep 1; done
echo "Deploying prometheus/grafana..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install -n prometheus kube-prometheus-stack prometheus-community/kube-prometheus-stack
kubectl -n prometheus patch svc "kube-prometheus-stack-grafana" -p '{"spec": {"type": "LoadBalancer", "loadBalancerIP": "192.168.1.19"}}'

# statping
echo "Deploying statping..."
kubectl create namespace statping
while ! kubectl -n statping get serviceaccount | grep default; do echo "Waiting for service account to be ready..."; sleep 1; done
kubectl apply -f yaml/statping/statping.yaml --namespace=statping
while ! kubectl -n statping get pod statping | grep Running; do echo "Waiting for statping container to be running..."; sleep 1; done
kubectl -n statping exec statping -- sh -c "echo 192.168.1.21 gitlab.bluefootedboobie.com >> /etc/hosts"

# gitlab
echo "Deploying GitLab..."
kubectl create namespace gitlab
kubectl -n gitlab create secret tls wildcard-cert --cert=$(pwd)/secrets/wildcard.bluefootedboobie.com.crt --key=$(pwd)/secrets/wildcard.bluefootedboobie.com.key
helm repo add gitlab https://charts.gitlab.io/
helm install gitlab gitlab/gitlab \
  --set global.hosts.domain=bluefootedboobie.com \
  --set certmanager.install=false \
  --set global.ingress.configureCertmanager=false \
  --set global.ingress.tls.secretName=wildcard-cert \
  --set gitlab-runner.install=false \
  -n gitlab
kubectl -n gitlab patch svc "gitlab-nginx-ingress-controller" -p '{"spec": {"loadBalancerIP": "192.168.1.21"}}'

echo "==========================================================================================================="
GL_ROOT_PW=$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode ; echo)
echo "Gitlab root password: $(echo $GL_ROOT_PW)"
echo "Don't forget to import secrets/root.crt to your browser and any other hosts that need to communicate via TLS!!!"

# D3Compare
read -p "Do you want to deploy D3Compare (Y/n) ?" d3_deploy
if [ "$d3_deploy" == "Y" ] || [ "$d3_deploy" == "" ]; then
	echo "Deploying D3Comapre..."
	kubectl create namespace d3compare
	read -p "Enter Blizzard API Client ID: " D3_CLIENT_ID
	read -p "Enter Blizzard API Client Secret: " D3_CLIENT_SECRET
	kubectl -n d3compare create secret generic d3-client-creds --from-literal=D3_CLIENT_ID=$D3_CLIENT_ID --from-literal=D3_CLIENT_SECRET=$D3_CLIENT_SECRET
	kubectl -n d3compare apply -f yaml/d3compare/d3compare.yaml
fi
