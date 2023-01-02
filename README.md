# k3d-on-docker

## build a k3d cluster on your docker env
```
make
```

## get started
```
export KUBECONFIG=bootstrap/kubeconfig
```
```
kubectl get nodes
```

## links

- argocd - http://localhost:31080
	- username: admin
	- password: [you can see a password on your console]
- traefik dashboard - http://localhost:30180/dashboard/

## verification

### whoami
```
curl -H "Host: whoami.k3d.local" localhost:30080
```

### traefik dashboard
```
kubectl port-forward -n kube-system $(kubectl get pods -n kube-system --selector "app.kubernetes.io/name=traefik" --output=name) 9000:9000
```
```
curl http://127.0.0.1:9000/dashboard/
```

## check dashboard configuration 
```
kubectl get cm -n kube-system traefik -o yaml
```
###
```
kubectl delete pod -n kube-system $(kubectl get pod -n kube-system | grep "^traefik-" | awk '{print $1}')
kubectl port-forward $(kubectl get pod -n kube-system | grep "^traefik-" | awk '{print $1}') -n kube-system 30181:8080
curl localhost:30181
```
### via NodePort
```
curl 172.18.0.2:30180
```

### from host machine
```
curl localhost:30180
curl localhost:30080
curl -H 'Host: traefik-dashboard.k3d.local' localhost:30080
```

