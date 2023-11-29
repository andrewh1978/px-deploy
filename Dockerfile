FROM --platform=linux/amd64 golang:1.20-alpine3.18 AS build
RUN wget -P / https://releases.hashicorp.com/terraform/1.6.1/terraform_1.6.1_linux_amd64.zip
RUN unzip /terraform_1.6.1_linux_amd64.zip -d /usr/bin/
RUN wget -P / https://github.com/vmware/govmomi/releases/download/v0.33.0/govc_Linux_x86_64.tar.gz
RUN tar -xzf /govc_Linux_x86_64.tar.gz -C /usr/bin/
RUN mkdir -p /root/go/src/px-deploy
COPY go.mod go.sum *.go /root/go/src/px-deploy/
RUN cd /root/go/src/px-deploy ; go install
COPY terraform /px-deploy/terraform
RUN terraform -chdir=/px-deploy/terraform/aws/ init
RUN terraform -chdir=/px-deploy/terraform/azure/ init
RUN terraform -chdir=/px-deploy/terraform/gcp/ init
RUN terraform -chdir=/px-deploy/terraform/vsphere/ init


FROM --platform=linux/amd64 alpine:3.18
RUN apk add --no-cache openssh-client-default bash
RUN echo ServerAliveInterval 300 >/etc/ssh/ssh_config
RUN echo ServerAliveCountMax 2 >>/etc/ssh/ssh_config
RUN echo TCPKeepAlive yes >>/etc/ssh/ssh_config
COPY --from=build /usr/bin/terraform /usr/bin/terraform
COPY --from=build /usr/bin/govc /usr/bin/govc
COPY vagrant /px-deploy/vagrant
#COPY terraform /px-deploy/terraform
COPY VERSION /
COPY --from=build /go/bin/px-deploy /root/go/bin/px-deploy
COPY --from=build /px-deploy/terraform/aws /px-deploy/terraform/aws 
COPY --from=build /px-deploy/terraform/azure /px-deploy/terraform/azure
COPY --from=build /px-deploy/terraform/gcp /px-deploy/terraform/gcp
COPY --from=build /px-deploy/terraform/vsphere /px-deploy/terraform/vsphere 
