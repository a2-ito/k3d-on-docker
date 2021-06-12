# SELinux

echo "#################################################################################"
echo "# Environment Values "
echo "#################################################################################"

MANIFESTS_DIR=/bootstrap/manifests

if command -v apt-get >/dev/null; then
  echo "apt-get is used here"
  #apt -d 1 -y install policycoreutils-python
	apt -y update
	apt -y install curl
elif command -v yum >/dev/null; then
  echo "yum is used here"
  yum -d 1 -y install policycoreutils-python
else
  echo "I have no Idea what im doing here"
	apk add curl
fi

#curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --bind-address 0.0.0.0

# audit-log-maxage=30 # days
# audit-log-maxsize=100 # megabytes
#--log /home/vagrant/k3s.log # default: /var/log/message

#curl -sfL https://get.k3s.io | sh -s - \
#curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v0.9.1 sh -

#curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v0.9.1 sh - 
mkdir /var/log/kubernetes

#_ip=`gcloud compute instances list --format='get(networkInterfaces[0].accessConfigs[0].natIP)'`

echo "#################################################################################"
echo "# Install k3d"
echo "#################################################################################"
sleep 1
#curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | sh
if [ ! -e "/bootstrap/k3d" ]; then
	wget -O /bootstrap/k3d https://github.com/rancher/k3d/releases/download/v4.4.4/k3d-linux-amd64
fi
chmod +x /bootstrap/k3d
cp /bootstrap/k3d /usr/local/bin/k3d
k3d cluster create --config /bootstrap/k3d-config.yml
if [ $? -ne 0 ]; then
	echo "##### k3d cluster create failed #####"
	sleep 3
	k3d cluster create \
		--config /bootstrap/k3d-config.yml
fi	
k3d kubeconfig get -a > /bootstrap/kubeconfig

echo "#################################################################################"
echo "# Install kubectl (latest)"
echo "#################################################################################"
if [ ! -e "/bootstrap/kubectl" ]; then
  curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
fi
chmod +x /bootstrap/kubectl
cp /bootstrap/kubectl /usr/local/bin/

echo "#################################################################################"
echo "# Traefik dashboard configuration"
echo "#################################################################################"
echo "## Wait Traefik pod for Running"
while true
do
  _status=`kubectl get pod -n kube-system | grep svclb-traefik | tail -n1 | awk '{print $3}'`
  if [ "${_status}" != "Running" ]; then
    echo current status : ${_status}
    sleep 5
  else
    echo current status : ${_status}
    break
  fi
done
kubectl apply -f $MANIFESTS_DIR/traefik-configmap.yaml
kubectl apply -f $MANIFESTS_DIR/traefik-ingress-webui-http.yaml
kubectl apply -f $MANIFESTS_DIR/traefik-dashboard-svc-nodeport.yaml
kubectl apply -f $MANIFESTS_DIR/traefik-dashboard-svc-clusterip.yaml

traefikpod=$(kubectl get pod -n kube-system | grep -e '^traefik' | cut -d' ' -f1)
kubectl delete pod -n kube-system $traefikpod


kubectl apply -f $MANIFESTS_DIR/deploy-whoami.yaml

echo "#################################################################################"
echo "# Install ArgoCD"
echo "#################################################################################"
kubectl create namespace argocd
kubectl apply -n argocd -f $MANIFESTS_DIR/argocd/install.yaml

echo "#################################################################################"
echo "# Install Helm3"
echo "#################################################################################"
apk add bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

install_crossplane

exit 0

function install_crossplane(){
  echo "#################################################################################"
  echo "# Install crossplane"
  echo "#################################################################################"
  kubectl create namespace crossplane-system
  helm repo add crossplane-stable https://charts.crossplane.io/stable
  helm repo update
  helm install crossplane --namespace crossplane-system crossplane-stable/crossplane --version 1.2.1
  curl -sL https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh | sh
}

kubectl apply -f $MANIFESTS_DIR/traefik-service.yaml
echo "#################################################################################"
echo "# Install Helm"
echo "#################################################################################"
wget https://get.helm.sh/helm-v2.16.1-linux-amd64.tar.gz
tar xzf helm-v2.16.1-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin

kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

sleep 10

helm init --service-account=tiller --upgrade

#wget https://get.helm.sh/helm-v3.0.2-linux-amd64.tar.gz
#curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
#chmod 700 get_helm.sh
#./get_helm.sh

echo "#################################################################################"
echo "# install Brigade"
echo "#################################################################################"
wget -O brig https://github.com/brigadecore/brigade/releases/download/v1.2.1/brig-linux-amd64
chmod +x brig
sudo mv brig /usr/local/bin/

kubectl create namespace brigade
helm repo add brigade https://brigadecore.github.io/charts
helm install -n brigade brigade/brigade --set rbac.enabled=true
#helm install -n brigade brigade/brigade --namespace brigade --set rbac.enabled=true



