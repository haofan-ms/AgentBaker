[Unit]
Description=Kubelet
ConditionPathExists=/usr/local/bin/kubelet


[Service]
Restart=always
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
EnvironmentFile=/etc/default/kubelet
SuccessExitStatus=143
ExecStartPre=/bin/bash /opt/azure/containers/kubelet.sh
ExecStartPre=/bin/mkdir -p /var/lib/kubelet
ExecStartPre=/bin/mkdir -p /var/lib/cni
ExecStartPre=/bin/bash -c "if [ $(mount | grep \"/var/lib/kubelet\" | wc -l) -le 0 ] ; then /bin/mount --bind /var/lib/kubelet /var/lib/kubelet ; fi"
ExecStartPre=/bin/mount --make-shared /var/lib/kubelet

ExecStartPre=-/sbin/ebtables -t nat --list
ExecStartPre=-/sbin/iptables -t nat --numeric --list

ExecStart=/usr/local/bin/kubelet \
        $KUBELET_KUBEADM_ARGS \
        --enable-server \
        --node-labels="${KUBELET_NODE_LABELS}" \
        --v=2 --container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/containerd/containerd.sock \
        --volume-plugin-dir=/etc/kubernetes/volumeplugins \
        $KUBELET_FLAGS \
        $KUBELET_REGISTER_NODE $KUBELET_REGISTER_WITH_TAINTS

[Install]
WantedBy=multi-user.target