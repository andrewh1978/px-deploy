# Installing the Crunchy Postgres operator to use PX

Create the namespace and install the custom operator with PX set as the storage types.

```
kubectl create namespace pgo
kubectl apply -f /assets/crunchy-postgres/crunchy-operator.yaml
```

Install the PGO client

```
curl https://raw.githubusercontent.com/CrunchyData/postgres-operator/v4.7.0/installers/kubectl/client-setup.sh > client-setup.sh
chmod +x client-setup.sh
./client-setup.sh
```

Export the pgo client values.

```
APISERVER=$(kubectl get service -n pgo --selector=name=postgres-operator  -o jsonpath='{.items[*].spec.clusterIP}')
export PGOUSER="${HOME?}/.pgo/pgo/pgouser"
export PGO_CA_CERT="${HOME?}/.pgo/pgo/client.crt"
export PGO_CLIENT_CERT="${HOME?}/.pgo/pgo/client.crt"
export PGO_CLIENT_KEY="${HOME?}/.pgo/pgo/client.key"
export PGO_APISERVER_URL='https://$APISERVER:8443'
export PGO_NAMESPACE=pgo
```

Create your demo psql cluster

`pgo create cluster -n pgo demo`