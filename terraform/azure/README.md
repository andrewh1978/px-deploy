### notes on azure terraform implementation

azure_disks option now also needs a disk type

`azure_disks: "Standard_LRS:49 Premium_LRS:50"`

### How to create credentials:

Run in az cli or Cloud Shell on Azure Web Portal

`az account list`

id -> azure_subscription_id

tenant -> azure_tenant_id

`az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/[azure_subscription_id]"`

appId -> azure_client_id

password -> azure_client_secret

### Accept RockyLinux EULA

`az vm image terms accept --urn "erockyenterprisesoftwarefoundationinc1653071250513:rockylinux:free:8.6.0"`


### Azure Option to add CloudDrives:

`-e cloud_drive="type%3DStandard_LRS%2Csize%3D150"`
