FROM centos:7
RUN curl -s https://mirror.go-repo.io/centos/go-repo.repo >/etc/yum.repos.d/go-repo.repo
RUN yum install -y gcc make openssh-clients python3-pip golang git
RUN echo ServerAliveInterval 300 >/etc/ssh/ssh_config
RUN echo ServerAliveCountMax 2 >>/etc/ssh/ssh_config
RUN echo TCPKeepAlive yes >>/etc/ssh/ssh_config
RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-278.0.0-linux-x86_64.tar.gz
RUN tar xzf google-cloud-sdk-278.0.0-linux-x86_64.tar.gz
RUN rm google-cloud-sdk-278.0.0-linux-x86_64.tar.gz
RUN ln -s /google-cloud-sdk/bin/gcloud /usr/bin/gcloud
RUN gcloud components install alpha -q
RUN rpm -i https://releases.hashicorp.com/vagrant/2.2.6/vagrant_2.2.6_x86_64.rpm
RUN vagrant plugin install vagrant-google --plugin-version 2.5.0
RUN vagrant plugin install vagrant-aws
RUN vagrant box add dummy https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box
RUN vagrant box add google/gce https://vagrantcloud.com/google/boxes/gce/versions/0.1.0/providers/google.box
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
