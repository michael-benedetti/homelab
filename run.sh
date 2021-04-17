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

# gitlab
echo "Deploying GitLab..."
kubectl create namespace gitlab
helm repo add gitlab https://charts.gitlab.io/
helm install gitlab gitlab/gitlab \
  --set global.hosts.domain=bluefootedboobie.com \
  --set certmanager.install=false \
  --set global.ingress.configureCertmanager=false \
  --set gitlab-runner.install=false \
  -n gitlab
kubectl -n gitlab patch svc "gitlab-nginx-ingress-controller" -p '{"spec": {"loadBalancerIP": "192.168.1.21"}}'
