package main

import (
	"bufio"
	"context"
	"encoding/base64"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"reflect"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
	"unicode/utf8"

	"github.com/Azure/azure-sdk-for-go/sdk/azcore/to"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/resourcegraph/armresourcegraph"
	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/ec2"

	"github.com/go-yaml/yaml"
	"github.com/google/uuid"
	version_hashicorp "github.com/hashicorp/go-version"
	"github.com/imdario/mergo"
	"github.com/olekukonko/tablewriter"
	"github.com/spf13/cobra"
)

type Config struct {
	Name                     string
	Template                 string
	Cloud                    string
	Aws_Region               string
	Gcp_Region               string
	Azure_Region             string
	Platform                 string
	Clusters                 string
	Nodes                    string
	K8s_Version              string
	Px_Version               string
	Stop_After               string
	Post_Script              string
	Auto_Destroy             string
	Quiet                    string
	Dry_Run                  string
	Aws_Type                 string
	Aws_Ebs                  string
	Aws_Tags                 string
	Eks_Version              string
	Tags                     string
	Aws_Access_Key_Id        string
	Aws_Secret_Access_Key    string
	Gcp_Type                 string
	Gcp_Disks                string
	Gcp_Zone                 string
	Gcp_Project              string
	Gcp_Auth_Json            string
	Gke_Version              string
	Azure_Type               string
	Azure_Disks              string
	Azure_Client_Id          string
	Azure_Client_Secret      string
	Azure_Subscription_Id    string
	Azure_Tenant_Id          string
	Aks_Version              string
	Vsphere_Host             string
	Vsphere_Compute_Resource string
	Vsphere_Resource_Pool    string
	Vsphere_User             string
	Vsphere_Password         string
	Vsphere_Template         string
	Vsphere_Datastore        string
	Vsphere_Datacenter       string
	Vsphere_Folder           string
	Vsphere_Disks            string
	Vsphere_Network          string
	Vsphere_Memory           string
	Vsphere_Cpu              string
	Vsphere_Repo             string
	Vsphere_Dns              string
	Vsphere_Gw               string
	Vsphere_Node_Ip          string
	Vsphere_Nodemap          map[string]string
	Scripts                  []string
	Description              string
	Env                      map[string]string
	Cluster                  []Config_Cluster
	Ocp4_Version             string
	Ocp4_Pull_Secret         string
	Ocp4_Domain              string
	Aws__Vpc                 string `yaml:"aws__vpc,omitempty"`
	Gcp__Vpc                 string `yaml:"gcp__vpc,omitempty"`
	Aws__Sg                  string `yaml:"aws__sg,omitempty"`
	Aws__Subnet              string `yaml:"aws__subnet,omitempty"`
	Aws__Gw                  string `yaml:"aws__gw,omitempty"`
	Aws__Routetable          string `yaml:"aws__routetable,omitempty"`
	Aws__Ami                 string `yaml:"aws__ami,omitempty"`
	Gcp__Project             string `yaml:"gcp__project,omitempty"`
	Gcp__Key                 string `yaml:"gcp__key,omitempty"`
	Azure__Group             string `yaml:"azure__group,omitempty"`
	Vsphere__Userdata        string `yaml:"vsphere__userdata,omitempty"`
	Ssh_Pub_Key              string
}

type Config_Cluster struct {
	Id            int
	Scripts       []string
	Instance_Type string
}

var Reset = "\033[0m"
var White = "\033[97m"
var Red = "\033[31m"
var Green = "\033[32m"
var Yellow = "\033[33m"
var Blue = "\033[34m"

var wg sync.WaitGroup

func main() {
	var createName, createPlatform, createClusters, createNodes, createK8sVer, createPxVer, createStopAfter, createAwsType, createAwsEbs, createAwsAccessKeyId, createEksVersion, createAwsSecretAccessKey, createTags, createGcpType, createGcpDisks, createGcpZone, createGcpProject, createGkeVersion, createAzureType, createAksVersion, createAzureDisks, createAzureClientSecret, createAzureClientId, createAzureTenantId, createAzureSubscriptionId, createTemplate, createRegion, createCloud, createEnv, createSshPubKey, connectName, kubeconfigName, destroyName, statusName, historyNumber string
	var createQuiet, createDryRun, destroyAll, destroyClear bool
	os.Chdir("/px-deploy/.px-deploy")
	rootCmd := &cobra.Command{Use: "px-deploy"}

	cmdCreate := &cobra.Command{
		Use:   "create",
		Short: "Creates a deployment",
		Long:  "Creates a deployment",
		Run: func(cmd *cobra.Command, args []string) {
			version_current := get_version_current()
			version_latest := get_version_latest()
			if version_latest == "" {
				fmt.Println(Yellow + "Current version is " + version_current + ", cannot determine latest version")
			} else {
				if version_current != version_latest {
					fmt.Println(Yellow + "Current version is " + version_current + ", latest version is " + version_latest)
				} else {
					fmt.Println(Green + "Current version is " + version_current + " (latest)")
				}
			}
			fmt.Print(Reset)

			if len(args) > 0 {
				die("Invalid arguments")
			}
			config := parse_yaml("defaults.yml")

			if config.Aws_Tags != "" {
				fmt.Printf("Parameter 'aws_tags: %s' is deprecated and will be ignored. Please change to 'tags: %s'  in ~/.px-deploy/defaults.yml \n", config.Aws_Tags, config.Aws_Tags)
			}

			// check for "recommended" version in default.yaml.[version_current]
			if _, err := os.Stat("defaults.yml." + version_current); os.IsNotExist(err) {
				fmt.Printf("%sdefaults.yml.%s not found. No recommended versions available to be shown%s \n", Yellow, version_current, Reset)
			} else {
				fmt.Printf("checking your defaults.yml for recommended version settings (from defaults.yml.%s) \n", version_current)
				recommended_versions := parse_yaml(fmt.Sprintf("defaults.yml.%s", version_current))
				recVers := reflect.ValueOf(recommended_versions)
				curDef := reflect.ValueOf(config)
				typeOfS := recVers.Type()
				for i := 0; i < recVers.NumField(); i++ {
					// get all fields from recommended defaults.yml.VERSION with name "version" inside and check against current default settings
					if strings.Contains(strings.ToLower(typeOfS.Field(i).Name), "version") {
						versioning_field := strings.ToLower(typeOfS.Field(i).Name)
						versioning_current := fmt.Sprintf("%s", reflect.Indirect(curDef).FieldByName(typeOfS.Field(i).Name))
						versioning_recommended := fmt.Sprintf("%s", recVers.Field(i).Interface())
						//fmt.Printf("(Field: %s\t Value: %s \t\t Recommended: %s)\n", versioning_field , versioning_current, versioning_recommended)
						if versioning_recommended != "" && versioning_current != "" {
							if versioning_recommended != versioning_current {

								v1, err := version_hashicorp.NewVersion(versioning_current)
								if err != nil {
									fmt.Printf("Error processing current Versioning %s : %s\n", versioning_field, versioning_current)
								}
								v2, err := version_hashicorp.NewVersion(versioning_recommended)
								if err != nil {
									fmt.Printf("Error processing recommended Versioning %s : %s", versioning_field, versioning_recommended)
								}
								if v1.LessThan(v2) {
									fmt.Printf("%sWarning:%s %s: %s %sin defaults.yml is lower than recommended setting%s %s\n", Yellow, Reset, versioning_field, versioning_current, Yellow, Reset, versioning_recommended)
								}
							}
						} else if versioning_recommended == "" {
							fmt.Printf("Field %s has no recommended version information available\n", versioning_field)
						} else if versioning_current == "" {
							fmt.Printf("%s please add%s %s: \"%s\" %sto defaults.yml (recommended setting) %s\n", Red, Reset, versioning_field, versioning_recommended, Red, Reset)
						}
					}
				}
			}

			env := config.Env
			var env_template map[string]string
			if createTemplate != "" {
				config.Template = createTemplate
				config_template := parse_yaml("templates/" + createTemplate + ".yml")
				env_template = config_template.Env
				mergo.MergeWithOverwrite(&config, config_template)
				mergo.MergeWithOverwrite(&env, env_template)
			}
			if createName != "" {
				if !regexp.MustCompile(`^[a-z0-9_\-\.]+$`).MatchString(createName) {
					die("Invalid deployment name '" + createName + "'")
				}
				if _, err := os.Stat("deployments/" + createName + ".yml"); !os.IsNotExist(err) {
					fmt.Printf("%sDeployment '%s' already exists%s\n", Red, createName, Reset)
					fmt.Printf("Please delete it by running 'px-deploy destroy -n %s' \n", createName)
					fmt.Printf("If this fails, remove cloud resources manually and run 'px-deploy destroy --clear -n %s'", createName)
					die("")
				}
			} else {
				createName = uuid.New().String()
			}
			config.Name = createName

			if createCloud != "" {
				config.Cloud = createCloud
			}
			if config.Cloud != "aws" && config.Cloud != "gcp" && config.Cloud != "azure" && config.Cloud != "vsphere" {
				die("Cloud must be 'aws', 'gcp', 'azure' or 'vsphere' (not '" + config.Cloud + "')")
			}

			if createSshPubKey != "" {
				config.Ssh_Pub_Key = createSshPubKey
			}

			if createRegion != "" {
				switch config.Cloud {
				case "aws":
					config.Aws_Region = createRegion
				case "gcp":
					config.Gcp_Region = createRegion
				case "azure":
					config.Azure_Region = createRegion
				default:
					die("setting cloud region not supported on " + config.Cloud)
				}
			}

			// check for command-line overrides and parameter validity for each cloud
			switch config.Cloud {
			case "aws":
				if !regexp.MustCompile(`^[a-zA-Z0-9_\-]+$`).MatchString(config.Aws_Region) {
					die("Invalid region '" + config.Aws_Region + "'")
				}

				if createAwsType != "" {
					config.Aws_Type = createAwsType
				}
				if !regexp.MustCompile(`^[0-9a-z\.]+$`).MatchString(config.Aws_Type) {
					die("Invalid AWS type '" + config.Aws_Type + "'")
				}

				if createAwsAccessKeyId != "" {
					config.Aws_Access_Key_Id = createAwsAccessKeyId
				}
				if createAwsSecretAccessKey != "" {
					config.Aws_Secret_Access_Key = createAwsSecretAccessKey
				}

				if createAwsEbs != "" {
					config.Aws_Ebs = createAwsEbs
				}
				if !regexp.MustCompile(`^[0-9a-z\ :]+$`).MatchString(config.Aws_Ebs) {
					die("Invalid AWS EBS volumes '" + config.Aws_Ebs + "'")
				}

				if createEksVersion != "" {
					config.Eks_Version = createEksVersion
				}
				if !regexp.MustCompile(`^[0-9\.]+$`).MatchString(config.Eks_Version) {
					die("Invalid EKS version '" + config.Eks_Version + "'")
				}

			case "gcp":
				if !regexp.MustCompile(`^[a-zA-Z0-9_\-]+$`).MatchString(config.Gcp_Region) {
					die("Invalid region '" + config.Gcp_Region + "'")
				}
				if createGcpType != "" {
					config.Gcp_Type = createGcpType
				}
				if !regexp.MustCompile(`^[0-9a-z\-]+$`).MatchString(config.Gcp_Type) {
					die("Invalid GCP type '" + config.Gcp_Type + "'")
				}

				if createGcpDisks != "" {
					config.Gcp_Disks = createGcpDisks
				}
				if !regexp.MustCompile(`^[0-9a-z\ :\-]+$`).MatchString(config.Gcp_Disks) {
					die("Invalid GCP disks '" + config.Gcp_Disks + "'")
				}

				if createGcpZone != "" {
					config.Gcp_Zone = createGcpZone
				}

				if createGcpProject != "" {
					config.Gcp_Project = createGcpProject
				}

				if config.Gcp_Zone != "a" && config.Gcp_Zone != "b" && config.Gcp_Zone != "c" {
					die("Invalid GCP zone '" + config.Gcp_Zone + "'")
				}

				if createGkeVersion != "" {
					config.Gke_Version = createGkeVersion
				}
				if !regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+-gke\.[0-9]+$`).MatchString(config.Gke_Version) {
					die("Invalid GKE version '" + config.Gke_Version + "'")
				}

			case "azure":
				if !regexp.MustCompile(`^[a-zA-Z0-9_\-]+$`).MatchString(config.Azure_Region) {
					die("Invalid region '" + config.Azure_Region + "'")
				}
				if createAzureClientId != "" {
					config.Azure_Client_Id = createAzureClientId
				}
				if createAzureClientSecret != "" {
					config.Azure_Client_Secret = createAzureClientSecret
				}
				if createAzureTenantId != "" {
					config.Azure_Tenant_Id = createAzureTenantId
				}
				if createAzureSubscriptionId != "" {
					config.Azure_Subscription_Id = createAzureSubscriptionId
				}

				if createAksVersion != "" {
					config.Aks_Version = createAksVersion
				}
				if !regexp.MustCompile(`^[0-9\.]+$`).MatchString(config.Aks_Version) {
					die("Invalid AKS version '" + config.Aks_Version + "'")
				}

				if createAzureType != "" {
					config.Azure_Type = createAzureType
				}
				if !regexp.MustCompile(`^[0-9a-zA-Z\-\_]+$`).MatchString(config.Azure_Type) {
					die("Invalid Azure type '" + config.Azure_Type + "'")
				}

				if createAzureDisks != "" {
					config.Azure_Disks = createAzureDisks
				}
				if !regexp.MustCompile(`^[0-9a-zA-Z\ \_:]+$`).MatchString(config.Azure_Disks) {
					die("Invalid Azure disks '" + config.Azure_Disks + "'")
				}
			case "vsphere":
				config.Vsphere_Template = strings.TrimLeft(config.Vsphere_Template, "/\\")
				config.Vsphere_Folder = strings.TrimLeft(config.Vsphere_Folder, "/\\")
				config.Vsphere_Folder = strings.TrimRight(config.Vsphere_Folder, "/\\")
			}

			if createPlatform != "" {
				config.Platform = createPlatform
			}
			if config.Platform != "k8s" && config.Platform != "k3s" && config.Platform != "none" && config.Platform != "dockeree" && config.Platform != "ocp4" && config.Platform != "eks" && config.Platform != "gke" && config.Platform != "aks" && config.Platform != "nomad" {
				die("Invalid platform '" + config.Platform + "'")
			}

			if createClusters != "" {
				config.Clusters = createClusters
			}
			if !regexp.MustCompile(`^[0-9]+$`).MatchString(config.Clusters) {
				die("Invalid number of clusters")
			}

			if createNodes != "" {
				config.Nodes = createNodes
			}
			if !regexp.MustCompile(`^[0-9]+$`).MatchString(config.Nodes) {
				die("Invalid number of nodes")
			}

			if createK8sVer != "" {
				config.K8s_Version = createK8sVer
			}
			if !regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+$`).MatchString(config.K8s_Version) {
				die("Invalid Kubernetes version '" + config.K8s_Version + "'")
			}

			if createPxVer != "" {
				config.Px_Version = createPxVer
			}
			if !regexp.MustCompile(`^[0-9\.]+$`).MatchString(config.Px_Version) {
				die("Invalid Portworx version '" + config.Px_Version + "'")
			}

			if createStopAfter != "" {
				config.Stop_After = createStopAfter
			}
			if !regexp.MustCompile(`^[0-9]+$`).MatchString(config.Stop_After) {
				die("Invalid number of hours")
			}

			if createEnv != "" {
				env_cli := make(map[string]string)
				for _, kv := range strings.Split(createEnv, ",") {
					s := strings.Split(kv, "=")
					env_cli[s[0]] = s[1]
				}
				mergo.MergeWithOverwrite(&env, env_cli)
			}
			config.Env = env
			if createQuiet {
				config.Quiet = "true"
			}
			if createDryRun {
				config.Dry_Run = "true"
			}

			if createTags != "" {
				config.Tags = createTags
			}

			if !regexp.MustCompile(`^((([\p{L}\p{Z}\p{N}_.:+\-]*)=([\p{L}\p{Z}\p{N}_.:+\-]*),)*(([\p{L}\p{Z}\p{N}_.:+\-]*)=([\p{L}\p{Z}\p{N}_.:+\-]*)){1})*$`).MatchString(config.Tags) {
				die("Invalid tags '" + config.Tags + "'")
			}

			for _, c := range config.Cluster {
				for _, s := range c.Scripts {
					if _, err := os.Stat("scripts/" + s); os.IsNotExist(err) {
						die("Script '" + s + "' does not exist")
					}
					cmd := exec.Command("bash", "-n", "scripts/"+s)
					err := cmd.Run()
					if err != nil {
						die("Script '" + s + "' is not valid Bash")
					}
				}
			}
			for _, s := range config.Scripts {
				if _, err := os.Stat("scripts/" + s); os.IsNotExist(err) {
					die("Script '" + s + "' does not exist")
				}
				cmd := exec.Command("bash", "-n", "scripts/"+s)
				err := cmd.Run()
				if err != nil {
					die("Script '" + s + "' is not valid Bash")
				}
			}
			if config.Post_Script != "" {
				if _, err := os.Stat("scripts/" + config.Post_Script); os.IsNotExist(err) {
					die("Postscript '" + config.Post_Script + "' does not exist")
				}
				cmd := exec.Command("bash", "-n", "scripts/"+config.Post_Script)
				err := cmd.Run()
				if err != nil {
					die("Postscript '" + config.Post_Script + "' is not valid Bash")
				}
			}
			switch config.Cloud {
			case "aws":
				checkvar := []string{"aws_access_key_id", "aws_secret_access_key"}
				emptyVars := isEmpty(config.Aws_Access_Key_Id, config.Aws_Secret_Access_Key)
				if len(emptyVars) > 0 {
					for _, i := range emptyVars {
						fmt.Printf("%splease set \"%s\" in defaults.yml %s\n", Red, checkvar[i], Reset)
					}
					die("canceled deployment")
				}
			case "azure":
				checkvar := []string{"azure_client_id", "azure_client_secret", "azure_tenant_id", "azure_subscription_id"}
				emptyVars := isEmpty(config.Azure_Client_Id, config.Azure_Client_Secret, config.Azure_Tenant_Id, config.Azure_Subscription_Id)
				if len(emptyVars) > 0 {
					for _, i := range emptyVars {
						fmt.Printf("%splease set \"%s\" in defaults.yml %s\n", Red, checkvar[i], Reset)
					}
					die("canceled deployment")
				}
			case "gcp":
				checkvar := []string{"gcp_project"}
				emptyVars := isEmpty(config.Gcp_Project)
				if len(emptyVars) > 0 {
					for _, i := range emptyVars {
						fmt.Printf("%splease set \"%s\" in defaults.yml %s\n", Red, checkvar[i], Reset)
					}
					die("canceled deployment")
				}
			case "vsphere":
				checkvar := []string{"vsphere_compute_resource", "vsphere_datacenter", "vsphere_datastore", "vsphere_host", "vsphere_network", "vsphere_resource_pool", "vsphere_template", "vsphere_user", "vsphere_password", "vsphere_repo"}
				emptyVars := isEmpty(config.Vsphere_Compute_Resource, config.Vsphere_Datacenter, config.Vsphere_Datastore, config.Vsphere_Host, config.Vsphere_Network, config.Vsphere_Resource_Pool, config.Vsphere_Template, config.Vsphere_User, config.Vsphere_Password, config.Vsphere_Repo)
				if len(emptyVars) > 0 {
					for _, i := range emptyVars {
						fmt.Printf("%splease set \"%s\" in defaults.yml %s\n", Red, checkvar[i], Reset)
					}
					die("canceled deployment")
				}
			}

			if config.Platform == "ocp4" {
				checkvar := []string{"ocp4_domain", "ocp4_pull_secret"}
				emptyVars := isEmpty(config.Ocp4_Domain, config.Ocp4_Pull_Secret)
				if len(emptyVars) > 0 {
					for _, i := range emptyVars {
						fmt.Printf("%splease set \"%s\" in defaults.yml %s\n", Red, checkvar[i], Reset)
					}
					die("canceled deployment")
				}
			}

			if config.Cloud == "gcp" {
				if config.Gcp_Project == "" {
					die("Please set gcp_project in defaults.yml")
				}

				if _, err := os.Stat("/px-deploy/.px-deploy/gcp.json"); os.IsNotExist(err) {
					die("~/.px-deploy/gcp.json not found. refer to readme.md how to create it")
				} else {
					config.Gcp_Auth_Json = "/px-deploy/.px-deploy/gcp.json"
				}
			}

			if config.Platform == "eks" && !(config.Cloud == "aws") {
				die("EKS only makes sense with AWS (not " + config.Cloud + ")")
			}
			if config.Platform == "ocp4" && config.Cloud != "aws" {
				die("Openshift 4 only supported on AWS (not " + config.Cloud + ")")
			}
			if config.Platform == "gke" && config.Cloud != "gcp" {
				die("GKE only makes sense with GCP (not " + config.Cloud + ")")
			}
			if config.Platform == "aks" && config.Cloud != "azure" {
				die("AKS only makes sense with Azure (not " + config.Cloud + ")")
			}
			y, _ := yaml.Marshal(config)
			log("[ " + strings.Join(os.Args[1:], " ") + " ] " + base64.StdEncoding.EncodeToString(y))

			err := ioutil.WriteFile("deployments/"+createName+".yml", y, 0644)
			if err != nil {
				die(err.Error())
			}
			if create_deployment(config) != 0 {
				destroy_deployment(config.Name)
				die("Aborted")
			}
			os.Chdir("/px-deploy/vagrant")
			os.Setenv("deployment", config.Name)

			if config.Auto_Destroy == "true" {
				destroy_deployment(config.Name)
			}
		},
	}

	cmdDestroy := &cobra.Command{
		Use:   "destroy",
		Short: "Destroys a deployment",
		Long:  "Destroys a deployment",
		Run: func(cmd *cobra.Command, args []string) {
			if destroyAll {
				if destroyClear {
					die("--clear is not supported with -a")
				}

				if destroyName != "" {
					die("Specify either -a or -n, not both")
				}
				filepath.Walk("deployments", func(file string, info os.FileInfo, err error) error {
					if info.Mode()&os.ModeDir != 0 {
						return nil
					}
					config := parse_yaml(file)
					destroy_deployment(config.Name)
					return nil
				})
			} else {
				if destroyName == "" {
					die("Must specify deployment to destroy")
				}
				if destroyClear {
					destroy_clear(destroyName)
				} else {
					destroy_deployment(destroyName)
				}
			}
		},
	}

	cmdConnect := &cobra.Command{
		Use:   "connect -n name [ command ]",
		Short: "Connects to a deployment",
		Long:  "Connects to the first master node as root, and executes optional command",
		Run: func(cmd *cobra.Command, args []string) {
			config := parse_yaml("deployments/" + connectName + ".yml")
			ip := get_ip(connectName)
			command := ""
			if len(args) > 0 {
				command = args[0]
			}
			syscall.Exec("/usr/bin/ssh", []string{"ssh", "-oLoglevel=ERROR", "-oStrictHostKeyChecking=no", "-i", "keys/id_rsa." + config.Cloud + "." + config.Name, "root@" + ip, command}, os.Environ())
		},
	}

	cmdKubeconfig := &cobra.Command{
		Use:   "kubeconfig -n name",
		Short: "Downloads kubeconfigs from clusters",
		Long:  "Downloads kubeconfigs from clusters",
		Run: func(cmd *cobra.Command, args []string) {
			config := parse_yaml("deployments/" + kubeconfigName + ".yml")
			ip := get_ip(kubeconfigName)
			clusters, _ := strconv.Atoi(config.Clusters)
			for c := 1; c <= clusters; c++ {
				cmd := exec.Command("bash", "-c", "ssh -oLoglevel=ERROR -oStrictHostKeyChecking=no -i keys/id_rsa."+config.Cloud+"."+config.Name+" root@"+ip+" ssh master-"+strconv.Itoa(c)+" cat /root/.kube/config")
				kubeconfig, err := cmd.Output()
				if err != nil {
					die(err.Error())
				}
				err = ioutil.WriteFile("kubeconfig/"+config.Name+"."+strconv.Itoa(c), kubeconfig, 0644)
				if err != nil {
					die(err.Error())
				}
			}
		},
	}

	cmdList := &cobra.Command{
		Use:   "list",
		Short: "Lists available deployments",
		Long:  "Lists available deployments",
		Run: func(cmd *cobra.Command, args []string) {
			var data [][]string
			filepath.Walk("deployments", func(file string, info os.FileInfo, err error) error {
				if info.Mode()&os.ModeDir != 0 {
					return nil
				}
				if !strings.HasSuffix(file, ".yml") {
					return nil
				}
				config := parse_yaml(file)
				var region string
				switch config.Cloud {
				case "aws":
					region = config.Aws_Region
				case "gcp":
					region = config.Gcp_Region
				case "azure":
					region = config.Azure_Region
				case "vsphere":
					region = config.Vsphere_Compute_Resource
				}
				if config.Name == "" {
					config.Name = Red + "UNKNOWN" + Reset
				} else {
					if config.Template == "" {
						config.Template = "<None>"
					}
				}
				data = append(data, []string{config.Name, config.Cloud, region, config.Platform, config.Template, config.Clusters, config.Nodes, info.ModTime().Format(time.RFC3339)})

				return nil
			})
			print_table([]string{"Deployment", "Cloud", "Region", "Platform", "Template", "Clusters", "Nodes/Cl", "Created"}, data)
		},
	}

	cmdTemplates := &cobra.Command{
		Use:   "templates",
		Short: "Lists available templates",
		Long:  "Lists available templates",
		Run: func(cmd *cobra.Command, args []string) {
			list_templates()
		},
	}

	cmdStatus := &cobra.Command{
		Use:   "status name",
		Short: "Lists master IPs in a deployment",
		Long:  "Lists master IPs in a deployment",
		Run: func(cmd *cobra.Command, args []string) {
			config := parse_yaml("deployments/" + statusName + ".yml")

			var ip string

			Clusters, _ := strconv.Atoi(config.Clusters)
			Nodes, _ := strconv.Atoi(config.Nodes)

			if (config.Platform == "ocp4") || (config.Platform == "eks") || (config.Platform == "aks") || (config.Platform == "gke") {
				Nodes = 0
			}
			// loop clusters and add master name/ip to tf var
			for c := 1; c <= Clusters; c++ {

				switch config.Cloud {
				case "aws":
					ip = aws_get_node_ip(statusName, fmt.Sprintf("master-%v-1", c))
				case "azure":
					ip = azure_get_node_ip(statusName, fmt.Sprintf("master-%v-1", c))
				case "gcp":
					ip = gcp_get_node_ip(statusName, fmt.Sprintf("%v-master-%v-1", config.Name, c))
				case "vsphere":
					ip = vsphere_get_node_ip(&config, fmt.Sprintf("%v-master-%v", config.Name, c))
				}
				// get content of node tracking file (-> each node will add its entry when finished cloud-init/vagrant scripts)
				cmd := exec.Command("ssh", "-q", "-oStrictHostKeyChecking=no", "-i", "keys/id_rsa."+config.Cloud+"."+config.Name, "root@"+ip, "cat /var/log/px-deploy/completed/tracking")
				out, err := cmd.CombinedOutput()
				if err != nil {
					die(err.Error())
				} else {
					scanner := bufio.NewScanner(strings.NewReader(string(out)))
					ready_nodes := make(map[string]string)
					for scanner.Scan() {
						entry := strings.Fields(scanner.Text())
						ready_nodes[entry[0]] = entry[1]
					}
					if ready_nodes[fmt.Sprintf("master-%v", c)] != "" {
						fmt.Printf("Ready\tmaster-%v \t  %v\n", c, ip)
					} else {
						fmt.Printf("NotReady\tmaster-%v \t (%v)\n", c, ip)
					}
					if config.Platform == "ocp4" {
						if ready_nodes["url"] != "" {
							fmt.Printf("  URL: %v \n", ready_nodes["url"])
						} else {
							fmt.Printf("  OCP4 URL not yet available\n")
						}
						if ready_nodes["cred"] != "" {
							fmt.Printf("  Credentials: kubeadmin / %v \n", ready_nodes["cred"])
						} else {
							fmt.Printf("  OCP4 credentials not yet available\n")
						}
					}
					for n := 1; n <= Nodes; n++ {
						if ready_nodes[fmt.Sprintf("node-%v-%v", c, n)] != "" {
							fmt.Printf("Ready\t node-%v-%v\n", c, n)
						} else {
							fmt.Printf("NotReady\t node-%v-%v\n", c, n)
						}
					}
				}
			}
			//			} else {
			//				ip := get_ip(statusName)
			//				c := `
			//        masters=$(grep master /etc/hosts | cut -f 2 -d " ")
			//        for m in $masters; do
			//          ip=$(sudo ssh -oStrictHostKeyChecking=no $m "curl http://ipinfo.io/ip" 2>/dev/null)
			//          hostname=$(sudo ssh -oStrictHostKeyChecking=no $m "curl http://ipinfo.io/hostname" 2>/dev/null)
			//          echo $m $ip $hostname
			//        done`
			//				syscall.Exec("/usr/bin/ssh", []string{"ssh", "-q", "-oStrictHostKeyChecking=no", "-i", "keys/id_rsa." + config.Cloud + "." + config.Name, "root@" + ip, c}, []string{})
			//			}
		},
	}

	cmdCompletion := &cobra.Command{
		Use:   "completion",
		Short: "Generates bash completion scripts",
		Long: `To load completion run

  . <(px-deploy completion)`,
		Run: func(cmd *cobra.Command, args []string) {
			rootCmd.GenBashCompletion(os.Stdout)
		},
	}

	cmdVsphereInit := &cobra.Command{
		Use:   "vsphere-init",
		Short: "Creates vSphere template",
		Long:  "Creates vSphere template",
		Run: func(cmd *cobra.Command, args []string) {
			vsphere_init()
		},
	}

	cmdVsphereCheckTemplateVersion := &cobra.Command{
		Use:   "vsphere-check-template",
		Short: "Checks version of vSphere template",
		Long:  "Checks version of vSphere template",
		Run: func(cmd *cobra.Command, args []string) {
			vsphere_check_templateversion(statusName)
		},
	}

	cmdVersion := &cobra.Command{
		Use:   "version",
		Short: "Displays version",
		Long:  "Displays version",
		Run: func(cmd *cobra.Command, args []string) {
			version()
		},
	}

	cmdHistory := &cobra.Command{
		Use:   "history [ -n <ID> ]",
		Short: "Displays history or inspects historical deployment",
		Long:  "Displays history or inspects historical deployment",
		Run: func(cmd *cobra.Command, args []string) {
			history(historyNumber)
		},
	}

	defaults := parse_yaml("defaults.yml")
	cmdCreate.Flags().StringVarP(&createName, "name", "n", "", "name of deployment to be created (if blank, generate UUID)")
	cmdCreate.Flags().StringVarP(&createPlatform, "platform", "p", "", "k8s | dockeree | none | k3s | ocp4 | eks | gke | aks | nomad (default "+defaults.Platform+")")
	cmdCreate.Flags().StringVarP(&createClusters, "clusters", "c", "", "number of clusters to be deployed (default "+defaults.Clusters+")")
	cmdCreate.Flags().StringVarP(&createNodes, "nodes", "N", "", "number of nodes to be deployed in each cluster (default "+defaults.Nodes+")")
	cmdCreate.Flags().StringVarP(&createK8sVer, "k8s_version", "k", "", "Kubernetes version to be deployed (default "+defaults.K8s_Version+")")
	cmdCreate.Flags().StringVarP(&createPxVer, "px_version", "P", "", "Portworx version to be deployed (default "+defaults.Px_Version+")")
	cmdCreate.Flags().StringVarP(&createStopAfter, "stop_after", "s", "", "Stop instances after this many hours (default "+defaults.Stop_After+")")
	cmdCreate.Flags().StringVarP(&createAwsType, "aws_type", "", "", "AWS type for each node (default "+defaults.Aws_Type+")")
	cmdCreate.Flags().StringVarP(&createAwsEbs, "aws_ebs", "", "", "space-separated list of EBS volumes to be attached to worker nodes, eg \"gp2:20 standard:30\" (default "+defaults.Aws_Ebs+")")
	cmdCreate.Flags().StringVarP(&createAwsAccessKeyId, "aws_access_key_id", "", "", "your AWS API access key id (default \""+defaults.Aws_Access_Key_Id+"\")")
	cmdCreate.Flags().StringVarP(&createAwsSecretAccessKey, "aws_secret_access_key", "", "", "your AWS API secret access key (default \""+defaults.Aws_Secret_Access_Key+"\")")
	cmdCreate.Flags().StringVarP(&createTags, "tags", "", "", "comma-separated list of tags to be applies to cloud nodes, eg \"Owner=Bob,Purpose=Demo\"")
	cmdCreate.Flags().StringVarP(&createGcpType, "gcp_type", "", "", "GCP type for each node (default "+defaults.Gcp_Type+")")
	cmdCreate.Flags().StringVarP(&createGcpProject, "gcp_project", "", "", "GCP Project")
	cmdCreate.Flags().StringVarP(&createGcpDisks, "gcp_disks", "", "", "space-separated list of EBS volumes to be attached to worker nodes, eg \"pd-standard:20 pd-ssd:30\" (default "+defaults.Gcp_Disks+")")
	cmdCreate.Flags().StringVarP(&createGcpZone, "gcp_zone", "", defaults.Gcp_Zone, "GCP zone (a, b or c)")
	cmdCreate.Flags().StringVarP(&createAksVersion, "aks_version", "", "", "AKS Version (default "+defaults.Aks_Version+")")
	cmdCreate.Flags().StringVarP(&createAksVersion, "eks_version", "", "", "EKS Version (default "+defaults.Eks_Version+")")
	cmdCreate.Flags().StringVarP(&createAzureType, "azure_type", "", "", "Azure type for each node (default "+defaults.Azure_Type+")")
	cmdCreate.Flags().StringVarP(&createAzureClientSecret, "azure_client_secret", "", "", "Azure Client Secret (default "+defaults.Azure_Client_Secret+")")
	cmdCreate.Flags().StringVarP(&createAzureClientId, "azure_client_id", "", "", "Azure client ID (default "+defaults.Azure_Client_Id+")")
	cmdCreate.Flags().StringVarP(&createAzureTenantId, "azure_tenant_id", "", "", "Azure tenant ID (default "+defaults.Azure_Tenant_Id+")")
	cmdCreate.Flags().StringVarP(&createAzureSubscriptionId, "azure_subscription_id", "", "", "Azure subscription ID (default "+defaults.Azure_Subscription_Id+")")
	cmdCreate.Flags().StringVarP(&createAzureDisks, "azure_disks", "", "", "space-separated list of Azure disks to be attached to worker nodes, eg \"Standard_LRS:20 Premium_LRS:30\" (default "+defaults.Azure_Disks+")")
	cmdCreate.Flags().StringVarP(&createTemplate, "template", "t", "", "name of template to be deployed")
	cmdCreate.Flags().StringVarP(&createRegion, "region", "r", "", "AWS, GCP or Azure region (default "+defaults.Aws_Region+", "+defaults.Gcp_Region+" or "+defaults.Azure_Region+")")
	cmdCreate.Flags().StringVarP(&createCloud, "cloud", "C", "", "aws | gcp | azure | vsphere (default "+defaults.Cloud+")")
	cmdCreate.Flags().StringVarP(&createSshPubKey, "ssh_pub_key", "", "", "ssh public key which will be added for root access on each node")
	cmdCreate.Flags().StringVarP(&createEnv, "env", "e", "", "Comma-separated list of environment variables to be passed, for example foo=bar,abc=123")
	cmdCreate.Flags().BoolVarP(&createQuiet, "quiet", "q", false, "hide provisioning output")
	cmdCreate.Flags().BoolVarP(&createDryRun, "dry_run", "d", false, "dry-run, create local files only. Works only on aws / azure")

	cmdDestroy.Flags().BoolVarP(&destroyAll, "all", "a", false, "destroy all deployments")
	cmdDestroy.Flags().BoolVarP(&destroyClear, "clear", "c", false, "destroy local deployment files (use with caution!)")
	cmdDestroy.Flags().StringVarP(&destroyName, "name", "n", "", "name of deployment to be destroyed")

	cmdConnect.Flags().StringVarP(&connectName, "name", "n", "", "name of deployment to connect to")
	cmdConnect.MarkFlagRequired("name")
	cmdKubeconfig.Flags().StringVarP(&kubeconfigName, "name", "n", "", "name of deployment to connect to")
	cmdKubeconfig.MarkFlagRequired("name")

	cmdStatus.Flags().StringVarP(&statusName, "name", "n", "", "name of deployment")
	cmdStatus.MarkFlagRequired("name")

	cmdVsphereCheckTemplateVersion.Flags().StringVarP(&statusName, "name", "n", "", "name of deployment")
	cmdVsphereCheckTemplateVersion.MarkFlagRequired("name")

	cmdHistory.Flags().StringVarP(&historyNumber, "number", "n", "", "deployment ID")

	rootCmd.AddCommand(cmdCreate, cmdDestroy, cmdConnect, cmdKubeconfig, cmdList, cmdTemplates, cmdStatus, cmdCompletion, cmdVsphereInit, cmdVsphereCheckTemplateVersion, cmdVersion, cmdHistory)
	rootCmd.Execute()
}

func create_deployment(config Config) int {
	var output []byte
	var err error
	var errapply error

	var pxduser string

	var tf_variables []string
	var tf_variables_ocp4 []string
	var tf_variables_eks []string

	var tf_cluster_instance_type string
	var tf_var_ebs []string
	var tf_var_tags []string

	fmt.Println(White + "Provisioning infrastructure..." + Reset)
	switch config.Cloud {
	case "aws":
		{
			// create directory for deployment and copy terraform scripts
			err = os.Mkdir("/px-deploy/.px-deploy/tf-deployments/"+config.Name, 0755)
			if err != nil {
				die(err.Error())
			}
			//maybe there is a better way to copy templates to working dir ?
			exec.Command("cp", "-a", `/px-deploy/terraform/aws/main.tf`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			exec.Command("cp", "-a", `/px-deploy/terraform/aws/variables.tf`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			exec.Command("cp", "-a", `/px-deploy/terraform/aws/cloud-init.tpl`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			exec.Command("cp", "-a", `/px-deploy/terraform/aws/aws-returns.tpl`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			// also copy terraform modules
			//exec.Command("cp", "-a", `/px-deploy/terraform/aws/.terraform`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			// creating symlink for .terraform as performance on mac significantly improves when not on bind mount issue #397
			exec.Command("ln", "-s", `/px-deploy/terraform/aws/.terraform`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name+`/.terraform`).Run()
			exec.Command("cp", "-a", `/px-deploy/terraform/aws/.terraform.lock.hcl`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()

			switch config.Platform {
			case "ocp4":
				{
					exec.Command("cp", "-a", `/px-deploy/terraform/aws/ocp4/ocp4.tf`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
					exec.Command("cp", "-a", `/px-deploy/terraform/aws/ocp4/ocp4-install-config.tpl`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
				}
			case "eks":
				{
					exec.Command("cp", "-a", `/px-deploy/terraform/aws/eks/eks.tf`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
					exec.Command("cp", "-a", `/px-deploy/terraform/aws/eks/eks_run_everywhere.tpl`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
				}
			}

			write_nodescripts(config)

			// create EBS definitions
			// split ebs definition by spaces and range the results

			ebs := strings.Fields(config.Aws_Ebs)
			for i, val := range ebs {
				// split by : and create common .tfvars entry for all nodes
				entry := strings.Split(val, ":")
				tf_var_ebs = append(tf_var_ebs, "      {\n        ebs_type = \""+entry[0]+"\"\n        ebs_size = \""+entry[1]+"\"\n        ebs_device_name = \"/dev/sd"+string(i+98)+"\"\n      },")
			}
			// other node ebs processing happens in cluster/node loop

			// AWS default tagging
			tf_var_tags = append(tf_var_tags, "aws_tags = {")

			if config.Tags != "" {
				tags := strings.Split(config.Tags, ",")
				for _, val := range tags {
					entry := strings.Split(val, "=")
					tf_var_tags = append(tf_var_tags, "  "+strings.TrimSpace(entry[0])+" = \""+strings.TrimSpace(entry[1])+"\"")
				}
			}
			// get PXDUSER env and apply to tf_variables
			pxduser = os.Getenv("PXDUSER")
			if pxduser != "" {
				tf_var_tags = append(tf_var_tags, "  px-deploy_username = \""+pxduser+"\"")
			} else {
				tf_var_tags = append(tf_var_tags, "  px-deploy_username = \"unknown\"")
			}
			tf_var_tags = append(tf_var_tags, "  px-deploy_name = \""+config.Name+"\"")
			tf_var_tags = append(tf_var_tags, "}\n")

			switch config.Platform {
			case "ocp4":
				{
					tf_variables = append(tf_variables, "ocp4_nodes = \""+config.Nodes+"\"")
					config.Nodes = "0"
				}
			case "eks":
				{
					tf_variables = append(tf_variables, "eks_nodes = \""+config.Nodes+"\"")
					tf_variables = append(tf_variables, "eks_version = \""+config.Eks_Version+"\"")
					config.Nodes = "0"
					if config.Env["run_everywhere"] != "" {
						tf_variables = append(tf_variables, "run_everywhere = \""+strings.Replace(config.Env["run_everywhere"], "'", "\\\"", -1)+"\"")
					}
				}
			}

			Clusters, err := strconv.Atoi(config.Clusters)
			Nodes, err := strconv.Atoi(config.Nodes)

			// build terraform variable file
			tf_variables = append(tf_variables, "config_name = \""+config.Name+"\"")
			tf_variables = append(tf_variables, "clusters = "+config.Clusters)
			tf_variables = append(tf_variables, "aws_region = \""+config.Aws_Region+"\"")
			tf_variables = append(tf_variables, "aws_access_key_id = \""+config.Aws_Access_Key_Id+"\"")
			tf_variables = append(tf_variables, "aws_secret_access_key = \""+config.Aws_Secret_Access_Key+"\"")

			switch config.Platform {
			case "ocp4":
				{
					tf_variables = append(tf_variables, "ocp4_domain = \""+config.Ocp4_Domain+"\"")
					tf_variables = append(tf_variables, "ocp4_pull_secret = \""+base64.StdEncoding.EncodeToString([]byte(config.Ocp4_Pull_Secret))+"\"")
					tf_variables_ocp4 = append(tf_variables_ocp4, "ocp4clusters = {")
				}
			case "eks":
				{
					tf_variables_eks = append(tf_variables_eks, "eksclusters = {")
				}
			}

			tf_variables = append(tf_variables, "nodeconfig = [")

			// loop clusters (masters and nodes) to build tfvars and master/node scripts
			for c := 1; c <= Clusters; c++ {
				masternum := strconv.Itoa(c)
				tf_cluster_instance_type = config.Aws_Type

				// if exist, apply individual scripts/aws_type settings for nodes of a cluster
				for _, clusterconf := range config.Cluster {
					if clusterconf.Id == c {
						//is there a cluster specific aws_type override? if not, set from generic config
						if clusterconf.Instance_Type != "" {
							tf_cluster_instance_type = clusterconf.Instance_Type
						}
					}
				}

				// process .tfvars file for deployment
				tf_variables = append(tf_variables, "  {")
				tf_variables = append(tf_variables, "    role = \"master\"")
				tf_variables = append(tf_variables, "    ip_start = 89")
				tf_variables = append(tf_variables, "    nodecount = 1")
				tf_variables = append(tf_variables, "    instance_type = \"t3.large\"")
				tf_variables = append(tf_variables, "    cluster = "+masternum)
				tf_variables = append(tf_variables, "    ebs_block_devices = [] ")
				tf_variables = append(tf_variables, "  },")

				tf_variables = append(tf_variables, "  {")
				tf_variables = append(tf_variables, "    role = \"node\"")
				tf_variables = append(tf_variables, "    ip_start = 100")
				tf_variables = append(tf_variables, "    nodecount = "+strconv.Itoa(Nodes))
				tf_variables = append(tf_variables, "    instance_type = \""+tf_cluster_instance_type+"\"")
				tf_variables = append(tf_variables, "    cluster = "+masternum)
				tf_variables = append(tf_variables, "    ebs_block_devices = [")
				tf_variables = append(tf_variables, tf_var_ebs...)
				tf_variables = append(tf_variables, "    ]\n  },")

				switch config.Platform {
				case "ocp4":
					{
						tf_variables_ocp4 = append(tf_variables_ocp4, "  \""+masternum+"\" = \""+tf_cluster_instance_type+"\",")
					}
				case "eks":
					{
						tf_variables_eks = append(tf_variables_eks, "  \""+masternum+"\" = \""+tf_cluster_instance_type+"\",")
					}
				}
			}
			tf_variables = append(tf_variables, "]")

			switch config.Platform {
			case "ocp4":
				{
					tf_variables_ocp4 = append(tf_variables_ocp4, "}")
					tf_variables = append(tf_variables, tf_variables_ocp4...)
				}
			case "eks":
				{
					tf_variables_eks = append(tf_variables_eks, "}")
					tf_variables = append(tf_variables, tf_variables_eks...)
				}
			}
			tf_variables = append(tf_variables, tf_var_tags...)
			write_tf_file(config.Name, ".tfvars", tf_variables)
			// now run terraform plan & terraform apply
			fmt.Println(White + "running terraform PLAN" + Reset)
			cmd := exec.Command("terraform", "-chdir=/px-deploy/.px-deploy/tf-deployments/"+config.Name, "plan", "-input=false", "-parallelism=50", "-out=tfplan", "-var-file", ".tfvars")
			cmd.Stderr = os.Stderr
			err = cmd.Run()
			if err != nil {
				fmt.Println(Yellow + "ERROR: terraform plan failed. Check validity of terraform scripts" + Reset)
				die(err.Error())
			} else {
				if config.Dry_Run == "true" {
					fmt.Printf("Dry run only. No deployment on target cloud. Run 'px-deploy destroy -n %s' to remove local files\n", config.Name)
					die("Exit")
				}
				fmt.Println(White + "running terraform APPLY" + Reset)
				cmd := exec.Command("terraform", "-chdir=/px-deploy/.px-deploy/tf-deployments/"+config.Name, "apply", "-input=false", "-parallelism=50", "-auto-approve", "tfplan")
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr
				errapply = cmd.Run()
				if errapply != nil {
					fmt.Println(Yellow + "ERROR: terraform apply failed. Check validity of terraform scripts" + Reset)
					die(errapply.Error())
				}

				// apply the terraform aws-returns-generated to deployment yml file (maintains compatibility to px-deploy behaviour, maybe not needed any longer)
				content, err := ioutil.ReadFile("/px-deploy/.px-deploy/tf-deployments/" + config.Name + "/aws-returns-generated.yaml")
				file, err := os.OpenFile("/px-deploy/.px-deploy/deployments/"+config.Name+".yml", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
				if err != nil {
					die(err.Error())
				}
				defer file.Close()
				_, err = file.WriteString(string(content))
				if err != nil {
					die(err.Error())
				}
				fmt.Println(Yellow + "Terraform infrastructure creation done. Please check master/node readiness/credentials using: px-deploy status -n " + config.Name + Reset)
			}
		}
	case "gcp":
		{
			// create directory for deployment and copy terraform scripts
			err = os.Mkdir("/px-deploy/.px-deploy/tf-deployments/"+config.Name, 0755)
			if err != nil {
				die(err.Error())
			}
			//maybe there is a better way to copy templates to working dir ?
			exec.Command("cp", "-a", `/px-deploy/terraform/gcp/main.tf`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			exec.Command("cp", "-a", `/px-deploy/terraform/gcp/variables.tf`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			exec.Command("cp", "-a", `/px-deploy/terraform/gcp/startup-script.tpl`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			exec.Command("cp", "-a", `/px-deploy/terraform/gcp/gcp-returns.tpl`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()

			// also copy terraform modules
			//exec.Command("cp", "-a", `/px-deploy/terraform/gcp/.terraform`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			// creating symlink for .terraform as performance on mac significantly improves when not on bind mount issue #397
			exec.Command("ln", "-s", `/px-deploy/terraform/gcp/.terraform`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name+`/.terraform`).Run()
			exec.Command("cp", "-a", `/px-deploy/terraform/gcp/.terraform.lock.hcl`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()

			switch config.Platform {
			case "gke":
				{
					exec.Command("cp", "-a", `/px-deploy/terraform/gcp/gke/gke.tf`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
				}
			}

			write_nodescripts(config)

			write_tf_file(config.Name, ".tfvars", gcp_create_variables(&config))
			// now run terraform plan & terraform apply
			fmt.Println(White + "running terraform PLAN" + Reset)
			cmd := exec.Command("terraform", "-chdir=/px-deploy/.px-deploy/tf-deployments/"+config.Name, "plan", "-input=false", "-parallelism=50", "-out=tfplan", "-var-file", ".tfvars")
			cmd.Stderr = os.Stderr
			err = cmd.Run()
			if err != nil {
				fmt.Println(Yellow + "ERROR: terraform plan failed. Check validity of terraform scripts" + Reset)
				die(err.Error())
			} else {
				if config.Dry_Run == "true" {
					fmt.Printf("Dry run only. No deployment on target cloud. Run 'px-deploy destroy -n %s' to remove local files\n", config.Name)
					die("Exit")
				}
				fmt.Println(White + "running terraform APPLY" + Reset)
				cmd := exec.Command("terraform", "-chdir=/px-deploy/.px-deploy/tf-deployments/"+config.Name, "apply", "-input=false", "-parallelism=50", "-auto-approve", "tfplan")
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr
				errapply = cmd.Run()
				if errapply != nil {
					fmt.Println(Yellow + "ERROR: terraform apply failed. Check validity of terraform scripts" + Reset)
					die(errapply.Error())
				}

				// apply the terraform gcp-returns-generated to deployment yml file (network name needed for different functions)
				content, err := ioutil.ReadFile("/px-deploy/.px-deploy/tf-deployments/" + config.Name + "/gcp-returns-generated.yaml")
				file, err := os.OpenFile("/px-deploy/.px-deploy/deployments/"+config.Name+".yml", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
				if err != nil {
					die(err.Error())
				}
				defer file.Close()
				_, err = file.WriteString(string(content))
				if err != nil {
					die(err.Error())
				}

				fmt.Println(Yellow + "Terraform infrastructure creation done. Please check master/node readiness/credentials using: px-deploy status -n " + config.Name + Reset)
			}

		}
	case "azure":
		{
			// create directory for deployment and copy terraform scripts
			err = os.Mkdir("/px-deploy/.px-deploy/tf-deployments/"+config.Name, 0755)
			if err != nil {
				die(err.Error())
			}
			//maybe there is a better way to copy templates to working dir ?
			exec.Command("cp", "-a", `/px-deploy/terraform/azure/main.tf`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			exec.Command("cp", "-a", `/px-deploy/terraform/azure/variables.tf`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			exec.Command("cp", "-a", `/px-deploy/terraform/azure/cloud-init.tpl`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			// also copy terraform modules
			//exec.Command("cp", "-a", `/px-deploy/terraform/azure/.terraform`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			// creating symlink for .terraform as performance on mac significantly improves when not on bind mount issue #397
			exec.Command("ln", "-s", `/px-deploy/terraform/azure/.terraform`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name+`/.terraform`).Run()
			exec.Command("cp", "-a", `/px-deploy/terraform/azure/.terraform.lock.hcl`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()

			switch config.Platform {
			case "aks":
				{
					exec.Command("cp", "-a", `/px-deploy/terraform/azure/aks/aks.tf`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
					//exec.Command("cp", "-a", `/px-deploy/terraform/azure/aks/aks_run_everywhere.tpl`,`/px-deploy/.px-deploy/tf-deployments/`+ config.Name).Run()
				}
			}
			write_nodescripts(config)

			// create Azure Disks definitions
			// split Azure Disks definition by spaces and range the results

			ebs := strings.Fields(config.Azure_Disks)
			for _, val := range ebs {
				// split by : and create common .tfvars entry for all nodes
				entry := strings.Split(val, ":")
				tf_var_ebs = append(tf_var_ebs, "      {\n        type = \""+entry[0]+"\"\n        size = \""+entry[1]+"\"\n      },")
			}
			// other node ebs processing happens in cluster/node loop

			// set default tagging
			tf_var_tags = append(tf_var_tags, "azure_tags = {")

			if config.Tags != "" {
				tags := strings.Split(config.Tags, ",")
				for _, val := range tags {
					entry := strings.Split(val, "=")
					tf_var_tags = append(tf_var_tags, "  "+strings.TrimSpace(entry[0])+" = \""+strings.TrimSpace(entry[1])+"\"")
				}
			}
			// get PXDUSER env and apply to tf_variables
			pxduser = os.Getenv("PXDUSER")
			if pxduser != "" {
				tf_var_tags = append(tf_var_tags, "  px-deploy_username = \""+pxduser+"\"")
			} else {
				tf_var_tags = append(tf_var_tags, "  px-deploy_username = \"unknown\"")
			}
			tf_var_tags = append(tf_var_tags, "  px-deploy_name = \""+config.Name+"\"")
			tf_var_tags = append(tf_var_tags, "}\n")

			switch config.Platform {
			case "aks":
				{
					tf_variables = append(tf_variables, "aks_nodes = \""+config.Nodes+"\"")
					tf_variables = append(tf_variables, "aks_version = \""+config.Aks_Version+"\"")
					config.Nodes = "0"
					if config.Env["run_everywhere"] != "" {
						tf_variables = append(tf_variables, "run_everywhere = \""+strings.Replace(config.Env["run_everywhere"], "'", "\\\"", -1)+"\"")
					}
				}
			}

			Clusters, err := strconv.Atoi(config.Clusters)
			Nodes, err := strconv.Atoi(config.Nodes)

			// build terraform variable file
			tf_variables = append(tf_variables, "config_name = \""+config.Name+"\"")
			tf_variables = append(tf_variables, "clusters = "+config.Clusters)
			tf_variables = append(tf_variables, "azure_region = \""+config.Azure_Region+"\"")
			tf_variables = append(tf_variables, "azure_client_id = \""+config.Azure_Client_Id+"\"")
			tf_variables = append(tf_variables, "azure_client_secret = \""+config.Azure_Client_Secret+"\"")
			tf_variables = append(tf_variables, "azure_tenant_id = \""+config.Azure_Tenant_Id+"\"")
			tf_variables = append(tf_variables, "azure_subscription_id = \""+config.Azure_Subscription_Id+"\"")

			switch config.Platform {
			case "aks":
				{
					tf_variables_eks = append(tf_variables_eks, "aksclusters = {")
				}
			}

			tf_variables = append(tf_variables, "nodeconfig = [")

			// loop clusters (masters and nodes) to build tfvars and master/node scripts
			for c := 1; c <= Clusters; c++ {
				masternum := strconv.Itoa(c)
				tf_cluster_instance_type = config.Azure_Type

				// if exist, apply individual scripts/aws_type settings for nodes of a cluster
				for _, clusterconf := range config.Cluster {
					if clusterconf.Id == c {
						//is there a cluster specific aws_type override? if not, set from generic config
						if clusterconf.Instance_Type != "" {
							tf_cluster_instance_type = clusterconf.Instance_Type
						}
					}
				}

				// process .tfvars file for deployment
				tf_variables = append(tf_variables, "  {")
				tf_variables = append(tf_variables, "    role = \"master\"")
				tf_variables = append(tf_variables, "    ip_start = 89")
				tf_variables = append(tf_variables, "    nodecount = 1")
				tf_variables = append(tf_variables, "    instance_type = \""+config.Azure_Type+"\"")
				tf_variables = append(tf_variables, "    cluster = "+masternum)
				tf_variables = append(tf_variables, "    block_devices = [] ")
				tf_variables = append(tf_variables, "  },")

				tf_variables = append(tf_variables, "  {")
				tf_variables = append(tf_variables, "    role = \"node\"")
				tf_variables = append(tf_variables, "    ip_start = 100")
				tf_variables = append(tf_variables, "    nodecount = "+strconv.Itoa(Nodes))
				tf_variables = append(tf_variables, "    instance_type = \""+tf_cluster_instance_type+"\"")
				tf_variables = append(tf_variables, "    cluster = "+masternum)
				tf_variables = append(tf_variables, "    block_devices = [")
				tf_variables = append(tf_variables, tf_var_ebs...)
				tf_variables = append(tf_variables, "    ]\n  },")

				switch config.Platform {
				case "aks":
					{
						tf_variables_eks = append(tf_variables_eks, "  \""+masternum+"\" = \""+tf_cluster_instance_type+"\",")
					}
				}

			}
			tf_variables = append(tf_variables, "]")

			switch config.Platform {
			case "aks":
				{
					tf_variables_eks = append(tf_variables_eks, "}")
					tf_variables = append(tf_variables, tf_variables_eks...)
				}
			}

			tf_variables = append(tf_variables, tf_var_tags...)
			write_tf_file(config.Name, ".tfvars", tf_variables)
			// now run terraform plan & terraform apply
			fmt.Println(White + "running terraform PLAN" + Reset)
			cmd := exec.Command("terraform", "-chdir=/px-deploy/.px-deploy/tf-deployments/"+config.Name, "plan", "-input=false", "-out=tfplan", "-var-file", ".tfvars")
			cmd.Stderr = os.Stderr
			err = cmd.Run()
			if err != nil {
				fmt.Println(Yellow + "ERROR: terraform plan failed. Check validity of terraform scripts" + Reset)
				die(err.Error())
			} else {
				if config.Dry_Run == "true" {
					fmt.Printf("Dry run only. No deployment on target cloud. Run 'px-deploy destroy -n %s' to remove local files\n", config.Name)
					die("Exit")
				}
				fmt.Println(White + "running terraform APPLY" + Reset)
				cmd := exec.Command("terraform", "-chdir=/px-deploy/.px-deploy/tf-deployments/"+config.Name, "apply", "-input=false", "-auto-approve", "tfplan")
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr
				errapply = cmd.Run()
				if errapply != nil {
					fmt.Println(Yellow + "ERROR: terraform apply failed. Check validity of terraform scripts" + Reset)
					die(errapply.Error())
				}
				/* do we still need
						// apply the terraform aws-returns-generated to deployment yml file (maintains compatibility to px-deploy behaviour, maybe not needed any longer)
						content, err := ioutil.ReadFile("/px-deploy/.px-deploy/tf-deployments/"+config.Name+"/aws-returns-generated.yaml")
						file,err := os.OpenFile("/px-deploy/.px-deploy/deployments/" + config.Name+".yml", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
						if err != nil {
							die(err.Error())
				  		}
				  		defer file.Close()
						_, err = file.WriteString(string(content))
				  		if err != nil {
							die(err.Error())
						}
				*/
				fmt.Println(Yellow + "Terraform infrastructure creation done. Please check master/node readiness/credentials using: px-deploy status -n " + config.Name + Reset)
			}

		}
	case "vsphere":
		{
			// create directory for deployment and copy terraform scripts
			err = os.Mkdir("/px-deploy/.px-deploy/tf-deployments/"+config.Name, 0755)
			if err != nil {
				die(err.Error())
			}
			//maybe there is a better way to copy templates to working dir ?
			exec.Command("cp", "-a", `/px-deploy/terraform/vsphere/main.tf`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			exec.Command("cp", "-a", `/px-deploy/terraform/vsphere/variables.tf`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			exec.Command("cp", "-a", `/px-deploy/terraform/vsphere/cloud-init.tpl`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			exec.Command("cp", "-a", `/px-deploy/terraform/vsphere/metadata.tpl`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()

			// also copy terraform modules
			//exec.Command("cp", "-a", `/px-deploy/terraform/gcp/.terraform`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()
			// creating symlink for .terraform as performance on mac significantly improves when not on bind mount issue #397
			exec.Command("ln", "-s", `/px-deploy/terraform/vsphere/.terraform`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name+`/.terraform`).Run()
			exec.Command("cp", "-a", `/px-deploy/terraform/vsphere/.terraform.lock.hcl`, `/px-deploy/.px-deploy/tf-deployments/`+config.Name).Run()

			write_nodescripts(config)

			write_tf_file(config.Name, ".tfvars", vsphere_create_variables(&config))
			// now run terraform plan & terraform apply
			fmt.Println(White + "running terraform PLAN" + Reset)
			cmd := exec.Command("terraform", "-chdir=/px-deploy/.px-deploy/tf-deployments/"+config.Name, "plan", "-input=false", "-parallelism=50", "-out=tfplan", "-var-file", ".tfvars")
			cmd.Stderr = os.Stderr
			err = cmd.Run()
			if err != nil {
				fmt.Println(Yellow + "ERROR: terraform plan failed. Check validity of terraform scripts" + Reset)
				die(err.Error())
			} else {
				if config.Dry_Run == "true" {
					fmt.Printf("Dry run only. No deployment on target cloud. Run 'px-deploy destroy -n %s' to remove local files\n", config.Name)
					die("Exit")
				}
				fmt.Println(White + "running terraform APPLY" + Reset)
				cmd := exec.Command("terraform", "-chdir=/px-deploy/.px-deploy/tf-deployments/"+config.Name, "apply", "-input=false", "-parallelism=50", "-auto-approve", "tfplan")
				cmd.Stdout = os.Stdout
				cmd.Stderr = os.Stderr
				errapply = cmd.Run()
				if errapply != nil {
					fmt.Println(Yellow + "ERROR: terraform apply failed. Check validity of terraform scripts" + Reset)
					die(errapply.Error())
				}

				// apply the terraform nodemap.txt to deployment yml file (list of VM name / VM mobId / mac address)
				readFile, err := os.Open("/px-deploy/.px-deploy/tf-deployments/" + config.Name + "/nodemap.txt")
				if err != nil {
					die(err.Error())
				}
				fileScanner := bufio.NewScanner(readFile)
				fileScanner.Split(bufio.ScanLines)
				var fileLines []string
				fileLines = append(fileLines, "vsphere_nodemap:\n")

				for fileScanner.Scan() {
					fileLines = append(fileLines, fmt.Sprintf("  %s\n", strings.TrimSpace(fileScanner.Text())))
				}
				readFile.Close()

				file, err := os.OpenFile("/px-deploy/.px-deploy/deployments/"+config.Name+".yml", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
				if err != nil {
					die(err.Error())
				}
				defer file.Close()

				for _, line := range fileLines {
					_, err = file.WriteString(line)
					if err != nil {
						die(err.Error())
					}
				}
				fmt.Println(Yellow + "Terraform infrastructure creation done. Please check master/node readiness/credentials using: px-deploy status -n " + config.Name + Reset)
				vsphere_check_templateversion(config.Name)
			}

		}
	default:
		die("Invalid cloud '" + config.Cloud + "'")
	}
	if config.Quiet != "true" {
		fmt.Print(string(output))
	}
	if err != nil {
		return 1
	}
	return 0
}

func destroy_clear(name string) {
	os.Chdir("/px-deploy/.px-deploy")
	config := parse_yaml("deployments/" + name + ".yml")

	fmt.Println(Yellow + "Deleting local files for deployment " + name)
	fmt.Println("If there is any deployment in cloud " + config.Cloud + " you need to remove manually now" + Reset)

	os.Chdir("/px-deploy/.px-deploy")
	os.Remove("deployments/" + name + ".yml")
	os.RemoveAll("tf-deployments/" + name)
	os.Remove("keys/id_rsa." + config.Cloud + "." + name)
	os.Remove("keys/id_rsa." + config.Cloud + "." + name + ".pub")

	clusters, _ := strconv.Atoi(config.Clusters)
	for c := 0; c <= clusters; c++ {
		os.Remove("kubeconfig/" + name + "." + strconv.Itoa(c))
	}
}

func destroy_deployment(name string) {
	os.Chdir("/px-deploy/.px-deploy")
	config := parse_yaml("deployments/" + name + ".yml")
	var output []byte
	var err error
	var errdestroy error

	fmt.Println(White + "Destroying deployment '" + config.Name + "'..." + Reset)
	if config.Cloud == "aws" {
		if _, err := os.Stat("/px-deploy/.px-deploy/tf-deployments/" + config.Name); os.IsNotExist(err) {
			fmt.Println("Terraform Config for AWS deployment missing. If this has been created with a px-deploy Version <5.0.0 you need to destroy with the older version")
			die("Error: outdated deployment")
		}

		cfg := aws_load_config(&config)
		client := aws_connect_ec2(&config, &cfg)

		aws_instances, err := aws_get_instances(&config, client)
		if err != nil {
			panic(fmt.Sprintf("error listing aws instances %v \n", err.Error()))
		}

		// split aws_instances into chunks of 197 elements
		// because of the aws DescribeVolumes Filter limit of 200 (197 instances + pxtype: data/kvdb/journal)
		// build slice of slices
		aws_instances_split := make([]([]string), len(aws_instances)/197+1)
		for i, val := range aws_instances {
			aws_instances_split[i/197] = append(aws_instances_split[i/197], val)
		}

		aws_volumes, err := aws_get_clouddrives(aws_instances_split, &config, client)
		if err != nil {
			panic(fmt.Sprintf("error listing aws clouddrives %v \n", err.Error()))
		}

		fmt.Printf("Found %d portworx clouddrive volumes. \n", len(aws_volumes))

		switch config.Platform {
		case "ocp4":
			{

				clusters, _ := strconv.Atoi(config.Clusters)
				fmt.Println("Running pre-delete scripts on all master nodes. Output is mixed")
				for i := 1; i <= clusters; i++ {
					wg.Add(1)
					go run_predelete(&config, fmt.Sprintf("master-%v-1", i), "script")
				}
				wg.Wait()
				fmt.Println("pre-delete scripts done")

				fmt.Println(White + "Destroying OCP4 cluster(s), wait about 5 minutes (per cluster)... Output is mixed" + Reset)
				for i := 1; i <= clusters; i++ {
					wg.Add(1)
					go run_predelete(&config, fmt.Sprintf("master-%v-1", i), "platform")
				}
				wg.Wait()
				fmt.Println("OCP4 cluster delete done")
			}
		case "eks":
			{
				clusters, _ := strconv.Atoi(config.Clusters)

				fmt.Println("Running pre-delete scripts on all master nodes. Output will be mixed")
				for i := 1; i <= clusters; i++ {
					wg.Add(1)
					go run_predelete(&config, fmt.Sprintf("master-%v-1", i), "script")
				}
				wg.Wait()
				fmt.Println("pre-delete scripts done")

				err := aws_delete_nodegroups(&config)
				if err != nil {
					panic(fmt.Sprintf("error deleting eks nodegroups %v \n", err.Error()))
				}

			}
		default:
			{
				// if there are no px clouddrive volumes
				// terraform will terminate instances
				// otherwise terminate instances to enable volume deletion
				clusters, _ := strconv.Atoi(config.Clusters)
				fmt.Println("Running pre-delete scripts on all master nodes. Output will be mixed")
				for i := 1; i <= clusters; i++ {
					wg.Add(1)
					go run_predelete(&config, fmt.Sprintf("master-%v-1", i), "script")
				}
				wg.Wait()
				fmt.Println("pre-delete scripts done")

				if len(aws_volumes) > 0 {
					fmt.Printf("Waiting for termination of %v instances: (timeout 5min) \n", len(aws_instances))
					// terminate instances in chunks of 197 to prevent API rate limiting
					for i := range aws_instances_split {
						go terminate_ec2_instances(client, aws_instances_split[i])
						// create waiter for each instance
						for j := range aws_instances_split[i] {
							wg.Add(1)
							go wait_ec2_termination(client, aws_instances_split[i][j], 5)
						}

					}
					wg.Wait()
					fmt.Println("EC2 instances terminated")
				}
			}
		}

		// delete elb instances & attached SGs (+referncing rules) from VPC
		delete_elb_instances(config.Aws__Vpc, cfg)

		// at this point px clouddrive volumes must no longer be attached
		// as instances are terminated
		if len(aws_volumes) > 0 {
			fmt.Println(White + "Deleting px clouddrive volumes:" + Reset)
			for _, i := range aws_volumes {

				fmt.Println("  " + i)
				_, err = client.DeleteVolume(context.TODO(), &ec2.DeleteVolumeInput{
					VolumeId: aws.String(i),
				})
				if err != nil {
					fmt.Println("Error deleting Volume:")
					fmt.Println(err)
					return
				}
			}
		}

		fmt.Println(White + "running Terraform PLAN" + Reset)
		cmd := exec.Command("terraform", "-chdir=/px-deploy/.px-deploy/tf-deployments/"+config.Name, "plan", "-destroy", "-input=false", "-refresh=false", "-parallelism=50", "-out=tfplan", "-var-file", ".tfvars")
		cmd.Stderr = os.Stderr
		err = cmd.Run()
		if err != nil {
			fmt.Println(Red + "ERROR: Terraform plan failed. Check validity of terraform scripts" + Reset)
			die(err.Error())
		} else {
			fmt.Println(White + "running Terraform DESTROY" + Reset)
			cmd := exec.Command("terraform", "-chdir=/px-deploy/.px-deploy/tf-deployments/"+config.Name, "apply", "-input=false", "-parallelism=50", "-auto-approve", "tfplan")
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			errdestroy = cmd.Run()

			if errdestroy != nil {
				fmt.Println(Yellow + "ERROR: Terraform destroy failed. Check validity of terraform scripts" + Reset)
				die(errdestroy.Error())
			} else {
				os.RemoveAll("tf-deployments/" + config.Name)
			}
		}
		os.RemoveAll("deployments/" + name)
	} else if config.Cloud == "gcp" {
		drivelist := make(map[string]string)
		if _, err := os.Stat("/px-deploy/.px-deploy/tf-deployments/" + config.Name); os.IsNotExist(err) {
			fmt.Println("Terraform Config for GCP deployment missing. If this has been created with a px-deploy Version <5.3.0 you need to destroy with the older version")
			die("Error: outdated deployment")
		}

		clusters, _ := strconv.Atoi(config.Clusters)

		fmt.Println("Running pre-delete scripts on all master nodes. Output will be mixed")
		for i := 1; i <= clusters; i++ {
			wg.Add(1)
			go run_predelete(&config, fmt.Sprintf("%v-master-%v-1", config.Name, i), "script")
		}
		wg.Wait()
		fmt.Println("pre-delete scripts done")

		instances, err := gcp_get_instances(config.Name, &config)
		if err != nil {
			die("error listing gcp instances")
		}

		wg := new(sync.WaitGroup)
		fmt.Printf("checking for px clouddrives \n")

		for _, val := range instances {
			drives, err := gcp_get_clouddrives(val, &config)
			if err != nil {
				die("error getting clouddrive listing for instance " + val)
			}
			if len(drives) > 0 {
				for _, drive := range drives {
					drivelist[drive] = val
				}
				if config.Platform == "k8s" {
					fmt.Printf("\t waiting 2min for %v clouddrive-attached instance %v to stop \n", len(drives), val)
					wg.Add(1)
					go gcp_stop_wait_instance(val, &config, wg)
				}
			}
		}

		if config.Platform == "gke" {
			fmt.Printf("found %v px clouddrives \n", len(drivelist))
			clusters, _ := strconv.Atoi(config.Clusters)
			for c := 1; c <= clusters; c++ {
				nodepools, err := gcp_get_nodepools(&config, fmt.Sprintf("px-deploy-%v-%v", config.Name, c))
				if err != nil {
					fmt.Printf("Warning: error listing gke nodepools\n")
				}

				for _, n := range nodepools {
					fmt.Printf("  deleting nodepool '%v' of cluster 'px-deploy-%v-%v' (can take 5min or longer)\n", n, config.Name, c)
					wg.Add(1)
					go gcp_delete_wait_nodepools(&config, fmt.Sprintf("px-deploy-%v-%v", config.Name, c), n, wg)
				}
			}
		}

		wg.Wait()

		if len(drivelist) > 0 {
			fmt.Printf("all clouddrive-attached nodes stopped.\nstarting disk detach/delete (default timeout 2min)\n")
		}

		for drive, inst := range drivelist {

			switch config.Platform {
			case "k8s":
				{
					wg.Add(1)
					fmt.Printf("\t detach and delete drive %s from host %s\n", drive, inst)
					go gcp_detach_delete_wait_clouddrive(inst, drive, &config, wg)
				}
			case "gke":
				{
					wg.Add(1)
					fmt.Printf("\t deleting clouddrive %s \n", drive)
					go gcp_delete_wait_clouddrive(drive, &config, wg)
				}
			}
		}
		wg.Wait()

		fmt.Println(White + "running Terraform PLAN" + Reset)
		cmd := exec.Command("terraform", "-chdir=/px-deploy/.px-deploy/tf-deployments/"+config.Name, "plan", "-destroy", "-input=false", "-out=tfplan", "-var-file", ".tfvars")
		cmd.Stderr = os.Stderr
		err = cmd.Run()
		if err != nil {
			fmt.Println(Yellow + "ERROR: Terraform plan failed. Check validity of terraform scripts" + Reset)
			die(err.Error())
		} else {
			fmt.Println(White + "running Terraform DESTROY" + Reset)
			cmd := exec.Command("terraform", "-chdir=/px-deploy/.px-deploy/tf-deployments/"+config.Name, "apply", "-input=false", "-auto-approve", "tfplan")
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			errdestroy = cmd.Run()

			if errdestroy != nil {
				fmt.Println(Yellow + "ERROR: Terraform destroy failed. Check validity of terraform scripts" + Reset)
				die(errdestroy.Error())
			} else {
				os.RemoveAll("tf-deployments/" + config.Name)
			}
		}
		os.RemoveAll("deployments/" + name)

	} else if config.Cloud == "azure" {
		fmt.Println(White + "running Terraform PLAN" + Reset)
		cmd := exec.Command("terraform", "-chdir=/px-deploy/.px-deploy/tf-deployments/"+config.Name, "plan", "-destroy", "-input=false", "-out=tfplan", "-var-file", ".tfvars")
		cmd.Stderr = os.Stderr
		err = cmd.Run()
		if err != nil {
			fmt.Println(Yellow + "ERROR: Terraform plan failed. Check validity of terraform scripts" + Reset)
			die(err.Error())
		} else {
			fmt.Println(White + "running Terraform DESTROY" + Reset)
			cmd := exec.Command("terraform", "-chdir=/px-deploy/.px-deploy/tf-deployments/"+config.Name, "apply", "-input=false", "-auto-approve", "tfplan")
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			errdestroy = cmd.Run()

			if errdestroy != nil {
				fmt.Println(Yellow + "ERROR: Terraform destroy failed. Check validity of terraform scripts" + Reset)
				die(errdestroy.Error())
			} else {
				os.RemoveAll("tf-deployments/" + config.Name)
			}
		}
		os.RemoveAll("deployments/" + name)
	} else if config.Cloud == "vsphere" {

		clusters, _ := strconv.Atoi(config.Clusters)
		fmt.Println("Running pre-delete scripts on all master nodes. Output will be mixed")
		for i := 1; i <= clusters; i++ {
			wg.Add(1)
			go run_predelete(&config, fmt.Sprintf("%s-master-%v", config.Name, i), "script")
		}
		wg.Wait()
		fmt.Println("pre-delete scripts done")

		vsphere_prepare_destroy(&config)

		fmt.Println(White + "running Terraform PLAN" + Reset)
		cmd := exec.Command("terraform", "-chdir=/px-deploy/.px-deploy/tf-deployments/"+config.Name, "plan", "-destroy", "-input=false", "-out=tfplan", "-var-file", ".tfvars")
		cmd.Stderr = os.Stderr
		err = cmd.Run()
		if err != nil {
			fmt.Println(Yellow + "ERROR: Terraform plan failed. Check validity of terraform scripts" + Reset)
			die(err.Error())
		} else {
			fmt.Println(White + "running Terraform DESTROY" + Reset)
			cmd := exec.Command("terraform", "-chdir=/px-deploy/.px-deploy/tf-deployments/"+config.Name, "apply", "-input=false", "-auto-approve", "tfplan")
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			errdestroy = cmd.Run()

			if errdestroy != nil {
				fmt.Println(Yellow + "ERROR: Terraform destroy failed. Check validity of terraform scripts" + Reset)
				die(errdestroy.Error())
			} else {
				os.RemoveAll("tf-deployments/" + config.Name)
			}
		}
		os.RemoveAll("deployments/" + name)
	} else {
		die("Bad cloud")
	}
	if err != nil {
		die("Failed to destroy")
	}
	fmt.Print(string(output))
	os.Remove("deployments/" + name + ".yml")
	os.Remove("keys/id_rsa." + config.Cloud + "." + name)
	os.Remove("keys/id_rsa." + config.Cloud + "." + name + ".pub")
	clusters, _ := strconv.Atoi(config.Clusters)
	for c := 0; c <= clusters; c++ {
		os.Remove("kubeconfig/" + name + "." + strconv.Itoa(c))
	}
	fmt.Println(White + "Destroyed." + Reset)
}

func azure_get_node_ip(deployment string, node string) string {
	config := parse_yaml("/px-deploy/.px-deploy/deployments/" + deployment + ".yml")
	var output = []byte("")

	cred, err := azidentity.NewClientSecretCredential(config.Azure_Tenant_Id, config.Azure_Client_Id, config.Azure_Client_Secret, nil)
	if err != nil {
		panic("failed to create azure credential" + err.Error())
	}

	ctx := context.Background()

	// Create and authorize a ResourceGraph client
	client, err := armresourcegraph.NewClient(cred, nil)
	if err != nil {
		panic("failed to create azure client: " + err.Error())
	}

	results, err := client.Resources(ctx,
		armresourcegraph.QueryRequest{
			Query: to.Ptr(fmt.Sprintf("Resources | where type =~ 'Microsoft.Network/publicIPAddresses' | where resourceGroup == 'px-deploy.%s' | where name == 'px-deploy.%s.%s' | limit 1", config.Name, config.Name, node)),
			Subscriptions: []*string{
				to.Ptr(config.Azure_Subscription_Id)},
		},
		nil)
	if err != nil {
		panic("failed to search azure public ip:" + err.Error())
	} else {
		// https://pkg.go.dev/github.com/Azure/azure-sdk-for-go/sdk/resourcemanager/resourcegraph/armresourcegraph#QueryResponse
		for _, value := range results.Data.([]interface{}) {
			//fmt.Printf("Data result %v, type %s \n\n", key, reflect.TypeOf(value))
			for field, result := range value.(map[string]interface{}) {
				if field == "properties" {
					for prop, prop_val := range result.(map[string]interface{}) {
						if prop == "ipAddress" {
							//fmt.Printf("  %v : %v\n", prop, prop_val)
							output = []byte(fmt.Sprint(prop_val))
						}
					}
				}
			}
		}
	}
	return strings.TrimSuffix(string(output), "\n")
}

// get node ip following old naming scheme (master-1)
// terraform based deployments changed naming to master-1-1
// this function can be replaced after all clouds run terraform based
func get_ip(deployment string) string {
	config := parse_yaml("/px-deploy/.px-deploy/deployments/" + deployment + ".yml")
	var output []byte
	if config.Cloud == "aws" {
		output = []byte(aws_get_node_ip(deployment, "master-1-1"))
	} else if config.Cloud == "gcp" {
		output = []byte(gcp_get_node_ip(deployment, config.Name+"-master-1-1"))
	} else if config.Cloud == "azure" {
		output = []byte(azure_get_node_ip(deployment, "master-1-1"))
	} else if config.Cloud == "vsphere" {
		output = []byte(vsphere_get_node_ip(&config, config.Name+"-master-1"))
	}
	return strings.TrimSuffix(string(output), "\n")
}

func run_predelete(config *Config, confNode string, confPath string) {
	var ip string

	defer wg.Done()

	switch config.Cloud {
	case "aws":
		{
			ip = aws_get_node_ip(config.Name, confNode)
		}
	case "gcp":
		{
			ip = gcp_get_node_ip(config.Name, confNode)
		}
	case "vsphere":
		{
			ip = vsphere_get_node_ip(config, confNode)
		}
	default:
		{
			panic(fmt.Sprintf("pre_delete not implemented for cloud %v", config.Cloud))
		}

	}
	fmt.Printf("Running pre-delete scripts on %v (%v)\n", confNode, ip)

	cmd := exec.Command("/usr/bin/ssh", "-oStrictHostKeyChecking=no", "-q", "-i", "keys/id_rsa."+config.Cloud+"."+config.Name, "root@"+ip, `
		for i in /px-deploy/`+confPath+`-delete/*.sh; do bash $i ;done; exit 0
	`)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err := cmd.Run()
	if err != nil {
		fmt.Println(Yellow + "Failed to run pre-delete script:" + err.Error() + Reset)
	}

}

// return which variables are empty
func isEmpty(vars ...interface{}) []int {
	emptyVars := []int{}
	for i, v := range vars {
		if v == nil || reflect.ValueOf(v).IsZero() {
			emptyVars = append(emptyVars, i)
		}
	}
	return emptyVars
}

func write_nodescripts(config Config) {
	var tf_node_scripts []string
	var tf_master_scripts []string
	var tf_common_master_script []byte
	var tf_post_script []byte
	var tf_node_script []byte
	var tf_individual_node_script []byte
	var tf_master_script []byte
	var tf_env_script []byte

	// prepare ENV variables for node/master scripts
	// to maintain compatibility, create a env variable of everything from the yml spec which is from type string
	e := reflect.ValueOf(&config).Elem()
	for i := 0; i < e.NumField(); i++ {
		if e.Type().Field(i).Type.Name() == "string" {
			tf_env_script = append(tf_env_script, "export "+strings.ToLower(strings.TrimSpace(e.Type().Field(i).Name))+"=\""+strings.TrimSpace(e.Field(i).Interface().(string))+"\"\n"...)
		}
	}

	// set env variables from env spec
	for key, val := range config.Env {
		tf_env_script = append(tf_env_script, "export "+key+"=\""+val+"\"\n"...)
	}
	err := os.WriteFile("/px-deploy/.px-deploy/tf-deployments/"+config.Name+"/env.sh", tf_env_script, 0666)
	if err != nil {
		die(err.Error())
	}

	// prepare (single) cloud-init script for all nodes
	tf_node_scripts = []string{"all-common", config.Platform + "-common", config.Platform + "-node"}
	tf_node_script = append(tf_node_script, "#!/bin/bash\n"...)

	tf_node_script = append(tf_node_script, "mkdir /var/log/px-deploy\n"...)

	for _, filename := range tf_node_scripts {
		content, err := ioutil.ReadFile("/px-deploy/vagrant/" + filename)
		if err == nil {
			tf_node_script = append(tf_node_script, "(\n"...)
			tf_node_script = append(tf_node_script, "echo \"Started $(date)\"\n"...)
			tf_node_script = append(tf_node_script, content...)
			tf_node_script = append(tf_node_script, "\necho \"Finished $(date)\"\n"...)
			tf_node_script = append(tf_node_script, "\n) >&/var/log/px-deploy/"+filename+"\n"...)
		}
	}

	// prepare common base script for all master nodes
	// prepare common cloud-init script for all master nodes
	tf_master_scripts = []string{"all-common", config.Platform + "-common", "all-master", config.Platform + "-master"}
	tf_common_master_script = append(tf_common_master_script, "#!/bin/bash\n"...)
	tf_common_master_script = append(tf_common_master_script, "mkdir /px-deploy\n"...)
	tf_common_master_script = append(tf_common_master_script, "mkdir /px-deploy/platform-delete\n"...)
	tf_common_master_script = append(tf_common_master_script, "mkdir /px-deploy/script-delete\n"...)
	tf_common_master_script = append(tf_common_master_script, "touch /px-deploy/script-delete/dummy.sh\n"...)
	tf_common_master_script = append(tf_common_master_script, "touch /px-deploy/platform-delete/dummy.sh\n"...)
	tf_common_master_script = append(tf_common_master_script, "mkdir /var/log/px-deploy\n"...)
	tf_common_master_script = append(tf_common_master_script, "mkdir /var/log/px-deploy/completed\n"...)
	tf_common_master_script = append(tf_common_master_script, "touch /var/log/px-deploy/completed/tracking\n"...)

	for _, filename := range tf_master_scripts {
		content, err := ioutil.ReadFile("/px-deploy/vagrant/" + filename)
		if err == nil {
			tf_common_master_script = append(tf_common_master_script, "(\n"...)
			tf_common_master_script = append(tf_common_master_script, "echo \"Started $(date)\"\n"...)
			tf_common_master_script = append(tf_common_master_script, content...)
			tf_common_master_script = append(tf_common_master_script, "\necho \"Finished $(date)\"\n"...)
			tf_common_master_script = append(tf_common_master_script, "\n) >&/var/log/px-deploy/"+filename+"\n"...)
		}
	}

	// add scripts from the "scripts" section of config.yaml to common master node script
	for _, filename := range config.Scripts {
		content, err := ioutil.ReadFile("/px-deploy/.px-deploy/scripts/" + filename)
		if err == nil {
			tf_common_master_script = append(tf_common_master_script, "(\n"...)
			tf_common_master_script = append(tf_common_master_script, "echo \"Started $(date)\"\n"...)
			tf_common_master_script = append(tf_common_master_script, content...)
			tf_common_master_script = append(tf_common_master_script, "\necho \"Finished $(date)\"\n"...)
			tf_common_master_script = append(tf_common_master_script, "\n) >&/var/log/px-deploy/"+filename+"\n"...)
		}
	}

	// add post_script if defined
	if config.Post_Script != "" {
		content, err := ioutil.ReadFile("/px-deploy/.px-deploy/scripts/" + config.Post_Script)
		if err == nil {
			tf_post_script = append(tf_post_script, "(\n"...)
			tf_post_script = append(tf_post_script, "echo \"Started $(date)\"\n"...)
			tf_post_script = append(tf_post_script, content...)
			tf_post_script = append(tf_post_script, "\necho \"Finished $(date)\"\n"...)
			tf_post_script = append(tf_post_script, "\n) >&/var/log/px-deploy/"+config.Post_Script+"\n"...)
		}
	} else {
		tf_post_script = nil
	}

	Clusters, err := strconv.Atoi(config.Clusters)
	Nodes, err := strconv.Atoi(config.Nodes)

	// loop clusters (masters and nodes) to build tfvars and master/node scripts
	for c := 1; c <= Clusters; c++ {
		masternum := strconv.Itoa(c)

		tf_master_script = tf_common_master_script

		// if exist, apply individual scripts/aws_type settings for nodes of a cluster
		for _, clusterconf := range config.Cluster {
			if clusterconf.Id == c {
				for _, filename := range clusterconf.Scripts {
					content, err := ioutil.ReadFile("/px-deploy/.px-deploy/scripts/" + filename)
					if err == nil {
						tf_master_script = append(tf_master_script, "(\n"...)
						tf_master_script = append(tf_master_script, content...)
						tf_master_script = append(tf_master_script, "\necho \"Finished $(date)\"\n"...)
						tf_master_script = append(tf_master_script, "\n) >&/var/log/px-deploy/"+filename+"\n"...)
					}
				}
			}
		}

		// add post_script if defined
		if tf_post_script != nil {
			tf_master_script = append(tf_master_script, tf_post_script...)
		}

		// after running all scripts create file in /var/log/px-deploy/completed
		tf_master_script = append(tf_master_script, "export IP=$(curl -s https://ipinfo.io/ip)\n"...)
		tf_master_script = append(tf_master_script, "echo \"master-"+masternum+" $IP \" >> /var/log/px-deploy/completed/tracking \n"...)

		//write master script for cluster
		err := os.WriteFile("/px-deploy/.px-deploy/tf-deployments/"+config.Name+"/master-"+masternum+"-1", tf_master_script, 0666)
		if err != nil {
			die(err.Error())
		}

		// loop nodes of cluster, add node name/ip to tf var and write individual cloud-init scripts file
		for n := 1; n <= Nodes; n++ {
			nodenum := strconv.Itoa(n)
			tf_individual_node_script = tf_node_script
			tf_individual_node_script = append(tf_individual_node_script, "export IP=$(curl -s https://ipinfo.io/ip)\n"...)
			tf_individual_node_script = append(tf_individual_node_script, "echo \"echo 'node-"+masternum+"-"+nodenum+" $IP' >> /var/log/px-deploy/completed/tracking \" | ssh root@master-"+masternum+" \n"...)

			err := os.WriteFile("/px-deploy/.px-deploy/tf-deployments/"+config.Name+"/node-"+masternum+"-"+nodenum, tf_individual_node_script, 0666)
			if err != nil {
				die(err.Error())
			}
		}
	}
}

func version() {
	fmt.Println(get_version_current())
}

func history(number string) {
	f, err := os.Open("log")
	if err != nil {
		die(err.Error())
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	if number != "" {
		if num, err := strconv.Atoi(number); err == nil {
			for i := 0; i <= num; i++ {
				scanner.Scan()
			}
			i := strings.Index(scanner.Text(), " ] ")
			c, err := base64.StdEncoding.DecodeString(scanner.Text()[i+3:])
			if err != nil {
				die(err.Error())
			}
			fmt.Println(string(c))
			os.Exit(0)
		} else {
			die("Invalid deployment ID")
		}

	} else {
		var data [][]string
		n := 0
		for scanner.Scan() {
			i1 := strings.Index(scanner.Text(), " [ ")
			i2 := strings.Index(scanner.Text(), " ] ")
			data = append(data, []string{strconv.Itoa(n), scanner.Text()[0:i1], scanner.Text()[i1+3 : i2]})
			n++
		}
		if err := scanner.Err(); err != nil {
			die(err.Error())
		}
		print_table([]string{"Number", "Timestamp", "Parameters"}, data)
	}
}

func list_templates() {
	var data [][]string
	os.Chdir("templates")
	var foo = _list_templates(".")
	data = append(data, foo...)
	print_table([]string{"Name", "Description"}, data)
}

func _list_templates(dir string) [][]string {
	var temp [][]string
	filepath.Walk(dir, func(file string, info os.FileInfo, err error) error {
		if info.Mode()&os.ModeDir != 0 && dir != file {
			_list_templates(file)
		}
		if path.Ext(file) != ".yml" {
			return nil
		}
		config := parse_yaml(file)
		file = strings.TrimSuffix(file, ".yml")
		temp = append(temp, []string{file, config.Description})
		return nil
	})
	return temp
}

func die(msg string) {
	fmt.Println(Red + msg + Reset)
	os.Exit(1)
}

func log(msg string) {
	file, err := os.OpenFile("/px-deploy/.px-deploy/log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		die("Cannot open log: " + err.Error())
	}
	defer file.Close()
	if _, err := file.WriteString(time.Now().Format(time.RFC3339) + " " + msg + "\n"); err != nil {
		die("Cannot write log: " + err.Error())
	}
}

func parse_yaml(filename string) Config {
	b, err := ioutil.ReadFile(filename)
	if err != nil {
		die(err.Error())
	}
	if len(b) != utf8.RuneCount(b) {
		die("Non-ASCII values found in " + filename)
	}
	var d Config
	err = yaml.Unmarshal(b, &d)
	if err != nil {
		die("Broken YAML in " + filename + ": " + err.Error())
	}
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

func write_tf_file(deployment string, filename string, data []string) {
	file, err := os.OpenFile("/px-deploy/.px-deploy/tf-deployments/"+deployment+"/"+filename, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		die("Cannot open file: " + err.Error())
	}
	defer file.Close()
	for _, value := range data {
		if _, err := file.WriteString(value + "\n"); err != nil {
			die("Cannot write file: " + err.Error())
		}
	}
}

func get_version_current() string {
	v, err := ioutil.ReadFile("/VERSION")
	if err != nil {
		die(err.Error())
	}
	return strings.TrimSpace(string(v))
}

func get_version_latest() string {
	resp, err := http.Get("https://raw.githubusercontent.com/andrewh1978/px-deploy/master/VERSION")
	if err != nil {
		return ""
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	v := strings.TrimSpace(string(body))
	if regexp.MustCompile(`^[0-9\.]+$`).MatchString(v) {
		return v
	}
	return ""
}
