Prepare:

-open 2 cli consoles
-login to deployment on both consoles, on console 2 ssh into master-2
-both consoles will show login credentials to OCP, Console 1 will also show PX-Backup credentials
-login to PX-Backup & both OCP instances on Browser

Check:
- Cluster 1: on namespace pxbbq ubuntu-mongodb VM and 3 pxbbq pods are running


- get route to app, open app, Login to app and place an order

- show cluster 2 does not have pxbbq installed


c1cli: storkctl get clusterpair -n kube-system

c1cli: vi /assets/kubevirt/ocp/async-dr.yml
c1cli: kubectl apply -f /assets/kubevirt/ocp/async-dr.yml

c1cli: storkctl get migrations -n kube-system

c1cli: storkctl suspend migrationschedules pxbbq -n kube-system

c2cli:  storkctl activate migrations -n pxbbq

c2ui: show pods / vm in pxbbq namespace coming up

c1cli: DELETE PXBBQ namespace. takes some time

c2ui: show missing route, talk about not having route migrated
c2ui: create route to pxbbq app (service pxbbq-svc)
access app from cluster to via route
login, show existing order, add another one

login to px-backup gui
check if cloud, object target fit
onboard cluster-2
take a backup from pxbbq namespace. use namespace label app=pxbbq

when backup is taken, restore to cluster-1. exclude route
while restore running, switch to cluster1 ui to show everything is empty


Document Ubuntu Fallback
