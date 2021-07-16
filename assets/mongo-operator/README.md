# Installing the Mongo community operator to use PX

First deploy the MongoDB community operator.

`kubectl apply -f /assets/mongo-operator/mongo-operator.yaml`

Check for the operator pod to be running.

`kubectl get pods -n mongo`

Once it's running you can deploy a MongoDB stateful set using the provided manifest.

`kubectl apply -f assets/mongo-operator/mongo-deployment.yaml`

# Populate some data

Connect to one of your MongoDB pods.
`kubectl exec -it -n mongo demo-mongodb-0 -- bash`

Then login using the mongo client.

`mongo -u my-user -p password`

Now use a new database called ships.
`use ships`

Finally populate some data.

```
db.ships.insert({name:'USS Enterprise-D',operator:'Starfleet',type:'Explorer',class:'Galaxy',crew:750,codes:[10,11,12]})
db.ships.insert({name:'USS Prometheus',operator:'Starfleet',class:'Prometheus',crew:4,codes:[1,14,17]})
db.ships.insert({name:'USS Defiant',operator:'Starfleet',class:'Defiant',crew:50,codes:[10,17,19]})
db.ships.insert({name:'IKS Buruk',operator:' Klingon Empire',class:'Warship',crew:40,codes:[100,110,120]})
db.ships.insert({name:'IKS Somraw',operator:' Klingon Empire',class:'Raptor',crew:50,codes:[101,111,120]})
db.ships.insert({name:'Scimitar',operator:'Romulan Star Empire',type:'Warbird',class:'Warbird',crew:25,codes:[201,211,220]})
db.ships.insert({name:'Narada',operator:'Romulan Star Empire',type:'Warbird',class:'Warbird',crew:65,codes:[251,251,220]})
```

Validate that the data is present.

`db.ships.find().pretty()`

Show only the names of the ships.
`db.ships.find({}, {name:true, _id:false})`


