This template leverages PDS API to register the px-deploy created ec2 k8s cluster to PDS, creates a PDS Postgres deployment and runs spring-petlinic application deployment within the same namespace accessing the Postgres DB.

It also creates a script to delete the Postgres deployment and unregister the cluster from PDS Control plane. (found on master node /px-deploy/scripts-delete/pds-petclinic.sh) 

## contents
.px-deploy/assets/pds-petclinic/

.px-deploy/templates/pds-petclinic.yml

.px-deploy/scripts/pds-petclinic

## getting started
### 1.  Login to PDS 

note your ACCOUNT / TENANT / PROJECT Names (shown at login)
 ![image](./pds_project.png)

create a User API Key
![image](./pds_access_key.png)


### 2. review (and edit) template settings
in `.px-deploy/templates/pds-petclinic.yml`

check PDS_ACCOUNT / PDS_TENANT / PDS_PROJECT

check PDS_ENDPOINT 

if you need to change settings create your own temlplate file and modify. 

template pds-petclinic.yml will be updated regulary and your changes will be lost

### 3. set PDS API Key in defaults.yml
in `.px-deploy/defaults.yml` add the following

```
env:
  PDS_TOKEN: "your_PDS_User_API_Key"
```

### 4. create deployment
`px-deploy create -n nameyourdeployment -t pds-petclinic`

when deployment is finished you should be able to connect to spring-petclinic app using 
http://[external ip]:30333

You can also see the Deployment Target and the Postgres Deployment on PDS

### 4. uninstall

Deletion of pds-petclinic and pds-system deployments will be done by "px-deploy destroy"

## known issues / limitations
This template is currently designed for k8s/EKS/OCP4 clusters being deployed on aws


