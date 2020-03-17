#!/usr/bin/env bash
usage()
{
cat <<EOEG

Usage: $0 

    --license-password <License server admin user password. Note: Please use at least one special symbol and numeric value> Supported special symbols are: [!@#$%]

Required only with OIDC:
    --oidc-clientid <OIDC client-id>
    --oidc-secret <OIDC secret>
    --oidc-endpoint <OIDC endpoint>

Optional:
    --cluster-name <PX-Central Cluster Name>
    --admin-user <Admin user for PX-Central and Grafana>
    --admin-password <Admin user password>
    --admin-email <Admin user email address>
    --kubeconfig <Kubeconfig file>
    --custom-registry <Custom image registry path>
    --image-repo-name <Image repo name>
    --air-gapped <Specify for airgapped environment>
    --image-pull-secret <Image pull secret for custom registry>
    --pxcentral-endpoint <Any one of the master or worker node IP of current k8s cluster>
    --cloud <For cloud deployment specify endpoint as 'loadbalance endpoint'>
    --openshift <Provide if deploying PX-Central on openshift platform>
Examples:
    # Deploy PX-Central without OIDC:
    ./install.sh --license-password 'Adm1n!Ur'

    # Deploy PX-Central with OIDC:
    ./install.sh --oidc-clientid test --oidc-secret 0df8ca3d-7854-ndhr-b2a6-b6e4c970968b --oidc-endpoint X.X.X.X:Y --license-password 'Adm1n!Ur'

    # Deploy PX-Central without OIDC with user input kubeconfig:
    ./install.sh --license-password 'Adm1n!Ur' --kubeconfig /tmp/test.yaml

    # Deploy PX-Central with OIDC, custom registry with user input kubeconfig:
    ./install.sh  --license-password 'W3lc0m3#' --oidc-clientid test --oidc-secret 0df8ca3d-7854-ndhr-b2a6-b6e4c970968b  --oidc-endpoint X.X.X.X:Y --custom-registry xyz.amazonaws.com --image-repo-name pxcentral-onprem --image-pull-secret docregistry-secret --kubeconfig /tmp/test.yaml

    # Deploy PX-Central with custom registry:
    ./install.sh  --license-password 'W3lc0m3#' --custom-registry xyz.amazonaws.com --image-repo-name pxcentral-onprem --image-pull-secret docregistry-secret

    # Deploy PX-Central with custom registry with user input kubeconfig:
    ./install.sh  --license-password 'W3lc0m3#' --custom-registry xyz.amazonaws.com --image-repo-name pxcentral-onprem --image-pull-secret docregistry-secret --kubeconfig /tmp/test.yaml

    # Deploy PX-Central on openshift on onprem
    ./install.sh  --license-password 'W3lc0m3#' --openshift 

    # Deploy PX-Central on openshift on cloud
    ./install.sh  --license-password 'W3lc0m3#' --openshift --cloud --pxcentral-endpoint X.X.X.X

    # Deploy PX-Central on Cloud
    ./install.sh  --license-password 'W3lc0m3#' --cloud --pxcentral-endpoint X.X.X.X

    # Deploy PX-Central on cloud with external public IP
    ./install.sh --license-password 'Adm1n!Ur' --pxcentral-endpoint X.X.X.X

    # Deploy PX-Central on air-gapped environment
    ./install.sh  --license-password 'W3lc0m3#' --air-gapped --custom-registry test.ecr.us-east-1.amazonaws.com --image-repo-name pxcentral-onprem --image-pull-secret docregistry-secret

    # Deploy PX-Central on air-gapped envrionemt with oidc
    ./install.sh  --license-password 'W3lc0m3#' --oidc-clientid test --oidc-secret 87348ca3d-1a73-907db-b2a6-87356538  --oidc-endpoint X.X.X.X:Y --custom-registry test.ecr.us-east-1.amazonaws.com --image-repo-name pxcentral-onprem --image-pull-secret docregistry-secret

EOEG
exit 1
}

while [ "$1" != "" ]; do
    case $1 in
    --cluster-name)   shift
                      PXCPXNAME=$1
                      ;;
    --admin-user)     shift
                      ADMINUSER=$1
                      ;;
    --admin-password) shift
                      ADMINPASSWORD=$1
                      ;;
    --admin-email)    shift
                      ADMINEMAIL=$1
                      ;;
    --oidc-clientid)  shift
                      OIDCCLIENTID=$1
                      ;;
    --oidc-secret)    shift
                      OIDCSECRET=$1
                      ;;
    --oidc-endpoint)  shift
                      OIDCENDPOINT=$1
                      ;;
    --license-password) shift
                        LICENSEADMINPASSWORD=$1
                        ;;
    --kubeconfig)     shift
                      KC=$1
                      ;;
    --custom-registry)    shift
                          CUSTOMREGISTRY=$1
                          ;;
    --image-pull-secret)  shift
                          IMAGEPULLSECRET=$1
                          ;;
    --image-repo-name)    shift
                          IMAGEREPONAME=$1
                          ;;
    --pxcentral-endpoint) shift
                          PXCINPUTENDPOINT=$1
                          ;;
    --air-gapped)
                          AIRGAPPED="true"
                          ;;
    --openshift)
                          OPENSHIFTCLUSTER="true"
                          ;;
    --cloud)
                          CLOUDPLATFORM="true"
                          ;;
    -h | --help )   usage
                    ;;
    * )             usage
    esac
    shift
done

TIMEOUT=1800
SLEEPINTERVAL=2
LBSERVICETIMEOUT=300
PXCNAMESPACE="kube-system"
PXCDB="/tmp/db.sql"

UATLICENCETYPE="true"
AIRGAPPEDLICENSETYPE="false"
ISOPENSHIFTCLUSTER="false"
ISCLOUDDEPLOYMENT="false"
ISDOMAINENABLED="false"
PXENDPOINT=""
maxRetry=5
ONPREMOPERATORIMAGE="portworx/pxcentral-onprem-operator:1.0.0"
PXCENTRALAPISERVER="portworx/pxcentral-onprem-api:1.0.0"
IMAGEPULLPOLICY="Always"

checkKubectlCLI=`which kubectl`
if [ -z ${checkKubectlCLI} ]; then
  echo ""
  echo "ERROR: install script requires 'kubectl' client utility present on the instance where it runs."
  echo ""
  exit 1
fi

echo ""
export dotCount=0
export maxDots=10
function showMessage() {
	msg=$1
	dc=$dotCount
	if [ $dc = 0 ]; then
		i=0
		len=${#msg}
		len=$[$len+$maxDots]	
		b=""
		while [ $i -ne $len ]
		do
			b="$b "
			i=$[$i+1]
		done
		echo -e -n "\r$b"
		dc=1
	else 
		msg="$msg"
		i=0
		while [ $i -ne $dc ]
		do
			msg="$msg."
			i=$[$i+1]
		done
		dc=$[$dc+1]
		if [ $dc = $maxDots ]; then
			dc=0
		fi
	fi
	export dotCount=$dc
	echo -e -n "\r$msg"
}

if [ -z ${LICENSEADMINPASSWORD} ]; then
    echo "ERROR : License server admin password is required"
    echo ""
    usage
    exit 1
fi

license_password=`echo -n $LICENSEADMINPASSWORD | grep -E '[0-9]'| grep -E '[!@#$%]'`
if [ -z $license_password ]; then
  echo "ERROR: License server password does not meet secure password requirements, Your password must be have at least 1 special symbol and 1 numeric value."
  echo ""
  usage
fi

if [[ ( ! -n ${OIDCCLIENTID} ) &&  ( ! -n ${OIDCSECRET} ) && ( ! -n ${OIDCENDPOINT} ) ]]; then
  OIDCENABLED="false"
else
  OIDCENABLED="true"
  if [ -z $OIDCCLIENTID ]; then
    echo "ERROR: PX-Central OIDC Client ID is required"
    echo ""
    usage
    exit 1
  fi

  if [ -z $OIDCSECRET ]; then
    echo "ERROR: PX-Central OIDC Client Secret is required"
    echo ""
    usage
    exit 1
  fi

  if [ -z $OIDCENDPOINT ]; then
    echo "ERROR: PX-Central OIDC Endpoint is required"
    echo ""
    usage
    exit 1
  fi
fi
     
if [ -z ${KC} ]; then
  KC=$KUBECONFIG
fi

if [ -z ${KC} ]; then
    KC="$HOME/.kube/config"
fi

if [ -z ${ADMINUSER} ]; then
    ADMINUSER="pxadmin"
fi

if [ -z ${PXCPXNAME} ]; then
    PXCPXNAME="pxcentral-onprem"
fi

if [ -z ${ADMINPASSWORD} ]; then
    ADMINPASSWORD="Password1"
fi

if [ -z ${ADMINEMAIL} ]; then
    ADMINEMAIL="pxadmin@portworx.com"
fi

CUSTOMREGISTRYENABLED=""
if [[ ( ! -n ${CUSTOMREGISTRY} ) &&  ( ! -n ${IMAGEPULLSECRET} ) && ( ! -n ${IMAGEREPONAME} ) ]]; then
  CUSTOMREGISTRYENABLED="false"
else
  CUSTOMREGISTRYENABLED="true"
fi

if [[ ( ${CUSTOMREGISTRYENABLED} = "true" ) && ( -z ${CUSTOMREGISTRY} ) ]]; then
    echo "ERROR: Custom registry url is required for air-gapped installation."
    echo ""
    usage 
    exit 1
fi

if [[ ( $CUSTOMREGISTRYENABLED = "true" ) && ( -z ${IMAGEPULLSECRET} ) ]]; then
    echo "ERROR: Custom registry url and Image pull secret are required for air-gapped installation."
    echo ""
    usage 
    exit 1
fi

if [[ ( $CUSTOMREGISTRYENABLED = "true" ) && ( -z ${IMAGEREPONAME} ) ]]; then
    echo "ERROR: Custom registry url and image repository is required for air-gapped installation."
    echo ""
    usage 
    exit 1
fi

if [ ${AIRGAPPED} ]; then
  if [ "$AIRGAPPED" == "true" ]; then
    AIRGAPPEDLICENSETYPE="true"
    if [[ ( "$CUSTOMREGISTRYENABLED" == "false" ) || ( -z ${IMAGEREPONAME} ) || ( -z ${IMAGEPULLSECRET} ) || ( -z ${IMAGEREPONAME} ) ]]; then
      echo "ERROR: Air gapped deployment requires --custom-registry,--image-repo-name and --image-pull-secret"
      echo ""
      usage
      exit 1
    fi
  fi
fi

if [ ${OPENSHIFTCLUSTER} ]; then
  if [ "$OPENSHIFTCLUSTER" == "true" ]; then
    ISOPENSHIFTCLUSTER="true"
  fi
fi

if [ ${DOMAINENABLED} ]; then
  if [ "$DOMAINENABLED" == "true" ]; then
    ISDOMAINENABLED="true"
    kubectl --kubeconfig=$KC apply -f $pxc_service --namespace $PXCNAMESPACE &>/dev/null
  fi
fi

if [ "$ISDOMAINENABLED" == "true" ]; then
    ISCLOUDDEPLOYMENT="true"
fi

if [ ${CLOUDPLATFORM} ]; then
  if [[ "$CLOUDPLATFORM" == "true"  && "$ISOPENSHIFTCLUSTER" == false ]]; then
    ISCLOUDDEPLOYMENT="true"
    if [ -z ${PXCINPUTENDPOINT} ]; then
      echo "ERROR: Cloud deployment needs a public Loadbalancer endpoint to ensure that the UI is accessible from anywhere. "
      echo ""
      echo "# Deploy PX-Central on openshift on cloud"
      echo "./install.sh  --license-password 'W3lc0m3#' --cloud --pxcentral-endpoint X.X.X.X"
      echo ""
      exit 1
    fi
  fi
fi

if [ ${OPENSHIFTCLUSTER} ]; then
  if [ "$CLOUDPLATFORM" == "true" ]; then
    ISCLOUDDEPLOYMENT="true"
    if [ -z ${PXCINPUTENDPOINT} ]; then
      echo "ERROR: Cloud deployment needs a public Loadbalancer endpoint to ensure that the UI is accessible from anywhere. "
      echo ""
      echo "# Deploy PX-Central on openshift on cloud"
      echo "./install.sh  --license-password 'W3lc0m3#' --openshift --cloud --pxcentral-endpoint X.X.X.X"
      echo ""
      exit 1
    fi
  fi
fi

echo "Validate and Pre-Install check in progress:"
if [ -f "$KC" ]; then
    echo "Using Kubeconfig: $KC"
else 
    echo "ERROR : Kubeconfig [ $KC ] does not exist"
    usage
fi

checkK8sVersion=`kubectl --kubeconfig=$KC version --short | awk -Fv '/Server Version: / {print $3}' 2>&1`
echo "Kubernetes cluster version: $checkK8sVersion"
k8sVersion114Validate=`echo -n $checkK8sVersion | grep -E '1.14.x'`
k8sVersion115Validate=`echo -n $checkK8sVersion | grep -E '1.15.x'`
k8sVersion116Validate=`echo -n $checkK8sVersion | grep -E '1.16.x'`
if [[ ${k8sVersion114Validate} || ${k8sVersion115Validate} || ${k8sVersion116Validate} ]]; then
  echo "Warning: PX-Central supports following k8s versions : 1.14.x, 1.15.x and 1.16.x"
  echo ""
  usage
fi

if [ -z ${PXCINPUTENDPOINT} ]; then
  PXENDPOINT=`kubectl --kubeconfig=$KC get nodes -o wide 2>&1 | grep -i "master" | awk '{print $6}' | head -n 1 2>&1`
  echo "Using PX-Central Endpoint as: $PXENDPOINT"
  echo ""
  if [ -z ${PXENDPOINT} ]; then
    PXENDPOINT=`kubectl --kubeconfig=$KC get nodes -o wide 2>&1 | grep -v "master" | grep -v "INTERNAL-IP" | awk '{print $6}' | head -n 1 2>&1`
    echo "Using PX-Central Endpoint as:  $PXENDPOINT"
    echo ""
  fi

  if [ -z ${PXENDPOINT} ]; then
    echo "PX-Central endpoint empty."
    echo ""
    usage
    exit 1
  fi
else
  PXENDPOINT=$PXCINPUTENDPOINT
  echo "Using PX-Central Endpoint as: $PXENDPOINT"
  echo ""
fi

nodeCount=`kubectl --kubeconfig=$KC get nodes 2>&1 | grep -i "Ready" | awk '{print $3}' | grep -v "master" | wc -l 2>&1`
if [ "$nodeCount" -lt 3 ]; then 
    echo "PX-Central deployments needs minimum 3 worker nodes. found: $nodeCount"
    exit 1
fi

echo "PX-Central cluster resource check:"
resource_check="/tmp/resource_check.py"
cat > $resource_check <<- "EOF"
import os
import sys
import subprocess

kubeconfig=sys.argv[1]

cpu_check_list=[]
memory_check_list=[]
try:
  cmd = "kubectl --kubeconfig=%s get nodes | grep -v master | grep -v NAME | awk '{print $1}'" % kubeconfig
  output= subprocess.check_output(cmd, shell=True)
  nodes_output = output.decode("utf-8")
  nodes_list = nodes_output.split("\n")
  nodes_count = len(nodes_list)
  for node in nodes_list:
    try:
      cmd = "kubectl --kubeconfig=%s get node %s -o=jsonpath='{.status.capacity.cpu}'" % (kubeconfig, node)
      cpu_output = subprocess.check_output(cmd, shell=True)
      cpu_output = cpu_output.decode("utf-8")
      if cpu_output:
        cpu = int(cpu_output)
        if cpu > 3:
          cpu_check_list.append(True)
        else:
          cpu_check_list.append(False)

      cmd = "kubectl --kubeconfig=%s get node %s -o=jsonpath='{.status.capacity.memory}'" % (kubeconfig, node)
      memory_output = subprocess.check_output(cmd, shell=True)
      memory_output = memory_output.decode("utf-8")
      if memory_output:
        memory = memory_output.split("K")[0]
        memory = int(memory)
        if memory > 7000000:
          memory_check_list.append(True)
        else:
          memory_check_list.append(False)
    except Exception as ex:
      pass
except Exception as ex:
  pass
finally:
  if cpu_check_list == memory_check_list:
    print(True)
  else:
    print(False)
EOF

if [ -f ${resource_check} ]; then
  status=`python $resource_check $KC`
  if [ ${status} = "True" ]; then
    echo "Resource check passed.."
    echo ""
  else
    echo ""
    echo "Nodes in k8s cluster does not have minimum required  resources..."
    echo "CPU: 4, Memory: 8GB, Drives: 2  needed on each k8s worker node"
    exit 1
  fi
fi

kubectl --kubeconfig=$KC create namespace $PXCNAMESPACE &>/dev/null

if [ $CUSTOMREGISTRYENABLED = "true" ]; then
  kubectl --kubeconfig=$KC create secret docker-registry --docker-server=649513742363.dkr.ecr.us-east-1.amazonaws.com/ --docker-username=AWS --docker-password="eyJwYXlsb2FkIjoiRitYczdEcEpkaUFvcEZXdyt5YVkvajhkS3dHQlV6NklsMGYrYXVaREg1VzNNSHpNV1AvNXBVcmJ4L2RNSXNvSzRMWmhZam5DMitXc1V4NlFjSUlXUmdRRDN2ZU9MajFXN0tZZE1mNS83TVh1UUx4M3l0NkZsTWVBakkzV2paeDhlbkt2UjQ2ZTVzczlEM0MrQnlQYjNIeXhWZWMrckk1L0Zxa3BVYW43MHBHbHl6UWZOSTUrKzV2d242ZEdWNmQvRkZ6dzNJSmNlZ1VxZ2dCUExYR0tWTnpRWUM3TlVCQytvWGpZRFliTVNkY0txOEd6SjhBNkJtV295UGd2R2RzME5lem80eEFmcGRJemsvZmRnVm1hY0o1ZFpaQ09uamhERlpEWGN0NkxmQmJDRUNQQVR5RTVUWWgyaVJ2MTJUN3JOdlp6VkZFS2wzT3JzS3F0RGdjb04zQ3llUGRucGM2U1hKendvczhnSHc0Nkp1a05tSVpsb3U4OVVzSjNyVFNqWjFobUxTeERQN0hCcmk1V2JmRG13L0dmVnI5bHNJdm1PZlpETkFkQ1luaG1ZNENNeUFKaE5BbHdhV0lYb2IvUFNIRVFPUXJhY1VsekRBUzNJVGIrL2phMlVCWk8xUVRhSWVCbEE3R1pBYzBldWVPdFQrVE1id3J3MnJuZ0czZnRiOFBYR1UyQ3ZWVlVVTUh2ZkNxc2tXKzBRS0VIcmR5TElGMVJRbFM3TzVEc2dVLzUwOWQ0TzV2bEhzR3ljdktobmJtNlNrSnNoMklJazhZVkI3QzVhelFubEF5MndhV05LL3hxbnpvNVZaTjlFRXRLSk91cXR5d1lpRWhuZmFQemFVbGJ4azVwVHlxajhBSkh2SksrSlNIbmtDNDRoRGRXQWdUcnpHUGRHL2ozdzRMSlRoWHJMT0E0Q0ZrSWNIdzNCdkJERk1sTEwyNDZ5cDFsT2h3Z2RDN3J6R1pLNWFaQVBCL1FTbzRVcmtjSjhKVVM1THV4ZEdBbzl3VnhIMjI0OXppbXlJS1dsbmxYMU14c2ZqSytFSUJ0cnExZzBMWThtOUxabWg4ZjFId0crZ3F2eVFGTzdRb2sxOVJwdnBMQWxoenNLcjZmU2RMWjlRYkczQlEvT3BINExsdVpmcGdWa1htM3V4NDYrc3pXcjd6cnpNcW9KRFpTbHhEaXlETGZoQWZBMlJJWHc5Njc2YXN5VGdRME9lRDA0K2JzdHVQbXVrbzhkZmkwQnJOdHhESFdVWXdMelRqaXBqVUp3MVdIcDlCdy9PaEtBdWNRUXhxSlozK0J3R1FDaXUwelVJZnVuQ2wvRVJuSnBDd214UFpHNnE0WXQ2dlJmZmN2YTROc1kyYkllOHZ1bEdJK3FWcTZEcUM2Wm9kR0VmQlV2c3lLdGlSc0xMUGUralo2cmswOFQ5cHdXTWxsIiwiZGF0YWtleSI6IkFRRUJBSGh3bTBZYUlTSmVSdEptNW4xRzZ1cWVla1h1b1hYUGU1VUZjZTlScTgvMTR3QUFBSDR3ZkFZSktvWklodmNOQVFjR29HOHdiUUlCQURCb0Jna3Foa2lHOXcwQkJ3RXdIZ1lKWUlaSUFXVURCQUV1TUJFRURMc1JJVnRKL3hkaHd4OUM5Z0lCRUlBN3lkU3F6RHZ6KzFEOFJrWkswc0FYV3BsOWtjNURvMmFjN1ZoUWJUeTBTQ3hHSElEQ1FkZEQ2cHpxY2c4bEN3aXh6RnFJaGFOZUMxOCtqVms9IiwidmVyc2lvbiI6IjIiLCJ0eXBlIjoiREFUQV9LRVkiLCJleHBpcmF0aW9uIjoxNTgzMjE2OTAzfQ==" docregistry-secret --namespace $PXCNAMESPACE &>/dev/null
  sleep $SLEEPINTERVAL
  validatesecret=`kubectl --kubeconfig=$KC get secret $IMAGEPULLSECRET  --namespace $PXCNAMESPACE 2>&1 | grep -v NAME | awk '{print $1}' | wc -l 2>&1`
  if [ $validatesecret -ne "1" ]; then
    echo "ERROR: --image-pull-secret provided is not present in kube-system namespace, please create it in kube-system namespace and re-run the script"
    exit 1
  fi
else
  kubectl --kubeconfig=$KC create secret docker-registry --docker-server=https://index.docker.io/v1/ --docker-username=pwxbuild --docker-password=fridaydemos docregistry-secret --namespace $PXCNAMESPACE &>/dev/null
fi

if [ -z $IMAGEPULLSECRET ]; then
  IMAGEPULLSECRET="docregistry-secret"
fi

cat > $PXCDB <<- "EOF"
-- phpMyAdmin SQL Dump
-- version 4.7.6
-- https://www.phpmyadmin.net/
--
-- Host: localhost
-- Generation Time: Nov 22, 2019 at 04:40 AM
-- Server version: 5.7.20
-- PHP Version: 7.1.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `emtpypxcentralinit`
--

-- --------------------------------------------------------

--
-- Table structure for table `audit_log`
--

CREATE TABLE `audit_log` (
  `id` int(10) UNSIGNED NOT NULL,
  `type` enum('AUTH','SPEC','COMPANY') NOT NULL,
  `sub_type` enum('LOGIN','LOGOUT','CREATE','UPDATE','DELETE') NOT NULL,
  `data` varchar(2048) NOT NULL,
  `ip` varchar(39) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `aws_clusters`
--

CREATE TABLE `aws_clusters` (
  `id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `company_id` int(10) UNSIGNED NOT NULL,
  `aws_credential_id` int(10) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `instances` int(11) NOT NULL,
  `region` varchar(50) DEFAULT NULL,
  `security_group` varchar(255) DEFAULT NULL,
  `security_group_id` varchar(1024) DEFAULT NULL,
  `total_used` int(11) DEFAULT NULL,
  `total_size` int(11) DEFAULT NULL,
  `cpu` int(11) DEFAULT NULL,
  `instance_obj` blob,
  `status` enum('RUNNING','TERMINATED','STOPPED','REBOOT','ERROR','NEW') NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `aws_credentials`
--

CREATE TABLE `aws_credentials` (
  `id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `company_id` int(10) UNSIGNED NOT NULL,
  `aws_key` varchar(255) NOT NULL,
  `aws_secret` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `keypair_name` varchar(255) DEFAULT NULL,
  `group_name` varchar(255) DEFAULT NULL,
  `ssh_key` varchar(4096) DEFAULT NULL,
  `region` varchar(20) DEFAULT NULL,
  `version` varchar(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `company`
--

CREATE TABLE `company` (
  `id` int(11) UNSIGNED NOT NULL,
  `name` varchar(255) NOT NULL,
  `url` varchar(255) NOT NULL,
  `sales_contact` varchar(70) DEFAULT NULL,
  `contact_person_gender` enum('MALE','FEMALE','OTHER') NOT NULL,
  `contact_person` varchar(70) NOT NULL,
  `contact_email` varchar(254) NOT NULL,
  `contact_phone` varchar(20) DEFAULT NULL,
  `billing_address1` varchar(255) DEFAULT NULL,
  `billing_address2` varchar(255) DEFAULT NULL,
  `billing_city` varchar(255) DEFAULT NULL,
  `billing_state` varchar(255) DEFAULT NULL,
  `billing_country` varchar(255) DEFAULT NULL,
  `billing_zip` varchar(30) DEFAULT NULL,
  `gdpr` tinyint(1) NOT NULL DEFAULT '0',
  `notes` varchar(1024) DEFAULT NULL,
  `created_by` int(10) UNSIGNED NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Dumping data for table `company`
--

INSERT INTO `company` (`id`, `name`, `url`, `sales_contact`, `contact_person_gender`, `contact_person`, `contact_email`, `contact_phone`, `billing_address1`, `billing_address2`, `billing_city`, `billing_state`, `billing_country`, `billing_zip`, `gdpr`, `notes`, `created_by`, `created_at`, `updated_at`) VALUES
(1, 'UnAssigned', 'https://www.portworx.com', 'Brobyn', 'FEMALE', 'Hildagard Brobyn', 'hbrobyn0@prweb.com', '686-9867', '37 Mifflin Avenue', 'Porter', 'Pittsburgh', 'Pennsylvania', 'United States', '15266', 0, 'In sagittis dui vel nisl. Duis ac nibh. Fusce lacus purus, aliquet at, feugiat non, pretium quis, lectus.\n\nSuspendisse potenti. In eleifend quam a odio. In hac habitasse platea dictumst.', 1, '2019-04-12 06:04:20', '2019-04-14 02:56:16'),
(2, 'Portworx', 'https://www.portworx.com', 'Stockill', 'MALE', 'Cyrill Stockill', 'cstockill1@nationalgeographic.com', '717-765-0603', '5 Becker Plaza', 'John Wall', 'Lancaster', 'Pennsylvania', 'United States', '17605', 0, 'Maecenas leo odio, condimentum id, luctus nec, molestie sed, justo. Pellentesque viverra pede ac diam. Cras pellentesque volutpat dui.\n\nMaecenas tristique, est et tempus semper, est quam pharetra magna, ac consequat metus sapien ut nunc. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Mauris viverra diam vitae quam. Suspendisse potenti.', 1, '2019-04-12 06:04:20', '2019-04-12 06:04:20');

-- --------------------------------------------------------

--
-- Table structure for table `lh_cluster`
--
CREATE TABLE `lh_cluster` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `company_id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `clusteruuid` varchar(80) NOT NULL,
  `clusterid` varchar(255) NOT NULL,
  `endpoint_active` varchar(255) NOT NULL,
  `endpoint_schema` enum('http','https') NOT NULL,
  `endpoint` varchar(255) NOT NULL,
  `endpoint_sdk` varchar(255) NOT NULL,
  `endpoint_port` smallint(11) UNSIGNED NOT NULL,
  `sdk_port` smallint(11) UNSIGNED NOT NULL,
  `version` varchar(255) NOT NULL,
  `scheduler` enum('NONE','OTHER','MESOS','KUBERNETES','DCOS','DOCKER') NOT NULL,
  `grafana` varchar(1024) DEFAULT NULL,
  `prometheus` varchar(1024) DEFAULT NULL,
  `kibana` varchar(1024) DEFAULT NULL,
  `kube_config` varchar(10000) DEFAULT NULL,
  `security_type` enum('NONE','TOKEN','OIDC') NOT NULL,
  `token` varchar(5000) DEFAULT NULL,
  `data` varchar(2000) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `migrations`
--

CREATE TABLE `migrations` (
  `id` int(10) UNSIGNED NOT NULL,
  `migration` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `batch` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `migrations`
--

INSERT INTO `migrations` (`id`, `migration`, `batch`) VALUES
(1, '2014_10_12_000000_create_users_table', 1),
(2, '2014_10_12_100000_create_password_resets_table', 1),
(3, '2016_06_01_000001_create_oauth_auth_codes_table', 1),
(4, '2016_06_01_000002_create_oauth_access_tokens_table', 1),
(5, '2016_06_01_000003_create_oauth_refresh_tokens_table', 1),
(6, '2016_06_01_000004_create_oauth_clients_table', 1),
(7, '2016_06_01_000005_create_oauth_personal_access_clients_table', 1);

-- --------------------------------------------------------

--
-- Table structure for table `oauth_access_tokens`
--

CREATE TABLE `oauth_access_tokens` (
  `id` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `client_id` int(10) UNSIGNED NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `scopes` text COLLATE utf8mb4_unicode_ci,
  `revoked` tinyint(1) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `expires_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `oauth_auth_codes`
--

CREATE TABLE `oauth_auth_codes` (
  `id` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` int(11) NOT NULL,
  `client_id` int(10) UNSIGNED NOT NULL,
  `scopes` text COLLATE utf8mb4_unicode_ci,
  `revoked` tinyint(1) NOT NULL,
  `expires_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `oauth_clients`
--

CREATE TABLE `oauth_clients` (
  `id` int(10) UNSIGNED NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `secret` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `redirect` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `personal_access_client` tinyint(1) NOT NULL,
  `password_client` tinyint(1) NOT NULL,
  `revoked` tinyint(1) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `oauth_clients`
--

INSERT INTO `oauth_clients` (`id`, `user_id`, `name`, `secret`, `redirect`, `personal_access_client`, `password_client`, `revoked`, `created_at`, `updated_at`) VALUES
(1, NULL, 'Laravel Personal Access Client', 'vAGnE85CLxdtouR1Q5nnT4que1MBpoz32nyGxviS', 'http://localhost', 1, 0, 0, '2019-03-22 10:05:23', '2019-03-22 10:05:23'),
(2, NULL, 'Laravel Password Grant Client', 'i4I7FIfD4AeqJUhu3R7q4Qedjn7V50u4f4Gz1Q1k', 'http://localhost', 0, 1, 0, '2019-03-22 10:05:23', '2019-03-22 10:05:23');

-- --------------------------------------------------------

--
-- Table structure for table `oauth_personal_access_clients`
--

CREATE TABLE `oauth_personal_access_clients` (
  `id` int(10) UNSIGNED NOT NULL,
  `client_id` int(10) UNSIGNED NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `oauth_personal_access_clients`
--

INSERT INTO `oauth_personal_access_clients` (`id`, `client_id`, `created_at`, `updated_at`) VALUES
(1, 1, '2019-03-22 10:05:23', '2019-03-22 10:05:23');

-- --------------------------------------------------------

--
-- Table structure for table `oauth_refresh_tokens`
--

CREATE TABLE `oauth_refresh_tokens` (
  `id` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `access_token_id` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `revoked` tinyint(1) NOT NULL,
  `expires_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `password_resets`
--

CREATE TABLE `password_resets` (
  `id` int(10) UNSIGNED NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(129) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `specgen`
--

CREATE TABLE `specgen` (
  `id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `company_id` int(10) UNSIGNED NOT NULL,
  `name` varchar(1024) NOT NULL,
  `labels` varchar(1028) NOT NULL,
  `data` varchar(3072) NOT NULL,
  `command` varchar(1024) NOT NULL,
  `url` varchar(1024) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` bigint(20) UNSIGNED NOT NULL,
  `company_id` int(10) UNSIGNED NOT NULL DEFAULT '1',
  `company_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(275) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` enum('PXADMIN','DEMO','ADMIN','MANAGER','ENGINEER','SALES','USER') COLLATE utf8mb4_unicode_ci DEFAULT 'MANAGER',
  `provider_type` enum('NORMAL','GITHUB','GOOGLE','OIDC') COLLATE utf8mb4_unicode_ci NOT NULL,
  `provider_id` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `provider_token` varchar(5000) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `first_name` varchar(35) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_name` varchar(35) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `image` varchar(1028) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `phone` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `country` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `state` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `zip` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `profile_status` enum('NEW','COMPLETED') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'NEW',
  `receive_updates` tinyint(1) NOT NULL DEFAULT '0',
  `remember_token` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `email_verification_code` varchar(129) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `deleted_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `id` (`id`),
  ADD UNIQUE KEY `users_email_unique` (`email`,`deleted_at`) USING BTREE;

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT;
COMMIT;


-- --------------------------------------------------------

--
-- Table structure for table `user_invite`
--

CREATE TABLE `user_invite` (
  `id` int(10) UNSIGNED NOT NULL,
  `company_id` int(10) UNSIGNED NOT NULL,
  `user_id` int(10) UNSIGNED NOT NULL,
  `email` varchar(255) NOT NULL,
  `status` enum('NEW','ACCEPTED','REJECTED') NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `audit_log`
--
ALTER TABLE `audit_log`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `aws_clusters`
--
ALTER TABLE `aws_clusters`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `id` (`id`);

--
-- Indexes for table `aws_credentials`
--
ALTER TABLE `aws_credentials`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `id` (`id`);

--
-- Indexes for table `company`
--
ALTER TABLE `company`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `id` (`id`);

--
-- Indexes for table `lh_cluster`
--
ALTER TABLE `lh_cluster`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `id` (`id`);

--
-- Indexes for table `migrations`
--
ALTER TABLE `migrations`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `oauth_access_tokens`
--
ALTER TABLE `oauth_access_tokens`
  ADD PRIMARY KEY (`id`),
  ADD KEY `oauth_access_tokens_user_id_index` (`user_id`);

--
-- Indexes for table `oauth_auth_codes`
--
ALTER TABLE `oauth_auth_codes`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `oauth_clients`
--
ALTER TABLE `oauth_clients`
  ADD PRIMARY KEY (`id`),
  ADD KEY `oauth_clients_user_id_index` (`user_id`);

--
-- Indexes for table `oauth_personal_access_clients`
--
ALTER TABLE `oauth_personal_access_clients`
  ADD PRIMARY KEY (`id`),
  ADD KEY `oauth_personal_access_clients_client_id_index` (`client_id`);

--
-- Indexes for table `oauth_refresh_tokens`
--
ALTER TABLE `oauth_refresh_tokens`
  ADD PRIMARY KEY (`id`),
  ADD KEY `oauth_refresh_tokens_access_token_id_index` (`access_token_id`);

--
-- Indexes for table `password_resets`
--
ALTER TABLE `password_resets`
  ADD PRIMARY KEY (`id`),
  ADD KEY `password_resets_email_index` (`email`);

--
-- Indexes for table `specgen`
--
ALTER TABLE `specgen`
  ADD PRIMARY KEY (`id`);


--
-- Indexes for table `user_invite`
--
ALTER TABLE `user_invite`
  ADD PRIMARY KEY (`id`,`company_id`,`email`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `audit_log`
--
ALTER TABLE `audit_log`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `aws_clusters`
--
ALTER TABLE `aws_clusters`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `aws_credentials`
--
ALTER TABLE `aws_credentials`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `company`
--
ALTER TABLE `company`
  MODIFY `id` int(11) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1005;

--
-- AUTO_INCREMENT for table `lh_cluster`
--
ALTER TABLE `lh_cluster`
  MODIFY `id` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=31;

--
-- AUTO_INCREMENT for table `migrations`
--
ALTER TABLE `migrations`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `oauth_clients`
--
ALTER TABLE `oauth_clients`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `oauth_personal_access_clients`
--
ALTER TABLE `oauth_personal_access_clients`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `password_resets`
--
ALTER TABLE `password_resets`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `specgen`
--
ALTER TABLE `specgen`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=36;



--
-- AUTO_INCREMENT for table `user_invite`
--
ALTER TABLE `user_invite`
  MODIFY `id` int(10) UNSIGNED NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
EOF

cat <<< '
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
   name: pxcentral-onprem-operator
   namespace: kube-system
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: pxcentral-onprem-operator
  namespace: kube-system
subjects:
- kind: ServiceAccount
  name: pxcentral-onprem-operator
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: pxcentral-onprem-operator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: px-cluster-admin-binding
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: system:serviceaccount:kube-system:default
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: pxc-onprem-operator-cluster-admin-binding
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: system:serviceaccount:kube-system:pxcentral-onprem-operator
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pxcentral-onprem-operator
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: kube-system
  name: pxcentral-onprem-operator
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - services
  - services/finalizers
  - endpoints
  - persistentvolumeclaims
  - events
  - configmaps
  - secrets
  verbs:
  - "*"
- apiGroups:
  - apps
  resources:
  - deployments
  - daemonsets
  - replicasets
  - statefulsets
  verbs:
  - "*"
- apiGroups:
  - ""
  resources:
  - namespaces
  verbs:
  - get
- apiGroups:
  - ""
  resources:
  - configmaps
  - secrets
  verbs:
  - "*"
- apiGroups:
  - monitoring.coreos.com
  resources:
  - servicemonitors
  verbs:
  - get
  - create
- apiGroups:
  - apps
  resourceNames:
  - pxcentral-onprem-operator
  resources:
  - deployments/finalizers
  verbs:
  - update
- apiGroups:
  - ""
  resources:
  - pods
  verbs:
  - get
- apiGroups:
  - apps
  resources:
  - replicasets
  - deployments
  verbs:
  - get
- apiGroups:
  - pxcentral.com
  resources:
  - "*"
  verbs:
  - "*"
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: pxcentralonprems.pxcentral.com
  namespace: kube-system
spec:
  group: pxcentral.com
  names:
    kind: PxCentralOnprem
    listKind: PxCentralOnpremList
    plural: pxcentralonprems
    singular: pxcentralonprem
  scope: Namespaced
  subresources:
    status: {}
  versions:
  - name: v1alpha1
    served: true
    storage: true
---
apiVersion: v1
kind: Service
metadata:
  name: px-central
  namespace: kube-system
  labels:
    app: px-central
spec:
  selector:
    app: px-central
  ports:
    - name: px-central-grpc
      protocol: TCP
      port: 10005
      targetPort: 10005
    - name: px-central-rest
      protocol: TCP
      port: 10006
      targetPort: 10006
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pxcentral-onprem-operator
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      name: pxcentral-onprem-operator
      app: px-central
  template:
    metadata:
      labels:
        name: pxcentral-onprem-operator
        app: px-central
    spec:
        affinity:
          podAntiAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              - labelSelector:
                  matchExpressions:
                    - key: "name"
                      operator: In
                      values:
                      - pxcentral-onprem-operator
                topologyKey: "kubernetes.io/hostname"
        initContainers:
        - command:
          - python
          - /specs/pxc-pre-setup.py
          image: portworx/pxcentral-onprem-pre-setup:1.0.0
          imagePullPolicy: Always
          name: pxc-pre-setup
          resources: {}
          securityContext:
            privileged: true
        serviceAccount: pxcentral-onprem-operator
        serviceAccountName: pxcentral-onprem-operator
        containers:
          - name: pxcentral-onprem-operator
            image: '$ONPREMOPERATORIMAGE'
            imagePullPolicy: Always
            env:
              - name: OPERATOR_NAME
                value: pxcentral-onprem-operator
              - name: POD_NAME
                valueFrom:
                  fieldRef:
                    apiVersion: v1
                    fieldPath: metadata.name
              - name: WATCH_NAMESPACE
                valueFrom:
                  fieldRef:
                    apiVersion: v1
                    fieldPath: metadata.namespace
          - name: px-central
            image: '$PXCENTRALAPISERVER'
            imagePullPolicy: Always
            readinessProbe:
              httpGet:
                path: /v1/health
                port: 10006
              initialDelaySeconds: 10
              timeoutSeconds: 120
              periodSeconds: 20
            resources:
              limits:
                cpu: 512m
                memory: "512Mi"
              requests:
                memory: "512Mi"
                cpu: 256m
            securityContext:
              privileged: true
            command:
            - /pxcentral-onprem
            - start
        imagePullSecrets:
        - name: '$IMAGEPULLSECRET'
' > /tmp/pxcentralonprem_crd.yaml

cat <<< '
apiVersion: pxcentral.com/v1alpha1
kind: PxCentralOnprem
metadata:
  name: pxcentralonprem
  namespace: '$PXCNAMESPACE'
spec:
  namespace: '$PXCNAMESPACE'                    # Provide namespace to install px and pxcentral stack
  portworx:
    enabled: true
    clusterName: '$PXCPXNAME'   # Note: Use a unique name for your cluster: The characters allowed in names are: digits (0-9), lower case letters (a-z) and (-)
    security:
      enabled: false
      oidc:
        enabled: false
      selfSigned:
        enabled: false
  centralLighthouse:
    enabled: true
    externalHttpPort: 31236
    externalHttpsPort: 31237
  externalEndpoint: '$PXENDPOINT':31234       # For ingress endpint only
  loadBalancerEndpoint: '$PXENDPOINT'
  username: '$ADMINUSER'                       
  password: '$ADMINPASSWORD'
  email: '$ADMINEMAIL'
  imagePullSecrets: '$IMAGEPULLSECRET'
  customRegistryURL: '$CUSTOMREGISTRY'
  customeRegistryEnabled: '$CUSTOMREGISTRYENABLED'
  imagesRepoName: '$IMAGEREPONAME'
  imagePullPolicy: '$IMAGEPULLPOLICY'
  isOpenshiftCluster: '$ISOPENSHIFTCLUSTER'
  cloud:
    isCloud: '$ISCLOUDDEPLOYMENT'
  monitoring:
    prometheus:
      enabled: true
      externalPort: 31240
      externalEndpoint: pxc-cortex-nginx.kube-system.svc.cluster.local:80
    grafana:
      enabled: true
  pxcentral:
    enabled: true
    pxcui:                    # Deploy PX-Central UI, required on pxcentral cluster only 
      enabled: true
      externalAccessPort : 31234
      security:
        enabled: '$OIDCENABLED'
        clientId: '$OIDCCLIENTID'
        clientSecret: '$OIDCSECRET'
        oidcEndpoint: '$OIDCENDPOINT'
      metallb:
        enabled: false
    licenseserver:            # License Server
      enabled: true
      type:
        UAT: '$UATLICENCETYPE'
        airgapped: '$AIRGAPPEDLICENSETYPE'
      adminPassword: '$LICENSEADMINPASSWORD'
' > /tmp/pxcentralonprem_cr.yaml

mac_daemonset="/tmp/pxc-mac-check.yaml"
cat > $mac_daemonset <<- "EOF"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pxc-license-ha
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: pxc-license-ha-role
  namespace: kube-system
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: pxc-license-ha-role-binding
  namespace: kube-system
subjects:
- kind: ServiceAccount
  name: pxc-license-ha
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: pxc-license-ha-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
    run: pxc-mac-setup
  name: pxc-mac-setup
  namespace: kube-system
spec:
  selector:
    matchLabels:
      run: pxc-mac-setup
  minReadySeconds: 0
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  template:
    metadata:
      labels:
        run: pxc-mac-setup
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: px/enabled
                operator: NotIn
                values:
                - "false"
              - key: node-role.kubernetes.io/master
                operator: DoesNotExist
      hostNetwork: true
      hostPID: false
      restartPolicy: Always
      serviceAccountName: pxc-license-ha
      containers:
      - args:
        - bash
        - -c
        - python3 /code/setup_mac_address.py
        image: pwxbuild/pxc-macaddress-config:1.0.0
        imagePullPolicy: Always
        name: pxc-mac-setup
EOF

echo "PX-Central cluster deployment started:"
echo "This process may take several minutes. Please wait for it to complete..."
kubectl --kubeconfig=$KC apply -f $mac_daemonset &>/dev/null
pxclicensecm="0"
timecheck=0
count=0
while [ $pxclicensecm -ne "1" ]
  do
    pxcentral_license_cm=`kubectl --kubeconfig=$KC get cm --namespace $PXCNAMESPACE 2>&1 | grep -i "pxc-lsc-hasetup" | wc -l 2>&1`
    if [ "$pxcentral_license_cm" -eq "$nodeCount" ]; then
      pxclicensecm="1"
      break
    fi
    showMessage "Waiting for PX-Central required components to be ready (0/7)"
    sleep $SLEEPINTERVAL
    timecheck=$[$timecheck+$SLEEPINTERVAL]
    if [ $timecheck -gt $LBSERVICETIMEOUT ]; then
      echo ""
      echo "ERROR: PX-Central deployment is not ready, Contact: support@portworx.com"
      exit 1
    fi
  done
kubectl --kubeconfig=$KC delete -f $mac_daemonset &>/dev/null
showMessage "Waiting for PX-Central required components to be ready (0/7)"

kubectl --kubeconfig=$KC apply -f /tmp/pxcentralonprem_crd.yaml &>/dev/null
pxcentralcrdregistered="0"
timecheck=0
count=0
while [ $pxcentralcrdregistered -ne "1" ]
  do
    pxcentral_crd=`kubectl --kubeconfig=$KC get crds 2>&1 | grep -i "pxcentralonprems.pxcentral.com" | wc -l 2>&1`
    if [ "$pxcentral_crd" -eq "1" ]; then
      pxcentralcrdregistered="1"
      break
    fi
    showMessage "Waiting for PX-Central required components to be ready (0/7)"
    sleep $SLEEPINTERVAL
    timecheck=$[$timecheck+$SLEEPINTERVAL]
    if [ $timecheck -gt $TIMEOUT ]; then
      echo ""
      echo "ERROR: PX-Central deployment is not ready, Contact: support@portworx.com"
      exit 1
    fi
  done

kubectl --kubeconfig=$KC apply -f /tmp/pxcentralonprem_cr.yaml &>/dev/null
showMessage "Waiting for PX-Central required components to be ready (0/7)"
kubectl --kubeconfig=$KC get po --namespace $PXCNAMESPACE &>/dev/null
operatordeploymentready="0"
timecheck=0
count=0
while [ $operatordeploymentready -ne "1" ]
  do
    operatoronpremdeployment=`kubectl --kubeconfig=$KC get pods --namespace $PXCNAMESPACE 2>&1 | grep "pxcentral-onprem-operator" | awk '{print $2}' | grep -v READY | grep "1/2" | wc -l 2>&1`
    if [ "$operatoronpremdeployment" -eq "1" ]; then
        operatordeploymentready="1"
        break
    fi
    operatoronpremdeploymentready=`kubectl --kubeconfig=$KC get pods --namespace $PXCNAMESPACE 2>&1 | grep "pxcentral-onprem-operator" | awk '{print $2}' | grep -v READY | grep "2/2" | wc -l 2>&1`
    if [ "$operatoronpremdeploymentready" -eq "1" ]; then
        operatordeploymentready="1"
        break
    fi
    showMessage "Waiting for PX-Central required components to be ready (0/7)"
    sleep $SLEEPINTERVAL
    timecheck=$[$timecheck+$SLEEPINTERVAL]
    if [ $timecheck -gt $TIMEOUT ]; then
      echo ""
      echo "PX-Central onprem deployment not ready... Timeout: $TIMEOUT seconds"
      operatorPodName=`kubectl --kubeconfig=$KC get pods --namespace $PXCNAMESPACE 2>&1 | grep "pxcentral-onprem-operator" | awk '{print $1}' | grep -v NAME 2>&1`
      echo "ERROR: PX-Central deployment is not ready, Contact: support@portworx.com"
      echo ""
      exit 1
    fi
  done
showMessage "Waiting for PX-Central required components to be ready (1/7)"
pxready="0"
sleep $SLEEPINTERVAL
timecheck=0
count=0
license_server_cm_available="0"
while [ $pxready -ne "1" ]
  do
    pxready=`kubectl --kubeconfig=$KC get pods --namespace $PXCNAMESPACE -lname=portworx 2>&1 | awk '{print $2}' | grep -v READY | grep "1/1" | wc -l 2>&1`
    if [ "$pxready" -ge "3" ]; then
        pxready="1"
        break
    fi
    showMessage "Waiting for PX-Central required components to be ready (1/7)"

    if [ "$ISOPENSHIFTCLUSTER" == "true" ]; then
      if [ "$license_server_cm_available" -eq "0" ]; then
          main_node_ip=`kubectl --kubeconfig=$KC get cm --namespace $PXCNAMESPACE pxc-lsc-replicas -o jsonpath={.data.primary} 2>&1`
          backup_node_ip=`kubectl --kubeconfig=$KC get cm --namespace $PXCNAMESPACE pxc-lsc-replicas -o jsonpath={.data.secondary} 2>&1`
          if [[ ( ! -z "$main_node_ip" ) && ( ! -z "$backup_node_ip" ) ]]; then
            main_node_hostname=`kubectl --kubeconfig=$KC get nodes -o wide | grep "$main_node_ip" | awk '{print $1}' 2>&1`
            backup_node_hostname=`kubectl --kubeconfig=$KC get nodes -o wide | grep "$backup_node_ip" | awk '{print $1}' 2>&1`
            kubectl --kubeconfig=$KC label node $main_node_hostname px/ls=true &>/dev/null
            kubectl --kubeconfig=$KC label node $backup_node_hostname px/ls=true &>/dev/null
            kubectl --kubeconfig=$KC label node $main_node_hostname primary/ls=true &>/dev/null
            kubectl --kubeconfig=$KC label node $backup_node_hostname backup/ls=true &>/dev/null
            main_node_count=`kubectl --kubeconfig=$KC get node -lprimary/ls=true | grep Ready | wc -l 2>&1`
            backup_node_count=`kubectl --kubeconfig=$KC get node -lbackup/ls=true | grep Ready | wc -l 2>&1`
            if [[ $main_node_count -eq 1 && $backup_node_count -eq 1 ]]; then
              license_server_cm_available=1
            fi
          fi
      fi
    fi

    sleep $SLEEPINTERVAL
    timecheck=$[$timecheck+$SLEEPINTERVAL]
    if [ $timecheck -gt $TIMEOUT ]; then
      break
    fi
  done

cassandrapxready="0"
timecheck=0
count=0
showMessage "Waiting for PX-Central required components to be ready (2/7)"
while [ $cassandrapxready -ne "1" ]
  do
    pxcassandraready=`kubectl --kubeconfig=$KC get sts --namespace $PXCNAMESPACE pxc-cortex-cassandra 2>&1 | grep -v READY | awk '{print $2}' | grep "3/3" | wc -l 2>&1`
    if [ "$pxcassandraready" -eq "1" ]; then
        cassandrapxready="1"
        break
    fi
    showMessage "Waiting for PX-Central required components to be ready (2/7)"
    sleep $SLEEPINTERVAL
    timecheck=$[$timecheck+$SLEEPINTERVAL]
    if [ $timecheck -gt $TIMEOUT ]; then
      break
    fi
  done

lscready="0"
timecheck=0
count=0
showMessage "Waiting for PX-Central required components to be ready (3/7)"
while [ $lscready -ne "1" ]
  do
    licenseserverready=`kubectl --kubeconfig=$KC get deployment --namespace $PXCNAMESPACE pxc-license-server 2>&1 | grep -v READY | awk '{print $2}' | grep "2/2" | wc -l 2>&1`
    if [ "$licenseserverready" -eq "1" ]; then
        lscready="1"
        break
    fi
    showMessage "Waiting for PX-Central required components to be ready (3/7)"
    sleep $SLEEPINTERVAL
    timecheck=$[$timecheck+$SLEEPINTERVAL]
    if [ $timecheck -gt $TIMEOUT ]; then
      break
    fi
  done
showMessage "Waiting for PX-Central required components to be ready (4/7)"

deploymentready="0"
timecheck=0
count=0
while [ $deploymentready -ne "1" ]
  do
    onpremdeployment=`kubectl --kubeconfig=$KC get deployment pxcentral-onprem-operator --namespace $PXCNAMESPACE 2>&1 | awk '{print $2}' | grep -v READY | grep "1/1" | wc -l 2>&1`
    if [ "$onpremdeployment" -eq "1" ]; then
        deploymentready="1"
        break
    fi

    onpremdeployment=`kubectl --kubeconfig=$KC get deployment pxcentral-onprem-operator --namespace $PXCNAMESPACE 2>&1 | awk '{print $2}' | grep -v READY | grep "2/2" | wc -l 2>&1`
    if [ "$onpremdeployment" -eq "1" ]; then
        deploymentready="1"
        break
    fi
    showMessage "Waiting for PX-Central required components to be ready (4/7)"
    sleep $SLEEPINTERVAL
    timecheck=$[$timecheck+$SLEEPINTERVAL]
    if [ $timecheck -gt $TIMEOUT ]; then
      operatorPodName=`kubectl --kubeconfig=$KC get pods --namespace $PXCNAMESPACE 2>&1 | grep "pxcentral-onprem-operator" | awk '{print $1}' | grep -v NAME 2>&1`
      echo ""
      echo "ERROR: PX-Central deployment is not ready, Contact: support@portworx.com"
      echo ""
      exit 1
    fi
  done

showMessage "Waiting for PX-Central required components to be ready (5/7)"
pxcdbready="0"
POD=$(kubectl --kubeconfig=$KC get pod -l app=pxc-mysql --namespace $PXCNAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>&1);
mysqlRootPassword="singapore"
timecheck=0
count=0
while [ $pxcdbready -ne "1" ]
  do
    pxcdbdeploymentready=`kubectl --kubeconfig=$KC get deployment --namespace $PXCNAMESPACE pxc-mysql 2>&1 | awk '{print $2}' | grep -v READY | grep "1/1" | wc -l 2>&1`
    if [ "$pxcdbdeploymentready" -eq "1" ]; then
        dbrunning=`kubectl --kubeconfig=$KC exec -it $POD --namespace $PXCNAMESPACE -- /etc/init.d/mysql status 2>&1 | grep "running" | wc -l 2>&1`
        if [ "$dbrunning" -eq "1" ]; then
          kubectl --kubeconfig=$KC exec -it $POD --namespace $PXCNAMESPACE -- mysql --host=127.0.0.1 --protocol=TCP -u root -psingapore pxcentral < $PXCDB &>/dev/null
          pxcdbready="1"
          break
        fi
    fi
    showMessage "Waiting for PX-Central required components to be ready (5/7)"
    sleep $SLEEPINTERVAL
    timecheck=$[$timecheck+$SLEEPINTERVAL]
    if [ $timecheck -gt $TIMEOUT ]; then
      podName=`kubectl --kubeconfig=$KC get pods --namespace $PXCNAMESPACE 2>&1 | grep "pxc-mysql" | awk '{print $1}' | grep -v NAME 2>&1`
      echo ""
      echo "ERROR: PX-Central deployment is not ready, Contact: support@portworx.com"
      echo ""
      exit 1
    fi
  done

showMessage "Waiting for PX-Central required components to be ready (6/7)"
postsetupjob="0"
timecheck=0
count=0
while [ $postsetupjob -ne "1" ]
  do
    pxcpostsetupjob=`kubectl --kubeconfig=$KC get jobs --namespace $PXCNAMESPACE pxc-post-setup 2>&1 | awk '{print $2}' | grep -v COMPLETIONS | grep "1/1" | wc -l 2>&1`
    CHECKOIDCENABLE=`kubectl --kubeconfig=$KC get cm --namespace $PXCENTRALNAMESPACE pxc-admin-user -o jsonpath={.data.oidc} 2>&1`
    if [[ "$CHECKOIDCENABLE" == "true" && "$pxcpostsetupjob" -eq 1 ]]; then
      break
    fi
    count=$[$count+1]
    if [ "$count" -eq "1" ]; then
      kubectl --kubeconfig=$KC delete job pxc-post-setup --namespace $PXCNAMESPACE &>/dev/null
    fi
    if [ "$pxcpostsetupjob" -eq "1" ]; then
        postsetupjob="1"
        showMessage "Waiting for PX-Central required components to be ready (7/7)"
        break
    fi
    showMessage "Waiting for PX-Central required components to be ready (6/7)"
    sleep $SLEEPINTERVAL
    timecheck=$[$timecheck+$SLEEPINTERVAL]
    if [ $timecheck -gt $TIMEOUT ]; then
      echo ""
      echo "ERROR: PX-Central deployment is not ready, Contact: support@portworx.com"
      echo ""
      exit 1
    fi
  done

echo ""
echo -e -n "PX-Central cluster deployment complete."

echo ""
echo ""
echo "+================================================+"
echo "SAVE THE FOLLOWING DETAILS FOR FUTURE REFERENCES"
echo "+================================================+"
url="http://$PXENDPOINT:31234/frontend"
echo "PX-Central User Interface Access URL : $url"
timecheck=0
while true
  do
    status_code=$(curl --write-out %{http_code} --silent --output /dev/null $url)
    if [[ "$status_code" -eq 200 ]] ; then
      echo -e -n ""
      break
    fi
    showMessage "Validating PX-Central endpoint access."
    sleep $SLEEPINTERVAL
    timecheck=$[$timecheck+$SLEEPINTERVAL]
    if [ $timecheck -gt $LBSERVICETIMEOUT ]; then
      echo ""
      echo "ERROR: Failed to check PX-Central endpoint accessible, Contact: support@portworx.com"
      echo ""
    fi
  done
echo ""
echo -e -n ""

if [ "$OIDCENABLED" == "false" ]; then
  if [[ ( ${ADMINEMAIL} = "pxadmin@portworx.com" ) && ( ${ADMINUSER} = "pxadmin" ) ]]; then
    echo "PX-Central admin user name: $ADMINEMAIL"
    echo "PX-Central admin user password: $ADMINPASSWORD"
    echo ""
    echo "PX-Central grafana admin user name: $ADMINEMAIL"
    echo "PX-Central grafana admin user password: $ADMINPASSWORD"
  else if [ $ADMINUSER == "admin" ]; then
      echo "PX-Central admin user name: $ADMINEMAIL"
      echo "PX-Central admin user password: $ADMINPASSWORD"
      echo ""
      echo "PX-Central grafana admin user name: $ADMINUSER"
      echo "PX-Central grafana admin user password: admin"
      echo "Note: Change Grafana Admin User Password to '$ADMINPASSWORD' from Grafana"
    fi
  fi
else
  echo "OIDC enabled, Use OIDC user credentials to access PX-Central UI."
fi
echo "+================================================+"
echo ""
