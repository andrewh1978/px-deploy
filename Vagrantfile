env = ENV.select { |key, value| key.start_with?("DEP", "GCP", "AWS") }

if !File.exist?("id_rsa")
  system("ssh-keygen -t rsa -b 2048 -f id_rsa -N ''");
  File.delete("id_rsa.pub") if File.exist?("id_rsa.pub")
end

Vagrant.configure("2") do |config|
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.provision "file", source: "id_rsa", destination: "/tmp/id_rsa"
  if ENV['DEP_CLOUD'] == "aws"
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
      override.ssh.private_key_path = ENV['AWS_sshkey_path']
    end
  elsif ENV['DEP_CLOUD'] == "gcp"
    config.vm.box = "google/gce"
    config.vm.provider :google do |gcp, override|
      gcp.google_project_id = ENV['GCP_PROJECT']
      gcp.zone = GCP_zone
      gcp.google_json_key_location = ENV['GCP_KEYFILE']
      gcp.image_family = "centos-7"
      gcp.machine_type = ENV['GCP_TYPE']
      gcp.disk_size = 15
      gcp.network = "px-net"
      gcp.subnetwork = "px-subnet"
      override.ssh.username = ENV['USER']
      override.ssh.private_key_path = ENV['GCP_sshkey_path']
    end
  end

  config.vm.provision "shell", path: "all-common", env: env
  config.vm.provision "shell", path: "#{ENV['DEP_PLATFORM']}-common"

  (1..ENV['DEP_CLUSTERS'].to_i).each do |c|
    subnet = "192.168.#{100+c}"
    config.vm.hostname = "master-#{c}"
    config.vm.define "master-#{c}" do |master|
      if ENV['DEP_CLOUD'] == "aws"
        master.vm.provider :aws do |aws|
          aws.private_ip_address = "#{subnet}.90"
          aws.tags = { "Name" => "master-#{c}" }
          aws.block_device_mapping = [{ :DeviceName => "/dev/sda1", "Ebs.DeleteOnTermination" => true, "Ebs.VolumeSize" => 15 }]
        end
      elsif ENV['DEP_CLOUD'] == "gcp"
        master.vm.provider :google do |gcp|
          gcp.name = "master-#{c}"
          gcp.network_ip = "#{subnet}.90"
        end
      end
      master.vm.provision "shell", path: "#{ENV['DEP_PLATFORM']}-master", env: (env.merge({ :c => c }))
      if ENV['DEP_INSTALL']
        ENV['DEP_INSTALL'].split(' ').each do |i|
          master.vm.provision "shell", path: "lib/#{i}", env: (env.merge({ :c => c }))
        end
      end
    end

    (1..ENV['DEP_NODES'].to_i).each do |n|
      config.vm.define "node-#{c}-#{n}" do |node|
        node.vm.hostname = "node-#{c}-#{n}"
        if ENV['DEP_CLOUD'] == "aws"
          node.vm.provider :aws do |aws|
            aws.private_ip_address = "#{subnet}.#{100+n}"
            aws.tags = { "Name" => "node-#{c}-#{n}" }
            aws.block_device_mapping = [{ :DeviceName => "/dev/sda1", "Ebs.DeleteOnTermination" => true, "Ebs.VolumeSize" => 15 }]
            d = 98
            ENV['AWS_EBS'].split(' ').each do |i|
              (type, size) = i.split(':')
              aws.block_device_mapping.push({ :DeviceName => "/dev/sd" + d.chr, "Ebs.DeleteOnTermination" => true, "Ebs.VolumeSize" => size, "Ebs.VolumeType" => type })
              d += 1
            end
          end
        elsif ENV['DEP_CLOUD'] == "gcp"
          node.vm.provider :google do |gcp|
            gcp.network_ip = "#{subnet}.#{100+n}"
            gcp.name = "node-#{c}-#{n}"
            d = 1
            ENV['GCP_DISKS'].split(' ').each do |i|
              (type, size) = i.split(':')
              gcp.additional_disks.push({ :disk_name => "disk-#{c}-#{n}-#{d}", :disk_type => type, :disk_size => size })
              d += 1
            end
          end
        end
        node.vm.provision "shell", path: "#{ENV['DEP_PLATFORM']}-node", env: (env.merge({ :c => c }))
      end
    end
  end
end
