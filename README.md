# k3d-on-docker

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

