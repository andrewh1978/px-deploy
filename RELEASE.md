# 4.16

## Improvements
 * Lots of awstf updates
 * Add containerd to support Kubernetes 1.25
 * Add OCP4 support for awstf
 * Petclinic now always in its own namespace
 * Bump PX-Central to 2.3.2
 * Bump OCP version to 4.10.37

## Fixes
 * Fix intermittent vSphere provisioning bug

# 4.15

## Improvements
 * Lots of awstf updates
 * Refactor training
 * Remove OCP3 support
 * Add performance Grafana dashboard
 * Add gke_version parameter

# 4.14

## Improvements
 * Bump PX-Central to 2.3.0
 * Bump Portworx to 2.11.3
 * Add new cloud awstf - migrate AWS support to Terraform (testing)
 * Add nginx asset

# 4.13.4

## Improvements
 * Bump Flannel to 0.19.2

# 4.13.3

## Improvements
 * Add pxc to .bashrc
 * Bump Portworx to 2.10.3
 * Bump PX-Central to 2.2.1

## Fixes
 * Fix vagrant-vsphere provisioning race condition

# 4.13.2

## Fixes
 * Specify vagrant-vsphere plugin version to fix provision bug

# 4.13.1

## Fixes
 * Bump Vagrant to 2.2.19 to fix build bug

# 4.13

## Improvements
 * Add nomad as a platform
 * Bump PX-Central to 2.2.0
 * Bump Portworx to 2.10.3

## Fixes
 * Find soon-to-be-deprecated CentOS 7 AMI

# 4.12.1

## Improvements
 * Install Helm on EKS
 * Bump Portworx to 2.10.1

## Fixes
 * kubectl/eksctl incompatibility
 * Grafana on EKS

# 4.12

## Improvements
 * Add `kubectl pxc pxctl`
 * Update PX-Central to 2.1.2
 * Update Portworx operator to 1.6.1
 * Bump Kubernetes to 1.21.11
 * Bump Portworx to 2.10.0

## Fixes
 * EKS IAM provisioning
