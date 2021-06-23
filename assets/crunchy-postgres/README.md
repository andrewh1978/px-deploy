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
export PGOUSER="${HOME?}/.pgo/pgo/pgouser"
export PGO_CA_CERT="${HOME?}/.pgo/pgo/client.crt"
export PGO_CLIENT_CERT="${HOME?}/.pgo/pgo/client.crt"
export PGO_CLIENT_KEY="${HOME?}/.pgo/pgo/client.key"
export PGO_APISERVER_URL="https://$(kubectl get service -n pgo --selector=name=postgres-operator  -o jsonpath='{.items[*].spec.clusterIP}'):8443"
export PGO_NAMESPACE=pgo
```

Create your demo psql cluster

`pgo create cluster -n pgo demo`

## Connect to the database to populate data.

```
pgo show user -n pgo demo

CLUSTER USERNAME PASSWORD                 EXPIRES STATUS ERROR
------- -------- ------------------------ ------- ------ -----
demo    testuser datalake                 never   ok
```

Get the database port.

```
kubectl -n pgo get svc

NAME                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
demo                         ClusterIP   10.96.218.63    <none>        2022/TCP,**5432**/TCP            59m
demo-backrest-shared-repo    ClusterIP   10.96.75.175    <none>        2022/TCP                     59m
postgres-operator            ClusterIP   10.96.121.246   <none>        8443/TCP,4171/TCP,4150/TCP   71m
```

Connect to the database.

```
PGPASSWORD=datalake psql -h localhost -p 5432 -U testuser demo

psql (13.3)
Type "help" for help.

demo=>
```

## Connect using pgadmin (web console) instead

Deploy the web console
`pgo create pgadmin -n pgo demo`

Now patch the service to be a NodePort so we can access the UI externally.

`kubectl patch svc demo-pgadmin -n pgo --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"}]'`

Now get the URL for the pgadmin dashboard.

`echo http://$(curl --silent http://ipecho.net/plain):$(kubectl get svc -n pgo demo-pgadmin -o jsonpath='{.spec.ports[0].nodePort}')`

Browse to the UL and log in with the user details above.
