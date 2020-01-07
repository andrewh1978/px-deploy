# Edit these parameters
clusters = 2
nodes = 3
disk_size = 20
cluster_name = "px-test-cluster"
version = "2.3.1"
journal = false

# Set cloud to one of "aws", "gcp"
cloud = "aws"

# Set platform to one of "k8s", "openshift"
platform = "k8s"

# Set K8s version
k8s_version="1.16.4"

# Set some cloud-specific parameters
AWS_keypair_name = "CHANGEME"
AWS_sshkey_path = "#{ENV['HOME']}/.ssh/id_rsa"
AWS_type = "t3.large"
AWS_hostname_prefix = ""

GCP_sshkey_path = "#{ENV['HOME']}/.ssh/id_rsa"
GCP_zone = "#{ENV['GCP_REGION']}-b"
GCP_key = "./gcp-key.json"
GCP_type = "n1-standard-2"
GCP_disk_type = "pd-standard"

# Do not edit below this line
if !File.exist?("id_rsa")
  system("ssh-keygen -t rsa -b 2048 -f id_rsa -N ''");
  File.delete("id_rsa.pub") if File.exist?("id_rsa.pub")
end

Vagrant.configure("2") do |config|

  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.provision "file", source: "id_rsa", destination: "/tmp/id_rsa"

  if cloud == "aws"
    config.vm.box = "dummy"
    config.vm.provider :aws do |aws, override|
      aws.security_groups = ENV['AWS_sg']
      aws.keypair_name = AWS_keypair_name
      aws.region = ENV['AWS_region']
      aws.instance_type = AWS_type
      aws.ami = ENV['AWS_ami']
      aws.subnet_id = ENV['AWS_subnet']
      aws.associate_public_ip = true
      override.ssh.username = "centos"
      override.ssh.private_key_path = AWS_sshkey_path
    end

  elsif cloud == "gcp"
    config.vm.box = "google/gce"
    config.vm.provider :google do |gcp, override|
      gcp.google_project_id = ENV['GCP_PROJECT']
      gcp.zone = GCP_zone
      gcp.google_json_key_location = GCP_key
      gcp.image_family = "centos-7"
      gcp.machine_type = GCP_type
      gcp.disk_type = GCP_disk_type
      gcp.disk_size = 15
      gcp.network = "px-net"
      gcp.subnetwork = "px-subnet"
      gcp.metadata = { "px-cloud_owner" => ENV['GCP_owner_tag'] }
      override.ssh.username = ENV['USER']
      override.ssh.private_key_path = GCP_sshkey_path
    end
  end

  env_ = { :cluster_name => cluster_name, :version => version, :journal => journal, :nodes => nodes, :clusters => clusters, :k8s_version => k8s_version }

  config.vm.provision "shell", path: "all-common", env: env_

  if platform == "k8s"
    config.vm.provision "shell", path: "k8s-common"

  elsif platform == "openshift"
    config.vm.provision "shell", path: "openshift-common"

  end

  (1..clusters).each do |c|
    hostname_master = "master-#{c}"
    ip_master = "192.168.#{100+c}.90"
    config.vm.hostname = hostname_master
    env = env_.merge({ :c => c, :ip_master => ip_master, :hostname_master => hostname_master })

    config.vm.define hostname_master do |master|

      if cloud == "aws"
        master.vm.provider :aws do |aws|
          aws.private_ip_address = ip_master
          aws.tags = { "px-cloud_owner" => ENV['AWS_owner_tag'], "Name" => "#{AWS_hostname_prefix}master-#{c}" }
          aws.block_device_mapping = [{ :DeviceName => "/dev/sda1", "Ebs.DeleteOnTermination" => true, "Ebs.VolumeSize" => 15 }]
        end

      elsif cloud == "gcp"
        master.vm.provider :google do |gcp|
          gcp.name = hostname_master
          gcp.network_ip = ip_master
        end
      end

      master.vm.provision "shell", path: "#{platform}-master", env: env

    end

    (1..nodes).each do |n|
      config.vm.define "node-#{c}-#{n}" do |node|
        node.vm.hostname = "node-#{c}-#{n}"
        if cloud == "aws"
          node.vm.provider :aws do |aws|
            aws.private_ip_address = "192.168.#{100+c}.#{100+n}"
            aws.tags = { "px-cloud_owner" => ENV['AWS_owner_tag'], "Name" => "#{AWS_hostname_prefix}node-#{c}-#{n}" }
            aws.block_device_mapping = [{ :DeviceName => "/dev/sda1", "Ebs.DeleteOnTermination" => true, "Ebs.VolumeSize" => 15 }, { :DeviceName => "/dev/sdb", "Ebs.DeleteOnTermination" => true, "Ebs.VolumeSize" => disk_size }]
            if journal
              aws.block_device_mapping.push({ :DeviceName => "/dev/sdc", "Ebs.DeleteOnTermination" => true, "Ebs.VolumeSize" => 3 })
            end
          end

        elsif cloud == "gcp"
          node.vm.provider :google do |gcp|
            gcp.network_ip = "192.168.#{100+c}.#{100+n}"
            gcp.name = "node-#{c}-#{n}"
            gcp.additional_disks = [{ :disk_size => disk_size, :disk_name => "disk-#{c}-#{n}" }]
            if journal
              gcp.additional_disks.push({ :disk_size => 3, :disk_name => "journal-#{c}-#{n}" })
            end
          end
        end

        node.vm.provision "shell", path: "#{platform}-node", env: env

      end
    end
  end
end
