package main

import (
	"os"
	"strconv"
	"strings"
)

func azure_create_variables(config *Config) []string {
	var pxduser string
	var tf_variables []string
	var tf_variables_eks []string
	var tf_cluster_instance_type string
	var tf_var_ebs []string
	var tf_var_tags []string
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

	Clusters, _ := strconv.Atoi(config.Clusters)
	Nodes, _ := strconv.Atoi(config.Nodes)

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
	return tf_variables
}
