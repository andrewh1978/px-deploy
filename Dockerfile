FROM centos:7
RUN curl -s https://mirror.go-repo.io/centos/go-repo.repo >/etc/yum.repos.d/go-repo.repo
RUN echo W2F6dXJlLWNsaV0KbmFtZT1BenVyZSBDTEkKYmFzZXVybD1odHRwczovL3BhY2thZ2VzLm1pY3Jvc29mdC5jb20veXVtcmVwb3MvYXp1cmUtY2xpCmVuYWJsZWQ9MQpncGdjaGVjaz0xCmdwZ2tleT1odHRwczovL3BhY2thZ2VzLm1pY3Jvc29mdC5jb20va2V5cy9taWNyb3NvZnQuYXNjCg== | base64 -d >/etc/yum.repos.d/azure-cli.repo
RUN yum install -y gcc make openssh-clients python3-pip golang git azure-cli
RUN echo ServerAliveInterval 300 >/etc/ssh/ssh_config
RUN echo ServerAliveCountMax 2 >>/etc/ssh/ssh_config
RUN echo TCPKeepAlive yes >>/etc/ssh/ssh_config
RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-278.0.0-linux-x86_64.tar.gz
RUN tar xzf google-cloud-sdk-278.0.0-linux-x86_64.tar.gz
RUN rm google-cloud-sdk-278.0.0-linux-x86_64.tar.gz
RUN ln -s /google-cloud-sdk/bin/gcloud /usr/bin/gcloud
RUN gcloud components install alpha -q
RUN rpm -i https://releases.hashicorp.com/vagrant/2.2.9/vagrant_2.2.9_x86_64.rpm
RUN vagrant plugin install vagrant-google --plugin-version 2.5.0
RUN vagrant plugin install vagrant-aws
RUN vagrant plugin install vagrant-azure
RUN vagrant box add dummy https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box --provider aws
RUN vagrant box add google/gce https://vagrantcloud.com/google/boxes/gce/versions/0.1.0/providers/google.box --provider google
RUN vagrant box add azure https://github.com/azure/vagrant-azure/raw/v2.0/dummy.box --provider azure --provider azure
RUN pip3 install awscli
RUN go get -u github.com/olekukonko/tablewriter
RUN go get -u github.com/spf13/cobra/cobra
RUN go get -u github.com/google/uuid
RUN go get -u github.com/go-yaml/yaml
RUN go get -u github.com/imdario/mergo
RUN mkdir /root/go/src/px-deploy
COPY px-deploy.go /root/go/src/px-deploy/main.go
COPY vagrant /px-deploy/vagrant
RUN go install px-deploy
