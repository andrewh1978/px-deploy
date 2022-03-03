# PX-Explorer

PX-Explorer is a view only web interface for Portworx clusters. It shows basic information about the cluster and detailed information about the different STORK Custom Resource Definitions (CRDs) that Portworx propvides for advanced storage, replication and disaster recovery features.

This application is currently only available to Portworx or Pure Storage employees.

## Getting started
To deploy the app, apply the [`px-explorer.yaml`](./px-explorer.yaml) file.

This will create the following:
- A storageclass called px-explorer (based on the `px-db` profile)
- A namespace called px-explorer
- ClusterRoles, CLusterRoleBinding, Roles, RoleBindings to allow PX-Explorer to access Kubernetes objects
- A mysql statefulset `px-explorer-db` for application storage
- The application web server deployment  `px-explorer`
- A service to access the application called `px-explorer`
- Three collectors: `k8s-collector`, `pwx-collector` and `metrics-collector`. These collectors respectively watch for updates on; Kubernetes objects (like pods, pvcs, statefulsets, etc); Portworx objects (like ClusterPair, Migration, etc); Prometheus metrics from the Portworx worker nodes.

## Access the GUI
If you have a LoadBalancer in your Kubernetes cluster, you can access the cluster using the LoadBalancer FQDN or IP address using HTTP at port 80. When you don't have a LoadBalancer in your cluster, you can use the nodePort `31313` with the IP address of any of the nodes. To show the service use:

```
kubectl get svc -n px-explorer px-explorer
```

The default username and password are pureuser/pureuser.

# Known limitations
- Does not yet work on RedHat OpenShift (untested)
- No support for SSL / encryption of the application
- The application is only available to Portworx or Pure Storage employees.
- Read-only access to the cluster
- Single Kubernetes cluster view only

# Suggestions or bugs?
To report any bugs or share suggestions (currently for Portworx/Pure Storage employees only), please request access to the followin private GitHub repository and create an issue:

[https://github.com/rdeenik/px-explorer](https://github.com/rdeenik/px-explorer)
