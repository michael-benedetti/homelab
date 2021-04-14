# k3s install
curl -sfL https://get.k3s.io | sh -
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

while kubectl get node | grep NotReady; do echo "Waiting for k3s..."; sleep 1; done

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
