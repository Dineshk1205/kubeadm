yum install haproxy keepalived -y

mv /etc/keepalived/keepalived.conf  /etc/keepalived/keepalived.conf.backup

cat <<EOF | sudo tee /etc/keepalived/keepalived.conf
vrrp_script chk_haproxy {
script "killall -0 haproxy"
interval 2
weight 2
}
vrrp_instance VI_1 {
interface ens190
state MASTER
advert_int 1
virtual_router_id 51
priority 101
unicast_src_ip 172.90.0.16 ## Master-01 IP Address
unicast_peer {
172.90.0.17 ## Enter Master-02 IP Address
172.90.0.18 ## Enter Master-03 IP Address
}
virtual_ipaddress {
172.90.0.15 ## Enter Virtual IP address
}
track_script {
chk_haproxy
}
}
EOF


systemctl start keepalived && systemctl enable keepalived

mv /etc/haproxy/haproxy.cfg   /etc/haproxy/haproxy.cfg.backup

cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
global
log 127.0.0.1 local2
chroot /var/lib/haproxy
pidfile /var/run/haproxy.pid
maxconn 4000
user haproxy
group haproxy
daemon
# turn on stats unix socket
stats socket /var/lib/haproxy/stats
#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
mode http
log global
option httplog
option dontlognull
option http-server-close
option forwardfor except 127.0.0.0/8
option redispatch
retries 3
timeout http-request 10s
timeout queue 1m
timeout connect 10s
timeout client 1m
timeout server 1m
timeout http-keep-alive 10s
timeout check 10s
maxconn 3000
#---------------------------------------------------------------------
# apiserver frontend which proxys to the masters
#---------------------------------------------------------------------
frontend apiserver
bind *:8443
mode tcp
option tcplog
default_backend apiserver
#---------------------------------------------------------------------
# round robin balancing for apiserver
#---------------------------------------------------------------------
backend apiserver
option httpchk GET /healthz
http-check expect status 200
mode tcp
option ssl-hello-chk
balance roundrobin
server master0 172.90.0.16:6443 check
server master1 172.90.0.17:6443 check
server master2 172.90.0.18:6443 check
EOF

systemctl restart haproxy && systemctl enable haproxy

