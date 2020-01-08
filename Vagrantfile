AWS_sshkey_path = "#{ENV['HOME']}/.ssh/id_rsa"
GCP_sshkey_path = "#{ENV['HOME']}/.ssh/id_rsa"
GCP_zone = "#{ENV['GCP_REGION']}-b"

if !File.exist?("id_rsa")
  system("ssh-keygen -t rsa -b 2048 -f id_rsa -N ''");
  File.delete("id_rsa.pub") if File.exist?("id_rsa.pub")
end

Vagrant.configure("2") do |config|
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.provision "file", source: "id_rsa", destination: "/tmp/id_rsa"
  if ENV['PX_CLOUD'] == "aws"
    config.vm.box = "dummy"
    config.vm.provider :aws do |aws, override|
      aws.security_groups = ENV['AWS_sg']
      aws.keypair_name = ENV['AWS_keypair']
      aws.region = ENV['AWS_region']
      aws.instance_type = ENV['AWS_TYPE']
      aws.ami = ENV['AWS_ami']
      aws.subnet_id = ENV['AWS_subnet']
      aws.associate_public_ip = true
      override.ssh.username = "centos"
      override.ssh.private_key_path = AWS_sshkey_path
    end
  elsif ENV['PX_CLOUD'] == "gcp"
    config.vm.box = "google/gce"
    config.vm.provider :google do |gcp, override|
      gcp.google_project_id = ENV['GCP_PROJECT']
      gcp.zone = GCP_zone
      gcp.google_json_key_location = ENV['GCP_KEYFILE']
      gcp.image_family = "centos-7"
      gcp.machine_type = ENV['GCP_TYPE']
      gcp.disk_type = ENV['GCP_DISKTYPE']
      gcp.disk_size = 15
      gcp.network = "px-net"
      gcp.subnetwork = "px-subnet"
      override.ssh.username = ENV['USER']
      override.ssh.private_key_path = GCP_sshkey_path
    end
  end

  env = { :cluster_name => ENV['PX_CLUSTERNAME'], :version => ENV['PX_VERSION'], :nodes => ENV['PX_NODES'], :clusters => ENV['PX_CLUSTERS'], :k8s_version => ENV['PX_K8S_VERSION'] }
  config.vm.provision "shell", path: "all-common", env: env
  config.vm.provision "shell", path: "#{ENV['PX_PLATFORM']}-common"

  (1..ENV['PX_CLUSTERS'].to_i).each do |c|
    subnet = "192.168.#{100+c}"
    config.vm.hostname = "master-#{c}"
    config.vm.define "master-#{c}" do |master|
      if ENV['PX_CLOUD'] == "aws"
        master.vm.provider :aws do |aws|
          aws.private_ip_address = "#{subnet}.90"
          aws.tags = { "Name" => "master-#{c}" }
          aws.block_device_mapping = [{ :DeviceName => "/dev/sda1", "Ebs.DeleteOnTermination" => true, "Ebs.VolumeSize" => 15 }]
        end
      elsif ENV['PX_CLOUD'] == "gcp"
        master.vm.provider :google do |gcp|
          gcp.name = "master-#{c}"
          gcp.network_ip = "#{subnet}.90"
        end
      end
      master.vm.provision "shell", path: "#{ENV['PX_PLATFORM']}-master", env: (env.merge({ :c => c }))
    end

    (1..ENV['PX_NODES'].to_i).each do |n|
      config.vm.define "node-#{c}-#{n}" do |node|
        node.vm.hostname = "node-#{c}-#{n}"
        if ENV['PX_CLOUD'] == "aws"
          node.vm.provider :aws do |aws|
            aws.private_ip_address = "#{subnet}.#{100+n}"
            aws.tags = { "Name" => "node-#{c}-#{n}" }
            aws.block_device_mapping = [{ :DeviceName => "/dev/sda1", "Ebs.DeleteOnTermination" => true, "Ebs.VolumeSize" => 15 }, { :DeviceName => "/dev/sdb", "Ebs.DeleteOnTermination" => true, "Ebs.VolumeSize" => ENV['PX_DISKSIZE'] }]
          end
        elsif ENV['PX_CLOUD'] == "gcp"
          node.vm.provider :google do |gcp|
            gcp.network_ip = "#{subnet}.#{100+n}"
            gcp.name = "node-#{c}-#{n}"
            gcp.additional_disks = [{ :disk_size => ENV['PX_DISKSIZE'], :disk_name => "disk-#{c}-#{n}" }]
          end
        end
        node.vm.provision "shell", path: "#{ENV['PX_PLATFORM']}-node", env: (env.merge({ :c => c }))
      end
    end
  end
end
