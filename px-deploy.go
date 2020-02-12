package main

import (
  "fmt"
  "os"
  "regexp"
  "syscall"
  "time"
  "os/exec"
  "text/tabwriter"
  "path/filepath"
  "strings"
  "github.com/spf13/cobra"
  "github.com/joho/godotenv"
  "github.com/google/uuid"
)

func main() {
  var deployName, deployPlatform, deployClusters, deployNodes, deployK8sVer, deployPxVer, deployAwsType, deployAwsEbs, deployGcpType, deployGcpDisks, deployGcpZone, deployTemplate, deployRegion, deployCloud, connectName, destroyName, statusName string

  os.Chdir("/px-deploy/.px-deploy")
  godotenv.Load("defaults")

  cmdDeploy := &cobra.Command {
    Use: "deploy",
    Short: "Creates a deployment",
    Long: "Creates a deployment",
    Run: func(cmd *cobra.Command, args []string) {
      if (deployName != "") {
        if (!regexp.MustCompile(`^[a-zA-Z0-9_\-\.]+$`).MatchString(deployName)) { die("Invalid deployment name '" + deployName + "'") }
        if _, err := os.Stat("./deployments/" + deployName); os.IsExist(err) { die("Deployment '" + deployName + "' already exists") }
      } else {
        deployName = uuid.New().String()
      }
      os.Setenv("DEP_NAME", deployName)
      if (deployTemplate != "") {
        if _, err := os.Stat("./templates/" + deployTemplate); os.IsNotExist(err) { die("Template '" + deployTemplate + "' does not exist") }
        godotenv.Overload("templates/" + deployTemplate)
        os.Setenv("DEP_TEMPLATE", deployTemplate)
      }
      if (deployCloud != "") {
        if (deployCloud != "aws" && deployCloud != "gcp") { die("Cloud must be 'aws' or 'gcp' (not '" + deployCloud + "')") }
        os.Setenv("DEP_CLOUD", deployCloud)
      }
      if (deployRegion != "") {
        if (!regexp.MustCompile(`^[a-zA-Z0-9_\-]+$`).MatchString(deployRegion)) { die("Invalid region '" + deployRegion + "'") }
        os.Setenv(strings.ToUpper(os.Getenv("DEP_CLOUD")) + "_REGION", deployRegion)
      }
      if (deployPlatform != "") {
        if (deployPlatform != "k8s" && deployPlatform != "ocp3") { die("Invalid platform '" + deployPlatform + "'") }
        os.Setenv("DEP_PLATFORM", deployPlatform)
      }
      if (deployClusters != "") {
        if (!regexp.MustCompile(`^[0-9]+$`).MatchString(deployClusters)) { die("Invalid number of clusters") }
        os.Setenv("DEP_CLUSTERS", deployClusters)
      }
      if (deployNodes != "") {
        if (!regexp.MustCompile(`^[0-9]+$`).MatchString(deployNodes)) { die("Invalid number of nodes") }
        os.Setenv("DEP_NODES", deployNodes)
      }
      if (deployK8sVer != "") {
        if (!regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+$`).MatchString(deployK8sVer)) { die("Invalid Kubernetes version '" + deployK8sVer + "'") }
        os.Setenv("DEP_K8S_VERSION", deployK8sVer)
      }
      if (deployPxVer != "") {
        if (!regexp.MustCompile(`^[0-9\.]+$`).MatchString(deployPxVer)) { die("Invalid Portworx version '" + deployPxVer + "'") }
        os.Setenv("DEP_PX_VERSION", deployPxVer)
      }
      if (deployAwsType != "") {
        if (!regexp.MustCompile(`^[0-9a-z\.]+$`).MatchString(deployAwsType)) { die("Invalid AWS type '" + deployAwsType + "'") }
        os.Setenv("AWS_TYPE", deployAwsType)
      }
      if (deployAwsEbs != "") {
        if (!regexp.MustCompile(`^[0-9a-z\ :]+$`).MatchString(deployAwsEbs)) { die("Invalid AWS EBS volumes '" + deployAwsEbs + "'") }
        os.Setenv("AWS_EBS", deployAwsEbs)
      }
      if (deployGcpType != "") {
        if (!regexp.MustCompile(`^[0-9a-z\-]+$`).MatchString(deployGcpType)) { die("Invalid GCP type '" + deployGcpType + "'") }
        os.Setenv("GCP_TYPE", deployGcpType)
      }
      if (deployGcpDisks != "") {
        if (!regexp.MustCompile(`^[0-9a-z\ :\-]+$`).MatchString(deployGcpDisks)) { die("Invalid GCP disks '" + deployGcpDisks + "'") }
        os.Setenv("GCP_DISKS", deployGcpDisks)
      }
      if (deployGcpZone != "") {
        if (deployGcpZone != "a" && deployGcpZone != "b" && deployGcpZone != "c") { die("Invalid GCP zone '" + deployGcpZone + "'") }
        os.Setenv("GCP_ZONE", deployGcpZone)
      }
      switch (os.Getenv("DEP_CLOUD")) {
        case "aws": create_deployment_aws()
        case "gcp": create_deployment_gcp()
        default: die("Bad cloud")
      }
      godotenv.Load("deployments/" + deployName)
      os.Chdir("/px-deploy/vagrant")
      syscall.Exec("/usr/bin/vagrant", []string{"vagrant", "up"}, os.Environ())
    },
  }
  
  cmdDestroy := &cobra.Command {
    Use: "destroy",
    Short: "Destroys a deployment",
    Long: "Destroys a deployment",
    Run: func(cmd *cobra.Command, args []string) {
      if _, err := os.Stat("./deployments/" + destroyName); os.IsNotExist(err) { die("Deployment '" + destroyName + "' does not exist") }
      godotenv.Overload("deployments/" + destroyName)
      var output []byte
      if (os.Getenv("DEP_CLOUD") == "aws") {
        output, _ = exec.Command("bash", "-c", `
          aws configure set default.region $AWS_REGION
          instances=$(aws ec2 describe-instances --filters "Name=network-interface.vpc-id,Values=$_AWS_vpc" --query "Reservations[*].Instances[*].InstanceId" --output text)
          [[ "$instances" ]] && {
            aws ec2 terminate-instances --instance-ids $instances >/dev/null
            aws ec2 wait instance-terminated --instance-ids $instances
          }
          aws ec2 delete-security-group --group-id $_AWS_sg &&
          aws ec2 delete-subnet --subnet-id $_AWS_subnet &&
          aws ec2 detach-internet-gateway --internet-gateway-id $_AWS_gw --vpc-id $_AWS_vpc &&
          aws ec2 delete-internet-gateway --internet-gateway-id $_AWS_gw &&
          aws ec2 delete-route-table --route-table-id $_AWS_routetable &&
          aws ec2 delete-vpc --vpc-id $_AWS_vpc
          aws ec2 delete-key-pair --key-name px-deploy.$DEP_NAME >&/dev/null
        `).CombinedOutput()
      } else if (os.Getenv("DEP_CLOUD") == "gcp") {
        output, _ = exec.Command("bash", "-c", `
          gcloud projects delete $_GCP_project --quiet
        `).CombinedOutput()
        os.Remove("keys/px-deploy_gcp_" + os.Getenv("_GCP_project") + ".json")
      }
      fmt.Print(string(output))
      os.Remove("deployments/" + destroyName)
      os.Remove("keys/id_rsa." + os.Getenv("DEP_CLOUD") + "." + destroyName)
      os.Remove("keys/id_rsa." + os.Getenv("DEP_CLOUD") + "." + destroyName + ".pub")
    },
  }
  
  cmdConnect := &cobra.Command {
    Use: "connect name",
    Short: "Connects to a deployment",
    Long: "Connects to the first master node as root",
    Run: func(cmd *cobra.Command, args []string) {
      if _, err := os.Stat("./deployments/" + connectName); os.IsNotExist(err) { die("Deployment '" + connectName + "' does not exist") }
      godotenv.Overload("deployments/" + connectName)
      var output []byte
      var ip string
      if (os.Getenv("DEP_CLOUD") == "aws") {
        output, _ = exec.Command("bash", "-c", `aws ec2 describe-instances --region $AWS_REGION --filters "Name=network-interface.vpc-id,Values=$_AWS_vpc" "Name=tag:Name,Values=master-1" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicIpAddress" --output text`).Output()
      } else if (os.Getenv("DEP_CLOUD") == "gcp") {
        output, _ = exec.Command("bash", "-c", `gcloud compute instances list --project $_GCP_project --filter="name=('master-1')" --format 'flattened(networkInterfaces[0].accessConfigs[0].natIP)' | tail -1 | cut -f 2 -d " "`).Output()
      }
      ip = strings.TrimSuffix(string(output), "\n")
      syscall.Exec("/usr/bin/ssh", []string{"ssh", "-oStrictHostKeyChecking=no","-i","keys/id_rsa." + os.Getenv("DEP_CLOUD") + "." + os.Getenv("DEP_NAME"),"root@" + ip}, os.Environ())
    },
  }
  
  cmdList := &cobra.Command {
    Use: "list",
    Short: "Lists available deployments",
    Long: "Lists available deployments",
    Run: func(cmd *cobra.Command, args []string) {
      w := tabwriter.NewWriter(os.Stdout, 0, 0, 1, ' ', 0)
      fmt.Fprintln(w, "Deployment\tCloud\tRegion\tPlatform\tTemplate\tClusters\tNodes\tCreated")
      filepath.Walk("deployments", func(file string, info os.FileInfo, err error) error {
        if (info.Mode() & os.ModeDir != 0) { return nil }
        godotenv.Overload(file)
        var region string
        switch os.Getenv("DEP_CLOUD") {
          case "aws": region = os.Getenv("AWS_REGION")
          case "gcp": region = os.Getenv("GCP_REGION")
          default: die("Unknown cloud")
        }
        template := os.Getenv("DEP_TEMPLATE");
        if (template == "") { template = "<None>" }
        fmt.Fprintln(w, filepath.Base(file) + "\t" + os.Getenv("DEP_CLOUD") + "\t" + region + "\t" + os.Getenv("DEP_PLATFORM") + "\t" + template + "\t" + os.Getenv("DEP_CLUSTERS") + "\t" + os.Getenv("DEP_NODES") + "\t" + info.ModTime().Format(time.RFC3339))
        return nil
      })
      w.Flush()
    },
  }

  cmdStatus := &cobra.Command {
    Use: "status name",
    Short: "Lists master IPs in a deployment",
    Long: "Lists master IPs in a deployment",
    Run: func(cmd *cobra.Command, args []string) {
      if _, err := os.Stat("./deployments/" + statusName); os.IsNotExist(err) { die("Deployment '" + statusName + "' does not exist") }
      godotenv.Overload("deployments/" + statusName)
      var output []byte
      var ip string
      if (os.Getenv("DEP_CLOUD") == "aws") {
        output, _ = exec.Command("bash", "-c", `aws ec2 describe-instances --region $AWS_REGION --filters "Name=network-interface.vpc-id,Values=$_AWS_vpc" "Name=tag:Name,Values=master-1" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicIpAddress" --output text`).Output()
      } else if (os.Getenv("DEP_CLOUD") == "gcp") {
        output, _ = exec.Command("bash", "-c", `gcloud compute instances list --project $_GCP_project --filter="name=('master-1')" --format 'flattened(networkInterfaces[0].accessConfigs[0].natIP)' | tail -1 | cut -f 2 -d " "`).Output()
      }
      ip = strings.TrimSuffix(string(output), "\n")
      c := `
        masters=$(grep master /etc/hosts | cut -f 2 -d " ")
        for m in $masters; do
          ip=$(sudo ssh -oStrictHostKeyChecking=no $m "curl http://ipinfo.io/ip" 2>/dev/null)
          hostname=$(sudo ssh -oStrictHostKeyChecking=no $m "curl http://ipinfo.io/hostname" 2>/dev/null)
          echo $m $ip $hostname
        done`
      syscall.Exec("/usr/bin/ssh", []string{"ssh", "-q", "-oStrictHostKeyChecking=no", "-i", "keys/id_rsa." + os.Getenv("DEP_CLOUD") + "." + os.Getenv("DEP_NAME"), "root@" + ip, c}, os.Environ())
    },
  }
  
  cmdDeploy.Flags().StringVarP(&deployName, "name", "n", "", "name of deployment to be created (if blank, generate UUID)")
  cmdDeploy.Flags().StringVarP(&deployPlatform, "platform", "p", "", "k8s or ocp3 (default " + os.Getenv("DEP_PLATFORM") + ")")
  cmdDeploy.Flags().StringVarP(&deployClusters, "clusters", "c", "", "number of clusters to be deployed (default " + os.Getenv("DEP_CLUSTERS") + ")")
  cmdDeploy.Flags().StringVarP(&deployNodes, "nodes", "N", "", "number of nodes to be deployed in each cluster (default " + os.Getenv("DEP_NODES") + ")")
  cmdDeploy.Flags().StringVarP(&deployK8sVer, "k8s_version", "k", "", "Kubernetes version to be deployed (default " + os.Getenv("DEP_K8S_VERSION") + ")")
  cmdDeploy.Flags().StringVarP(&deployPxVer, "px_version", "", os.Getenv("DEP_PX_VERSION"), "Portworx version to be deployed")
  cmdDeploy.Flags().StringVarP(&deployAwsType, "aws_type", "", os.Getenv("AWS_TYPE"), "AWS type for each node")
  cmdDeploy.Flags().StringVarP(&deployAwsEbs, "aws_ebs", "", os.Getenv("AWS_EBS"), "space-separated list of EBS volumes to be attached to worker nodes, eg \"gp2:20 standard:30\"")
  cmdDeploy.Flags().StringVarP(&deployGcpType, "gcp_type", "", os.Getenv("GCP_TYPE"), "GCP type for each node")
  cmdDeploy.Flags().StringVarP(&deployGcpDisks, "gcp_disks", "", os.Getenv("GCP_DISKS"), "space-separated list of EBS volumes to be attached to worker nodes, eg \"pd-standard:20 pd-ssd:30\"")
  cmdDeploy.Flags().StringVarP(&deployGcpZone, "gcp_zone", "", os.Getenv("GCP_ZONE"), "GCP zone (a, b or c)")
  cmdDeploy.Flags().StringVarP(&deployTemplate, "template", "t", "", "name of template to be deployed")
  cmdDeploy.Flags().StringVarP(&deployRegion, "region", "r", "", "AWS or GCP region (default " + os.Getenv("AWS_REGION") + " or " + os.Getenv("GCP_REGION") + ")")
  cmdDeploy.Flags().StringVarP(&deployCloud, "cloud", "C", "", "aws or gcp (default " + os.Getenv("DEP_CLOUD") + ")")

  cmdDestroy.Flags().StringVarP(&destroyName, "name", "n", "", "name of deployment to be destroyed")
  cmdDestroy.MarkFlagRequired("name")

  cmdConnect.Flags().StringVarP(&connectName, "name", "n", "", "name of deployment to connect to")
  cmdConnect.MarkFlagRequired("name")

  cmdStatus.Flags().StringVarP(&statusName, "name", "n", "", "name of deployment")
  cmdStatus.MarkFlagRequired("name")

  rootCmd := &cobra.Command{Use: "px-deploy"}
  rootCmd.AddCommand(cmdDeploy, cmdDestroy, cmdConnect, cmdList, cmdStatus)
  rootCmd.Execute()
}

func create_deployment_aws() {
  output, _ := exec.Command("bash", "-c", `
    aws configure set default.region $AWS_REGION
    rm -f keys/id_rsa.aws.$DEP_NAME*
    ssh-keygen -q -t rsa -b 2048 -f keys/id_rsa.aws.$DEP_NAME -N ''
    aws ec2 delete-key-pair --key-name px-deploy.$DEP_NAME >&/dev/null
    aws ec2 import-key-pair --key-name px-deploy.$DEP_NAME --public-key-material file://keys/id_rsa.aws.$DEP_NAME.pub
    _AWS_vpc=$(aws --output text ec2 create-vpc --cidr-block 192.168.0.0/16 --query Vpc.VpcId)
    _AWS_subnet=$(aws --output text ec2 create-subnet --vpc-id $_AWS_vpc --cidr-block 192.168.0.0/16 --query Subnet.SubnetId)
    _AWS_gw=$(aws --output text ec2 create-internet-gateway --query InternetGateway.InternetGatewayId)
    aws ec2 attach-internet-gateway --vpc-id $_AWS_vpc --internet-gateway-id $_AWS_gw
    _AWS_routetable=$(aws --output text ec2 create-route-table --vpc-id $_AWS_vpc --query RouteTable.RouteTableId)
    aws ec2 create-route --route-table-id $_AWS_routetable --destination-cidr-block 0.0.0.0/0 --gateway-id $_AWS_gw >/dev/null
    aws ec2 associate-route-table  --subnet-id $_AWS_subnet --route-table-id $_AWS_routetable >/dev/null
    _AWS_sg=$(aws --output text ec2 create-security-group --group-name px-cloud --description "Security group for px-cloud" --vpc-id $_AWS_vpc --query GroupId)
    aws ec2 authorize-security-group-ingress --group-id $_AWS_sg --protocol tcp --port 22 --cidr 0.0.0.0/0 &
    aws ec2 authorize-security-group-ingress --group-id $_AWS_sg --protocol tcp --port 443 --cidr 0.0.0.0/0 &
    aws ec2 authorize-security-group-ingress --group-id $_AWS_sg --protocol tcp --port 8080 --cidr 0.0.0.0/0 &
    aws ec2 authorize-security-group-ingress --group-id $_AWS_sg --protocol tcp --port 30000-32767 --cidr 0.0.0.0/0 &
    aws ec2 authorize-security-group-ingress --group-id $_AWS_sg --protocol all --cidr 192.168.0.0/16 &
    aws ec2 create-tags --resources $_AWS_vpc $_AWS_subnet $_AWS_gw $_AWS_routetable $_AWS_sg --tags Key=px-deploy_name,Value=$DEP_NAME &
    aws ec2 create-tags --resources $_AWS_vpc --tags Key=Name,Value=px-deploy.$DEP_NAME &
    _AWS_ami=$(aws --output text ec2 describe-images --owners 679593333241 --filters Name=name,Values='CentOS Linux 7 x86_64 HVM EBS*' Name=architecture,Values=x86_64 Name=root-device-type,Values=ebs --query 'sort_by(Images, &Name)[-1].ImageId')
    wait
    set | grep ^_AWS >deployments/$DEP_NAME
  `).CombinedOutput()
  fmt.Print(string(output))
  f, _ := os.OpenFile("deployments/" + os.Getenv("DEP_NAME"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
  for _, i := range os.Environ() {
    if (strings.HasPrefix(i, "DEP") || strings.HasPrefix(i, "AWS")) { f.WriteString(i + "\n") }
  }
  f.Close()
}

func create_deployment_gcp() {
  output, _ := exec.Command("bash", "-c", `
  rm -f keys/id_rsa.gcp.$DEP_NAME*
  ssh-keygen -q -t rsa -b 2048 -f keys/id_rsa.gcp.$DEP_NAME -N ''
  _GCP_project=pxd-$(uuidgen | tr -d -- - | cut -b 1-26 | tr 'A-Z' 'a-z')
  gcloud projects create $_GCP_project --labels px-deploy_name=$DEP_NAME
  account=$(gcloud alpha billing accounts list | tail -1 | cut -f 1 -d " ")
  gcloud alpha billing projects link $_GCP_project --billing-account $account
  gcloud services enable compute.googleapis.com --project $_GCP_project
  gcloud compute networks create px-net --project $_GCP_project
  gcloud compute networks subnets create --range 192.168.0.0/16 --network px-net px-subnet --region $GCP_REGION --project $_GCP_project
  gcloud compute firewall-rules create allow-internal --allow=tcp,udp,icmp --source-ranges=192.168.0.0/16 --network px-net --project $_GCP_project &
  gcloud compute firewall-rules create allow-external --allow=tcp:22,tcp:443,tcp:6443 --network px-net --project $_GCP_project &
  gcloud compute project-info add-metadata --metadata "ssh-keys=centos:$(cat keys/id_rsa.gcp.$DEP_NAME.pub)" --project $_GCP_project &
  service_account=$(gcloud iam service-accounts list --project $_GCP_project --format 'flattened(email)' | tail -1 | cut -f 2 -d " ")
  _GCP_key=$(gcloud iam service-accounts keys create /dev/stdout --iam-account $service_account | base64 -w0)
  wait
  set | grep ^_GCP >deployments/$DEP_NAME
  `).CombinedOutput()
  fmt.Print(string(output))
  f, _ := os.OpenFile("deployments/" + os.Getenv("DEP_NAME"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
  for _, i := range os.Environ() {
    if (strings.HasPrefix(i, "DEP") || strings.HasPrefix(i, "GCP")) { f.WriteString(i + "\n") }
  }
  f.Close()
}

func die(msg string) {
  fmt.Println(msg)
  os.Exit(1)
}
