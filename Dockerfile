FROM --platform=linux/amd64 rockylinux:8
#RUN echo W2F6dXJlLWNsaV0KbmFtZT1BenVyZSBDTEkKYmFzZXVybD1odHRwczovL3BhY2thZ2VzLm1pY3Jvc29mdC5jb20veXVtcmVwb3MvYXp1cmUtY2xpCmVuYWJsZWQ9MQpncGdjaGVjaz0xCmdwZ2tleT1odHRwczovL3BhY2thZ2VzLm1pY3Jvc29mdC5jb20va2V5cy9taWNyb3NvZnQuYXNjCg== | base64 -d >/etc/yum.repos.d/azure-cli.repo
RUN dnf install -y gcc make openssh-clients python3-pip golang git epel-release openssl gcc-c++ mkisofs # azure-cli
RUN dnf install -y jq
RUN echo ServerAliveInterval 300 >/etc/ssh/ssh_config
RUN echo ServerAliveCountMax 2 >>/etc/ssh/ssh_config
RUN echo TCPKeepAlive yes >>/etc/ssh/ssh_config
RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-338.0.0-linux-x86_64.tar.gz
RUN tar xzf google-cloud-sdk-338.0.0-linux-x86_64.tar.gz
RUN rm google-cloud-sdk-338.0.0-linux-x86_64.tar.gz
RUN ln -s /google-cloud-sdk/bin/gcloud /usr/bin/gcloud
RUN gcloud components install alpha -q
RUN rpm -i https://releases.hashicorp.com/vagrant/2.2.19/vagrant_2.2.19_x86_64.rpm
RUN rpm -i https://rpm.releases.hashicorp.com/RHEL/7/x86_64/stable/packer-1.6.5-1.x86_64.rpm
RUN vagrant plugin install vagrant-google --plugin-version 2.5.0
#RUN vagrant plugin install vagrant-azure
RUN vagrant plugin install vagrant-vsphere --plugin-version 1.13.5
RUN vagrant box add google/gce https://vagrantcloud.com/google/boxes/gce/versions/0.1.0/providers/google.box --provider google
#RUN vagrant box add azure https://github.com/azure/vagrant-azure/raw/v2.0/dummy.box --provider azure --provider azure
RUN vagrant box add FEBO/oracle8 --provider vsphere
RUN curl -Ls https://github.com/vmware/govmomi/releases/download/v0.23.0/govc_linux_amd64.gz | zcat >/usr/bin/govc
RUN mkdir -p /root/go/src/px-deploy
RUN curl -s https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo >/etc/yum.repos.d/terraform-repo.repo
RUN dnf install -y terraform-1.3.9
COPY go.mod go.sum px-deploy.go /root/go/src/px-deploy/
COPY vagrant /px-deploy/vagrant
COPY terraform /px-deploy/terraform
COPY vsphere-init.sh VERSION /
RUN terraform -chdir=/px-deploy/terraform/aws/ init
RUN terraform -chdir=/px-deploy/terraform/azure/ init
RUN chmod 755 /usr/bin/govc /vsphere-init.sh
RUN cd /root/go/src/px-deploy ; go install
