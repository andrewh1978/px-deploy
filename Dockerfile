FROM centos:7
RUN rpm -i https://releases.hashicorp.com/vagrant/2.2.6/vagrant_2.2.6_x86_64.rpm
RUN yum install -y gcc make openssh-clients python3-pip
RUN pip3 install awscli
RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-278.0.0-linux-x86_64.tar.gz
RUN tar xzf google-cloud-sdk-278.0.0-linux-x86_64.tar.gz
RUN rm google-cloud-sdk-278.0.0-linux-x86_64.tar.gz
RUN ln -s /google-cloud-sdk/bin/gcloud /usr/bin/gcloud
RUN gcloud components install alpha -q
RUN vagrant plugin install vagrant-aws
RUN vagrant plugin install vagrant-google --plugin-version 2.5.0
RUN vagrant box add dummy https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box
RUN vagrant box add google/gce https://vagrantcloud.com/google/boxes/gce/versions/0.1.0/providers/google.box
COPY vagrant /px-deploy/vagrant
COPY px-deploy /px-deploy/px-deploy
