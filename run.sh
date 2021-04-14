# k3s install
curl -sfL https://get.k3s.io | sh -
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

echo "Waiting for k3s..."
while kubectl get node | grep NotReady; do echo "..."; sleep 1; done

# metallb install
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl apply -f yaml/metallb-config.yaml

# unifi-controller
kubectl apply -f https://raw.githubusercontent.com/michael-benedetti/unifi-controller-k8s/master/namespace.yaml
while ! kubectl -n unifi get serviceaccounts | grep default; do echo "Waiting for default service account..."; sleep 1; done
kubectl apply -f https://raw.githubusercontent.com/michael-benedetti/unifi-controller-k8s/master/pv.yaml
kubectl apply -f https://raw.githubusercontent.com/michael-benedetti/unifi-controller-k8s/master/pod.yaml
kubectl apply -f https://raw.githubusercontent.com/michael-benedetti/unifi-controller-k8s/master/service.yaml
