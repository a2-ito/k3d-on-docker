# SELinux

echo "#################################################################################"
echo "# Environment Values "
echo "#################################################################################"

MANIFESTS_DIR=/bootstrap/manifests
K3D_VERSION=v5.4.6
ARCHITECTURE=arm64

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
	wget -O /bootstrap/k3d https://github.com/k3d-io/k3d/releases/download/${K3D_VERSION}/k3d-linux-${ARCHITECTURE}
fi
chmod +x /bootstrap/k3d
cp /bootstrap/k3d /usr/local/bin/k3d
sleep 3
k3d cluster create --config /bootstrap/k3d-config.yml
if [ $? -ne 0 ]; then
	echo "##### k3d cluster create failed #####"
	sleep 3
	k3d cluster create --config /bootstrap/k3d-config.yml
fi
k3d kubeconfig get -a > /bootstrap/kubeconfig

echo "#################################################################################"
echo "# Install kubectl (latest)"
echo "#################################################################################"
if [ ! -e "/bootstrap/kubectl" ]; then
	curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
fi
chmod +x /bootstrap/kubectl
cp /bootstrap/kubectl /usr/local/bin/

function configure_traefik_dashboard(){
	echo "#################################################################################"
	echo "# Traefik dashboard configuration"
	echo "#################################################################################"
	echo "## Wait Traefik pod for Running"
	_target_pod=svclb-traefik
	while true
	do
  	_status=`kubectl get pod -n kube-system | grep ${_target_pod} | tail -n1 | awk '{print $3}'`
  	if [ "${_status}" != "Running" ]; then
  		echo current status [${_target_pod}]: ${_status}
  		sleep 5
  	else
    	echo current status [${_target_pod}]: ${_status}
    	break
  	fi
	done
	#kubectl apply -f $MANIFESTS_DIR/traefik-configmap.yaml
	#kubectl apply -f $MANIFESTS_DIR/traefik-ingress-webui-http.yaml
	kubectl apply -f $MANIFESTS_DIR/traefik-dashboard-svc-np.yaml
	kubectl apply -f $MANIFESTS_DIR/traefik-dashboard-svc-cip.yaml
	kubectl apply -f $MANIFESTS_DIR/traefik-dashboard-ingress.yaml

	traefikpod=$(kubectl get pod -n kube-system | grep -e '^traefik' | cut -d' ' -f1)
	kubectl delete pod -n kube-system $traefikpod
}

configure_traefik_dashboard
kubectl apply -f $MANIFESTS_DIR/deploy-whoami.yaml

exit 0

function install_helm(){
	echo "#################################################################################"
	echo "# Install Helm3"
	echo "#################################################################################"
	apk add bash
	curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
	chmod 700 get_helm.sh
	./get_helm.sh
}
install_helm

function install_traefik_v2(){
	echo "#################################################################################"
	echo "# Install Traefik"
	echo "#################################################################################"
	helm repo add traefik https://traefik.github.io/charts
	helm repo update
	kubectl create ns traefik-v2
	helm install --namespace=traefik-v2 traefik traefik/traefik
}
install_traefik_v2



function install_argocd(){
  echo "#################################################################################"
  echo "# Install ArgoCD"
  echo "#################################################################################"
  kubectl create namespace argocd
  # kubectl apply -n argocd -f $MANIFESTS_DIR/infra-argocd-install/install.yaml
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  _target_pod=argocd-server
  while true
  do
    _status=`kubectl get pod -n argocd | grep ${_target_pod} | tail -n1 | awk '{print $3}'`
    if [ "${_status}" != "Running" ]; then
      echo current status [${_target_pod}] : ${_status}
      sleep 5
    else
      echo current status [${_target_pod}] : ${_status}
      break
    fi
  done

  kubectl apply -f $MANIFESTS_DIR/infra-argocd-install/argocd-server-svc-nodeport.yaml
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

  kubectl apply -k $MANIFESTS_DIR/infra-argocd-application/argocd-root/overlays/dev
  kubectl apply -f $MANIFESTS_DIR/infra-argocd-application/argocd-config/application-argocd-config.yaml
}

install_argocd

install_crossplane

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



