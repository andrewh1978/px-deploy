# Run an etcd container
docker run -d --restart unless-stopped -v /usr/share/ca-certificates/:/etc/ssl/certs -p 2382:2382 \
 --name etcd quay.io/coreos/etcd:latest \
 /usr/local/bin/etcd \
 -name etcd0 \
 -auto-compaction-retention=3 -quota-backend-bytes=8589934592 \
 -advertise-client-urls http://$(hostname -i):2382 \
 -listen-client-urls http://0.0.0.0:2382
