require "base64"
env = ENV.select { |key, value| key.start_with?("DEP", "GCP", "AWS", "_AWS", "_GCP") }

system("ssh-keygen -t rsa -b 2048 -f id_rsa -N ''") if !File.exist?("id_rsa")
File.delete("id_rsa.pub") if File.exist?("id_rsa.pub")

Vagrant.configure("2") do |config|
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.provision "file", source: "id_rsa", destination: "/tmp/id_rsa"
  if ENV['DEP_CLOUD'] == "aws"
    config.vm.box = "dummy"
    config.vm.provider :aws do |aws, override|
      aws.security_groups = ENV['_AWS_sg']
      aws.keypair_name = ENV['AWS_KEYPAIR']
      aws.region = ENV['AWS_REGION']
      aws.instance_type = ENV['AWS_TYPE']
      aws.ami = ENV['_AWS_ami']
      aws.subnet_id = ENV['_AWS_subnet']
      aws.associate_public_ip = true
      aws.block_device_mapping = [{ :DeviceName => "/dev/sda1", "Ebs.DeleteOnTermination" => true, "Ebs.VolumeSize" => 15 }]
      override.ssh.username = "centos"
      override.ssh.private_key_path = ENV['DEP_SSHKEY']
    end
  elsif ENV['DEP_CLOUD'] == "gcp"
    config.vm.box = "google/gce"
    config.vm.provider :google do |gcp, override|
      File.open("px-deploy_gcp_#{ENV['_GCP_project']}.json", "w") do |line| line.puts(Base64.decode64(ENV['_GCP_key'])) end
      gcp.google_project_id = ENV['_GCP_project']
      gcp.zone = "#{ENV['GCP_REGION']}-#{ENV['GCP_ZONE']}"
      gcp.google_json_key_location = "px-deploy_gcp_#{ENV['_GCP_project']}.json";
      gcp.image_family = "centos-7"
      gcp.machine_type = ENV['GCP_TYPE']
      gcp.disk_size = 15
      gcp.network = "px-net"
      gcp.subnetwork = "px-subnet"
      override.ssh.username = ENV['USER']
      override.ssh.private_key_path = ENV['DEP_SSHKEY']
    end
  end

  config.vm.provision "shell", path: "all-common", env: env
  config.vm.provision "shell", path: "#{ENV['DEP_PLATFORM']}-common"

  (1..ENV['DEP_CLUSTERS'].to_i).each do |c|
    subnet = "192.168.#{100+c}"
    config.vm.define "#{ENV['DEP_ENV']}-master-#{c}" do |master|
      master.vm.hostname = "master-#{c}"
      if ENV['DEP_CLOUD'] == "aws"
        master.vm.provider :aws do |aws|
          aws.private_ip_address = "#{subnet}.90"
          aws.tags = { "Name" => "master-#{c}" }
        end
      elsif ENV['DEP_CLOUD'] == "gcp"
        master.vm.provider :google do |gcp|
          gcp.name = "master-#{c}"
          gcp.network_ip = "#{subnet}.90"
        end
      end
      master.vm.provision "shell", path: "#{ENV['DEP_PLATFORM']}-master", env: (env.merge({ :cluster => c }))
      ENV['DEP_SCRIPTS'].split(' ').each do |i| master.vm.provision "shell", path: "scripts/#{i}", env: (env.merge({ :cluster => c, :script => i })) end if ENV['DEP_SCRIPTS']
    end

    (1..ENV['DEP_NODES'].to_i).each do |n|
      config.vm.define "#{ENV['DEP_ENV']}-node-#{c}-#{n}" do |node|
        node.vm.hostname = "node-#{c}-#{n}"
        if ENV['DEP_CLOUD'] == "aws"
          node.vm.provider :aws do |aws|
            aws.private_ip_address = "#{subnet}.#{100+n}"
            aws.tags = { "Name" => "node-#{c}-#{n}" }
            d = 97
            ENV['AWS_EBS'].split(' ').each do |i|
              (type, size) = i.split(':')
              aws.block_device_mapping.push({:DeviceName => "/dev/sd#{(d+=1).chr}", "Ebs.DeleteOnTermination" => true, "Ebs.VolumeSize" => size, "Ebs.VolumeType" => type })
            end
          end
        elsif ENV['DEP_CLOUD'] == "gcp"
          node.vm.provider :google do |gcp|
            gcp.network_ip = "#{subnet}.#{100+n}"
            gcp.name = "node-#{c}-#{n}"
            d = 0
            ENV['GCP_DISKS'].split(' ').each do |i|
              (type, size) = i.split(':')
              gcp.additional_disks.push({ :disk_name => "disk-#{c}-#{n}-#{d+=1}", :disk_type => type, :disk_size => size })
            end
          end
        end
        node.vm.provision "shell", path: "#{ENV['DEP_PLATFORM']}-node", env: (env.merge({ :cluster => c }))
      end
    end
  end
end
