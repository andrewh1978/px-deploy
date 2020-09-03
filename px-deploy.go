package main

import (
  "fmt"
  "os"
  "path"
  "regexp"
  "syscall"
  "strconv"
  "time"
  "os/exec"
  "path/filepath"
  "io/ioutil"
  "strings"
  "unicode/utf8"
  "github.com/olekukonko/tablewriter"
  "github.com/imdario/mergo"
  "github.com/go-yaml/yaml"
  "github.com/spf13/cobra"
  "github.com/google/uuid"
)

type Config struct {
  Name string
  Template string
  Cloud string
  Aws_Region string
  Gcp_Region string
  Azure_Region string
  Platform string
  Clusters string
  Nodes string
  K8s_Version string
  Px_Version string
  Stop_After string
  Post_Script string
  Auto_Destroy string
  Aws_Type string
  Aws_Type_Cluster_1_Worker_Nodes string
  Aws_Ebs string
  Gcp_Type string
  Gcp_Disks string
  Gcp_Zone string
  Azure_Type string
  Azure_Disks string
  Scripts []string
  Description string
  Env map[string]string
  Cluster []Config_Cluster
  Aws__Vpc string `yaml:"aws__vpc,omitempty"`
  Aws__Sg string `yaml:"aws__sg,omitempty"`
  Aws__Subnet string `yaml:"aws__subnet,omitempty"`
  Aws__Gw string `yaml:"aws__gw,omitempty"`
  Aws__Routetable string `yaml:"aws__routetable,omitempty"`
  Aws__Ami string `yaml:"aws__ami,omitempty"`
  Gcp__Project string `yaml:"gcp__project,omitempty"`
  Gcp__Key string `yaml:"gcp__key,omitempty"`
  Azure__Group string `yaml:"azure__group,omitempty"`
}

type Config_Cluster struct {
  Id int
  Scripts []string
}

func main() {
  var createName, createPlatform, createClusters, createNodes, createK8sVer, createPxVer, createStopAfter, createAwsType, createAwsTypeCluster1WorkerNodes, createAwsEbs, createGcpType, createGcpDisks, createGcpZone, createAzureType, createAzureDisks, createTemplate, createRegion, createCloud, createEnv, connectName, destroyName, statusName string
  var destroyAll bool
  os.Chdir("/px-deploy/.px-deploy")
  rootCmd := &cobra.Command{Use: "px-deploy"}

  cmdCreate := &cobra.Command {
    Use: "create",
    Short: "Creates a deployment",
    Long: "Creates a deployment",
    Run: func(cmd *cobra.Command, args []string) {
      if (len(args) > 0) { die("Invalid arguments") }
      config := parse_yaml("defaults.yml")
      env := config.Env
      var env_template map[string]string
      if (createTemplate != "") {
        config.Template = createTemplate
        config_template := parse_yaml("templates/" + createTemplate + ".yml")
        env_template = config_template.Env
        mergo.MergeWithOverwrite(&config, config_template)
        mergo.MergeWithOverwrite(&env, env_template)
      }
      if (createName != "") {
        if (!regexp.MustCompile(`^[a-zA-Z0-9_\-\.]+$`).MatchString(createName)) { die("Invalid deployment name '" + createName + "'") }
        if _, err := os.Stat("deployments/" + createName + ".yml"); !os.IsNotExist(err) { die("Deployment '" + createName + "' already exists") }
      } else {
        createName = uuid.New().String()
      }
      config.Name = createName
      if (createCloud != "") {
        if (createCloud != "aws" && createCloud != "gcp" && createCloud != "azure") { die("Cloud must be 'aws', 'gcp' or 'azure' (not '" + createCloud + "')") }
        config.Cloud = createCloud
      }
      if (createRegion != "") {
        if (!regexp.MustCompile(`^[a-zA-Z0-9_\-]+$`).MatchString(createRegion)) { die("Invalid region '" + createRegion + "'") }
        switch(config.Cloud) {
          case "aws": config.Aws_Region = createRegion
          case "gcp": config.Gcp_Region = createRegion
          case "azure": config.Azure_Region = createRegion
          default: die("Bad cloud")
        }
      }
      if (createPlatform != "") {
        if (createPlatform != "k8s" && createPlatform != "k3s" && createPlatform != "dockeree" && createPlatform != "ocp3" && createPlatform != "ocp3c") { die("Invalid platform '" + createPlatform + "'") }
        config.Platform = createPlatform
      }
      if (createClusters != "") {
        if (!regexp.MustCompile(`^[0-9]+$`).MatchString(createClusters)) { die("Invalid number of clusters") }
        config.Clusters = createClusters
      }
      if (createNodes != "") {
        if (!regexp.MustCompile(`^[0-9]+$`).MatchString(createNodes)) { die("Invalid number of nodes") }
        config.Nodes = createNodes
      }
      if (createK8sVer != "") {
        if (!regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+$`).MatchString(createK8sVer)) { die("Invalid Kubernetes version '" + createK8sVer + "'") }
        config.K8s_Version = createK8sVer
      }
      if (createPxVer != "") {
        if (!regexp.MustCompile(`^[0-9\.]+$`).MatchString(createPxVer)) { die("Invalid Portworx version '" + createPxVer + "'") }
        config.Px_Version = createPxVer
      }
      if (createStopAfter != "") {
        if (!regexp.MustCompile(`^[0-9]+$`).MatchString(createStopAfter)) { die("Invalid number of hours") }
        config.Stop_After = createStopAfter
      }
      if (createEnv != "") {
        env_cli := make(map[string]string)
        for _, kv := range strings.Split(createEnv, ",") {
          s := strings.Split(kv, "=")
          env_cli[s[0]] = s[1]
        }
        mergo.MergeWithOverwrite(&env, env_cli)
      }
      config.Env = env
      if (createAwsType != "") {
        if (!regexp.MustCompile(`^[0-9a-z\.]+$`).MatchString(createAwsType)) { die("Invalid AWS type '" + createAwsType + "'") }
        config.Aws_Type = createAwsType
      }
      if (createAwsTypeCluster1WorkerNodes != "") {
        if (!regexp.MustCompile(`^[0-9a-z\.]+$`).MatchString(createAwsTypeCluster1WorkerNodes)) { die("Invalid AWS type '" + createAwsTypeCluster1WorkerNodes + "'") }
        config.Aws_Type_Cluster_1_Worker_Nodes = createAwsTypeCluster1WorkerNodes
      }
      if (createAwsEbs != "") {
        if (!regexp.MustCompile(`^[0-9a-z\ :]+$`).MatchString(createAwsEbs)) { die("Invalid AWS EBS volumes '" + createAwsEbs + "'") }
        config.Aws_Ebs = createAwsEbs
      }
      if (createGcpType != "") {
        if (!regexp.MustCompile(`^[0-9a-z\-]+$`).MatchString(createGcpType)) { die("Invalid GCP type '" + createGcpType + "'") }
        config.Gcp_Type = createGcpType
      }
      if (createGcpDisks != "") {
        if (!regexp.MustCompile(`^[0-9a-z\ :\-]+$`).MatchString(createGcpDisks)) { die("Invalid GCP disks '" + createGcpDisks + "'") }
        config.Gcp_Disks = createGcpDisks
      }
      if (createGcpZone != "") {
        if (createGcpZone != "a" && createGcpZone != "b" && createGcpZone != "c") { die("Invalid GCP zone '" + createGcpZone + "'") }
        config.Gcp_Zone = createGcpZone
      }
      if (createAzureType != "") {
        if (!regexp.MustCompile(`^[0-9a-z\-]+$`).MatchString(createAzureType)) { die("Invalid Azure type '" + createAzureType + "'") }
        config.Azure_Type = createAzureType
      }
      if (createAzureDisks != "") {
        if (!regexp.MustCompile(`^[0-9 ]+$`).MatchString(createAzureDisks)) { die("Invalid Azure disks '" + createAzureDisks + "'") }
        config.Azure_Disks = createAzureDisks
      }
      for _, c := range config.Cluster {
	for _, s := range c.Scripts {
          if _, err := os.Stat("scripts/" + s); os.IsNotExist(err) { die("Script '" + s + "' does not exist") }
          cmd := exec.Command("bash", "-n", "scripts/" + s)
          err := cmd.Run()
          if (err != nil) { die("Script '" + s + "' is not valid Bash") }
        }
      }
      for _, s := range config.Scripts {
        if _, err := os.Stat("scripts/" + s); os.IsNotExist(err) { die("Script '" + s + "' does not exist") }
        cmd := exec.Command("bash", "-n", "scripts/" + s)
        err := cmd.Run()
        if (err != nil) { die("Script '" + s + "' is not valid Bash") }
      }
      if config.Post_Script != "" {
        if _, err := os.Stat("scripts/" + config.Post_Script); os.IsNotExist(err) { die("Postscript '" + config.Post_Script + "' does not exist") }
        cmd := exec.Command("bash", "-n", "scripts/" + config.Post_Script)
        err := cmd.Run()
        if (err != nil) { die("Postscript '" + config.Post_Script + "' is not valid Bash") }
      }
      y, _ := yaml.Marshal(config)
      err := ioutil.WriteFile("deployments/" + createName + ".yml", y, 0644)
      if err != nil { die(err.Error()) }
      if (create_deployment(config) != 0) {
        destroy_deployment(config.Name)
        die("Aborted")
      }
      os.Chdir("/px-deploy/vagrant")
      os.Setenv("deployment", config.Name)
      var provider string
      switch(config.Cloud) {
        case "aws": provider = "aws"
        case "gcp": provider = "google"
        case "azure": provider = "azure"
      }
      fmt.Println("Provisioning VMs...")
      output, err := exec.Command("vagrant", "up", "--provider", provider).CombinedOutput()
      fmt.Println(string(output))
      if err != nil { die(err.Error()) }
      if config.Auto_Destroy == "true" { destroy_deployment(config.Name) }
    },
  }

  cmdDestroy := &cobra.Command {
    Use: "destroy",
    Short: "Destroys a deployment",
    Long: "Destroys a deployment",
    Run: func(cmd *cobra.Command, args []string) {
      if (destroyAll) {
        if (destroyName != "") { die("Specify either -a or -n, not both") }
        filepath.Walk("deployments", func(file string, info os.FileInfo, err error) error {
          if (info.Mode() & os.ModeDir != 0) { return nil }
          config := parse_yaml(file)
          destroy_deployment(config.Name)
          return nil
        })
      } else {
        if (destroyName == "") { die("Must specify deployment to destroy") }
	destroy_deployment(destroyName)
      }
    },
  }

  cmdConnect := &cobra.Command {
    Use: "connect name [ command ]",
    Short: "Connects to a deployment",
    Long: "Connects to the first master node as root, and executes optional command",
    Run: func(cmd *cobra.Command, args []string) {
      config := parse_yaml("deployments/" + connectName + ".yml")
      ip := get_ip(connectName)
      command := ""
      if (len(args) > 0) { command = args[0] }
      syscall.Exec("/usr/bin/ssh", []string{"ssh", "-oLoglevel=ERROR", "-oStrictHostKeyChecking=no","-i","keys/id_rsa." + config.Cloud + "." + config.Name,"root@" + ip, command}, os.Environ())
    },
  }

  cmdList := &cobra.Command {
    Use: "list",
    Short: "Lists available deployments",
    Long: "Lists available deployments",
    Run: func(cmd *cobra.Command, args []string) {
      var data [][]string
      filepath.Walk("deployments", func(file string, info os.FileInfo, err error) error {
        if (info.Mode() & os.ModeDir != 0) { return nil }
        config := parse_yaml(file)
        var region string
        switch(config.Cloud) {
          case "aws": region = config.Aws_Region
          case "gcp": region = config.Gcp_Region
          case "azure": region = config.Azure_Region
          default: die("Bad cloud")
        }
        template := config.Template
        if (template == "") { template = "<None>" }
        data = append(data, []string{config.Name, config.Cloud, region, config.Platform, template, config.Clusters, config.Nodes, info.ModTime().Format(time.RFC3339)})

        return nil
      })
      print_table([]string{"Deployment", "Cloud", "Region", "Platform", "Template", "Clusters", "Nodes", "Created"}, data)
    },
  }

  cmdTemplates := &cobra.Command {
    Use: "templates",
    Short: "Lists available templates",
    Long: "Lists available templates",
    Run: func(cmd *cobra.Command, args []string) {
      var data [][]string
      filepath.Walk("templates", func(file string, info os.FileInfo, err error) error {
        if (info.Mode() & os.ModeDir != 0) { return nil }
        if (path.Ext(file) != ".yml") { return nil }
        config := parse_yaml(file)
        file = path.Base(file)
        file = strings.TrimSuffix(file, ".yml")
        data = append(data, []string{file, config.Description})
        return nil
      })
      print_table([]string{"Name", "Description"}, data)
    },
  }

  cmdStatus := &cobra.Command {
    Use: "status name",
    Short: "Lists master IPs in a deployment",
    Long: "Lists master IPs in a deployment",
    Run: func(cmd *cobra.Command, args []string) {
      config := parse_yaml("deployments/" + statusName + ".yml")
      ip := get_ip(statusName)
      c := `
        masters=$(grep master /etc/hosts | cut -f 2 -d " ")
        for m in $masters; do
          ip=$(sudo ssh -oStrictHostKeyChecking=no $m "curl http://ipinfo.io/ip" 2>/dev/null)
          hostname=$(sudo ssh -oStrictHostKeyChecking=no $m "curl http://ipinfo.io/hostname" 2>/dev/null)
          echo $m $ip $hostname
        done`
      syscall.Exec("/usr/bin/ssh", []string{"ssh", "-q", "-oStrictHostKeyChecking=no", "-i", "keys/id_rsa." + config.Cloud + "." + config.Name, "root@" + ip, c}, []string{})
    },
  }

  cmdCompletion := &cobra.Command {
    Use:   "completion",
    Short: "Generates bash completion scripts",
    Long: `To load completion run

  . <(px-deploy completion)`,
    Run: func(cmd *cobra.Command, args []string) {
      rootCmd.GenBashCompletion(os.Stdout)
    },
  }

  defaults := parse_yaml("defaults.yml")
  cmdCreate.Flags().StringVarP(&createName, "name", "n", "", "name of deployment to be created (if blank, generate UUID)")
  cmdCreate.Flags().StringVarP(&createPlatform, "platform", "p", "", "k8s | dockeree | k3s | ocp3 | ocp3c (default " + defaults.Platform + ")")
  cmdCreate.Flags().StringVarP(&createClusters, "clusters", "c", "", "number of clusters to be deployed (default " + defaults.Clusters + ")")
  cmdCreate.Flags().StringVarP(&createNodes, "nodes", "N", "", "number of nodes to be deployed in each cluster (default " + defaults.Nodes + ")")
  cmdCreate.Flags().StringVarP(&createK8sVer, "k8s_version", "k", "", "Kubernetes version to be deployed (default " + defaults.K8s_Version + ")")
  cmdCreate.Flags().StringVarP(&createPxVer, "px_version", "P", "", "Portworx version to be deployed (default " + defaults.Px_Version + ")")
  cmdCreate.Flags().StringVarP(&createStopAfter, "stop_after", "s", "", "Stop instances after this many hours (default " + defaults.Stop_After + ")")
  cmdCreate.Flags().StringVarP(&createAwsType, "aws_type", "", "", "AWS type for each node (default " + defaults.Aws_Type + ")")
  cmdCreate.Flags().StringVarP(&createAwsTypeCluster1WorkerNodes, "Aws_Type_Cluster_1_Worker_Nodes", "", "", "AWS type for each node of first cluster (default " + defaults.Aws_Type + ")")
  cmdCreate.Flags().StringVarP(&createAwsEbs, "aws_ebs", "", "", "space-separated list of EBS volumes to be attached to worker nodes, eg \"gp2:20 standard:30\" (default " + defaults.Aws_Ebs + ")")
  cmdCreate.Flags().StringVarP(&createGcpType, "gcp_type", "", "", "GCP type for each node (default " + defaults.Gcp_Type + ")")
  cmdCreate.Flags().StringVarP(&createGcpDisks, "gcp_disks", "", "", "space-separated list of EBS volumes to be attached to worker nodes, eg \"pd-standard:20 pd-ssd:30\" (default " + defaults.Gcp_Disks + ")")
  cmdCreate.Flags().StringVarP(&createGcpZone, "gcp_zone", "", defaults.Gcp_Zone, "GCP zone (a, b or c)")
  cmdCreate.Flags().StringVarP(&createAzureType, "azure_type", "", "", "Azure type for each node (default " + defaults.Azure_Type + ")")
  cmdCreate.Flags().StringVarP(&createAzureDisks, "azure_disks", "", "", "space-separated list of Azure disks to be attached to worker nodes, eg \"20 30\" (default " + defaults.Azure_Disks + ")")
  cmdCreate.Flags().StringVarP(&createTemplate, "template", "t", "", "name of template to be deployed")
  cmdCreate.Flags().StringVarP(&createRegion, "region", "r", "", "AWS, GCP or Azure region (default " + defaults.Aws_Region + ", " + defaults.Gcp_Region + " or " + defaults.Azure_Region + ")")
  cmdCreate.Flags().StringVarP(&createCloud, "cloud", "C", "", "aws, gcp or azure (default " + defaults.Cloud + ")")
  cmdCreate.Flags().StringVarP(&createEnv, "env", "e", "", "Comma-separated list of environment variables to be passed, for example foo=bar,abc=123")

  cmdDestroy.Flags().BoolVarP(&destroyAll, "all", "a", false, "destroy all deployments")
  cmdDestroy.Flags().StringVarP(&destroyName, "name", "n", "", "name of deployment to be destroyed")

  cmdConnect.Flags().StringVarP(&connectName, "name", "n", "", "name of deployment to connect to")
  cmdConnect.MarkFlagRequired("name")

  cmdStatus.Flags().StringVarP(&statusName, "name", "n", "", "name of deployment")
  cmdStatus.MarkFlagRequired("name")

  rootCmd.AddCommand(cmdCreate, cmdDestroy, cmdConnect, cmdList, cmdTemplates, cmdStatus, cmdCompletion)
  rootCmd.Execute()
}

func create_deployment(config Config) int {
  var output []byte
  var err error
  fmt.Println("Provisioning infrastructure...")
  switch(config.Cloud) {
    case "aws": {
      output, err = exec.Command("bash", "-c", `
        aws configure set default.region ` + config.Aws_Region + `
        yes | ssh-keygen -q -t rsa -b 2048 -f keys/id_rsa.aws.` + config.Name + ` -N ''
        aws ec2 describe-instance-types --instance-types ` + config.Aws_Type + `>&/dev/null
        [ $? -ne 0 ] && echo "Invalid AWS type '` + config.Aws_Type + `' for region '` + config.Aws_Region + `'" && exit 1
        aws ec2 describe-instance-types --instance-types ` + config.Aws_Type_Cluster_1_Worker_Nodes + `>&/dev/null
        [ $? -ne 0 ] && echo "Invalid AWS type '` + config.Aws_Type_Cluster_1_Worker_Nodes + `' for region '` + config.Aws_Region + `'" && exit 1
        aws ec2 delete-key-pair --key-name px-deploy.` + config.Name + ` >&/dev/null
        aws ec2 import-key-pair --key-name px-deploy.` + config.Name + ` --public-key-material file://keys/id_rsa.aws.` + config.Name + `.pub >&/dev/null
        _AWS_vpc=$(aws --output text ec2 create-vpc --cidr-block 192.168.0.0/16 --query Vpc.VpcId)
        _AWS_subnet=$(aws --output text ec2 create-subnet --vpc-id $_AWS_vpc --cidr-block 192.168.0.0/16 --query Subnet.SubnetId)
        _AWS_gw=$(aws --output text ec2 create-internet-gateway --query InternetGateway.InternetGatewayId)
        aws ec2 attach-internet-gateway --vpc-id $_AWS_vpc --internet-gateway-id $_AWS_gw
        _AWS_routetable=$(aws --output text ec2 create-route-table --vpc-id $_AWS_vpc --query RouteTable.RouteTableId)
        aws ec2 create-route --route-table-id $_AWS_routetable --destination-cidr-block 0.0.0.0/0 --gateway-id $_AWS_gw >/dev/null
        aws ec2 associate-route-table  --subnet-id $_AWS_subnet --route-table-id $_AWS_routetable >/dev/null
        _AWS_sg=$(aws --output text ec2 create-security-group --group-name px-deploy --description "Security group for px-deploy" --vpc-id $_AWS_vpc --query GroupId)
        aws ec2 authorize-security-group-ingress --group-id $_AWS_sg --protocol tcp --port 22 --cidr 0.0.0.0/0 &
        aws ec2 authorize-security-group-ingress --group-id $_AWS_sg --protocol tcp --port 80 --cidr 0.0.0.0/0 &
        aws ec2 authorize-security-group-ingress --group-id $_AWS_sg --protocol tcp --port 443 --cidr 0.0.0.0/0 &
        aws ec2 authorize-security-group-ingress --group-id $_AWS_sg --protocol tcp --port 5900 --cidr 0.0.0.0/0 &
        aws ec2 authorize-security-group-ingress --group-id $_AWS_sg --protocol tcp --port 8080 --cidr 0.0.0.0/0 &
        aws ec2 authorize-security-group-ingress --group-id $_AWS_sg --protocol tcp --port 8443 --cidr 0.0.0.0/0 &
        aws ec2 authorize-security-group-ingress --group-id $_AWS_sg --protocol tcp --port 30000-32767 --cidr 0.0.0.0/0 &
        aws ec2 authorize-security-group-ingress --group-id $_AWS_sg --protocol all --cidr 192.168.0.0/16 &
        aws ec2 create-tags --resources $_AWS_vpc $_AWS_subnet $_AWS_gw $_AWS_routetable $_AWS_sg --tags Key=px-deploy_name,Value=` + config.Name + ` &
        aws ec2 create-tags --resources $_AWS_vpc --tags Key=Name,Value=px-deploy.` + config.Name + ` &
        _AWS_ami=$(aws --output text ec2 describe-images --owners 679593333241 --filters Name=name,Values='CentOS Linux 7 x86_64 HVM EBS*' Name=architecture,Values=x86_64 Name=root-device-type,Values=ebs --query 'sort_by(Images, &Name)[-1].ImageId')
        wait
        echo aws__vpc: $_AWS_vpc >>deployments/` + config.Name + `.yml
        echo aws__sg: $_AWS_sg >>deployments/` + config.Name + `.yml
        echo aws__subnet: $_AWS_subnet >>deployments/` + config.Name + `.yml
        echo aws__gw: $_AWS_gw >>deployments/` + config.Name + `.yml
        echo aws__routetable: $_AWS_routetable >>deployments/` + config.Name + `.yml
        echo aws__ami: $_AWS_ami >>deployments/` + config.Name + `.yml
      `).CombinedOutput()
    }
    case "gcp": {
      output, _ = exec.Command("bash", "-c", `
        yes | ssh-keygen -q -t rsa -b 2048 -f keys/id_rsa.gcp.` + config.Name + ` -N ''
        _GCP_project=pxd-$(uuidgen | tr -d -- - | cut -b 1-26 | tr 'A-Z' 'a-z')
        gcloud projects create $_GCP_project --labels px-deploy_name=` + config.Name + `
        account=$(gcloud alpha billing accounts list | tail -1 | cut -f 1 -d " ")
        gcloud alpha billing projects link $_GCP_project --billing-account $account
        gcloud services enable compute.googleapis.com --project $_GCP_project
        gcloud compute networks create px-net --project $_GCP_project
        gcloud compute networks subnets create --range 192.168.0.0/16 --network px-net px-subnet --region ` + config.Gcp_Region + ` --project $_GCP_project
        gcloud compute firewall-rules create allow-internal --allow=tcp,udp,icmp --source-ranges=192.168.0.0/16 --network px-net --project $_GCP_project &
        gcloud compute firewall-rules create allow-external --allow=tcp:22,tcp:80,tcp:443,tcp:6443,tcp:5900 --network px-net --project $_GCP_project &
        gcloud compute project-info add-metadata --metadata "ssh-keys=centos:$(cat keys/id_rsa.gcp.` + config.Name + `.pub)" --project $_GCP_project &
        service_account=$(gcloud iam service-accounts list --project $_GCP_project --format 'flattened(email)' | tail -1 | cut -f 2 -d " ")
        _GCP_key=$(gcloud iam service-accounts keys create /dev/stdout --iam-account $service_account | base64 -w0)
        wait
        echo gcp__project: $_GCP_project >>deployments/` + config.Name + `.yml
        echo gcp__key: $_GCP_key >>deployments/` + config.Name + `.yml
      `).CombinedOutput()
    }
    case "azure": {
      output, _ = exec.Command("bash", "-c", `
        az configure --defaults location=` + config.Azure_Region + `
        yes | ssh-keygen -q -t rsa -b 2048 -f keys/id_rsa.azure.` + config.Name + ` -N ''
	_AZURE_group=pxd-$(uuidgen)
	az group create -g $_AZURE_group --output none
	az network vnet create --name $_AZURE_group --resource-group $_AZURE_group --address-prefix 192.168.0.0/16 --subnet-name $_AZURE_group --subnet-prefixes 192.168.0.0/16 --output none
	az network private-dns zone create -g $_AZURE_group -n $_AZURE_group.pxd --output none
	az network private-dns link vnet create -g $_AZURE_group -n $_AZURE_group -z $_AZURE_group.pxd -v $_AZURE_group -e true --output none
	_AZURE_subscription=$(az account show --query id --output tsv)
	echo $(az ad sp create-for-rbac -n $_AZURE_group --query "[appId,password,tenant]" --output tsv 2>/dev/null) | while read _AZURE_client _AZURE_secret _AZURE_tenant ; do
	  echo azure__client: $_AZURE_client
	  echo azure__secret: $_AZURE_secret
	  echo azure__tenant: $_AZURE_tenant
	  echo azure__subscription: $_AZURE_subscription
	done >>deployments/` + config.Name + `.yml
        echo azure__group: $_AZURE_group >>deployments/` + config.Name + `.yml
      `).CombinedOutput()
    }
    default: die("Invalid cloud '"+ config.Cloud + "'")
  }
  fmt.Print(string(output))
  if err != nil { return 1 }
  return 0
}

func destroy_deployment(name string) {
  os.Chdir("/px-deploy/.px-deploy")
  config := parse_yaml("deployments/" + name + ".yml")
  var output []byte
  ip := get_ip(config.Name)
  fmt.Println("Destroying deployment '" + config.Name + "'...")
  if (config.Cloud == "aws") {
    c, _ := strconv.Atoi(config.Clusters)
    n, _ := strconv.Atoi(config.Nodes)
    if (c < 3 && n < 5) {
      _ = exec.Command("/usr/bin/ssh", "-oStrictHostKeyChecking=no", "-i", "keys/id_rsa." + config.Cloud + "." + config.Name, "root@" + ip, `
        for i in $(tail -n +3 /etc/hosts | cut -f 1 -d " "); do
          ssh $i poweroff --force --force &
        done
        wait
        poweroff --force --force
        done
      `).Start()
      time.Sleep(5 * time.Second)
    }
    output, _ = exec.Command("bash", "-c", `
      aws configure set default.region ` + config.Aws_Region + `
      aws ec2 delete-key-pair --key-name px-deploy.` + config.Name + ` >&/dev/null
      [ "` + config.Aws__Vpc + `" ] || exit
      for i in $(aws elb describe-load-balancers --query "LoadBalancerDescriptions[].{a:VPCId,b:LoadBalancerName}" --output text | awk '/` + config.Aws__Vpc + `/{print$2}'); do
        aws elb delete-load-balancer --load-balancer-name $i
      done
      while [ "$(aws elb describe-load-balancers --query "LoadBalancerDescriptions[].VPCId" --output text | grep ` + config.Aws__Vpc + `)" ]; do
        echo "waiting for ELB to disappear"
        sleep 2
      done
      instances=$(aws ec2 describe-instances --filters "Name=network-interface.vpc-id,Values=` + config.Aws__Vpc + `" --query "Reservations[*].Instances[*].InstanceId" --output text)
      [[ "$instances" ]] && {
        volumes=$(for i in $instances; do aws ec2 describe-volumes --filters "Name=attachment.instance-id,Values=$i" --query "Volumes[*].{a:VolumeId,b:Tags}" --output text; done | awk '/PX-DO-NOT-DELETE/{print$1}')
        aws ec2 terminate-instances --instance-ids $instances >/dev/null
        aws ec2 wait instance-terminated --instance-ids $instances
      }
      for i in $volumes; do aws ec2 delete-volume --volume-id $i & done
      aws ec2 delete-subnet --subnet-id ` + config.Aws__Subnet + ` &&
      aws ec2 delete-security-group --group-id ` + config.Aws__Sg + ` &&
      aws ec2 detach-internet-gateway --internet-gateway-id ` + config.Aws__Gw + ` --vpc-id ` + config.Aws__Vpc + ` &&
      aws ec2 delete-internet-gateway --internet-gateway-id ` + config.Aws__Gw + ` &&
      aws ec2 delete-route-table --route-table-id ` +config.Aws__Routetable + ` &&
      aws ec2 delete-vpc --vpc-id ` + config.Aws__Vpc + `
      wait
    `).CombinedOutput()
  } else if (config.Cloud == "gcp") {
    output, _ = exec.Command("bash", "-c", "gcloud projects delete " + config.Gcp__Project + " --quiet").CombinedOutput()
    os.Remove("keys/px-deploy_gcp_" + config.Gcp__Project + ".json")
  } else if (config.Cloud == "azure") {
    output, _ = exec.Command("bash", "-c", `
      az group delete -y -g ` + config.Azure__Group + ` --only-show-errors
      az ad sp delete --id http://` + config.Azure__Group + ` --only-show-errors
    `).CombinedOutput()
  } else { die ("Bad cloud") }
  fmt.Print(string(output))
  os.Remove("deployments/" + name + ".yml")
  os.Remove("keys/id_rsa." + config.Cloud + "." + name)
  os.Remove("keys/id_rsa." + config.Cloud + "." + name + ".pub")
  fmt.Println("Destroyed.")
}

func get_ip(deployment string) string {
  config := parse_yaml("/px-deploy/.px-deploy/deployments/" + deployment + ".yml")
  var output []byte
  if (config.Cloud == "aws") {
    output, _ = exec.Command("bash", "-c", `aws ec2 describe-instances --region ` + config.Aws_Region + ` --filters "Name=network-interface.vpc-id,Values=` + config.Aws__Vpc + `" "Name=tag:Name,Values=master-1" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicIpAddress" --output text`).Output()
  } else if (config.Cloud == "gcp") {
    output, _ = exec.Command("bash", "-c", `gcloud compute instances list --project ` + config.Gcp__Project + ` --filter="name=('master-1')" --format 'flattened(networkInterfaces[0].accessConfigs[0].natIP)' | tail -1 | cut -f 2 -d " "`).Output()
  } else if (config.Cloud == "azure") {
    output, _ = exec.Command("bash", "-c", `az vm show -g ` + config.Azure__Group + ` -n master-1 -d --query publicIps --output tsv`).Output()
  }
  return strings.TrimSuffix(string(output), "\n")
}

func die(msg string) {
  fmt.Println(msg)
  os.Exit(1)
}

func parse_yaml(filename string) Config {
  b, err := ioutil.ReadFile(filename)
  if err != nil { die(err.Error()) }
  if len(b) != utf8.RuneCount(b) { die("Non-ASCII values found in " + filename) }
  var d Config
  yaml.Unmarshal(b, &d)
  return d
}

func print_table(header []string, data [][]string) {
  table := tablewriter.NewWriter(os.Stdout)
  table.SetHeader(header)
  table.SetHeaderAlignment(tablewriter.ALIGN_LEFT)
  table.SetColWidth(80)
  table.SetHeaderLine(false)
  table.SetBorder(false)
  table.SetTablePadding("  ")
  table.SetNoWhiteSpace(true)
  table.AppendBulk(data)
  table.Render()
}
