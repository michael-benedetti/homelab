# Homelab Setup

This is my personal homelab setup which runs on a multi-node k3s cluster.  Everything can be spun up with the provided `run.sh` script and torn down with `uninstall.sh`.  Service yaml configs are found in [yaml](yaml/) and configurations as you would expect in [config](config/)

Currently, the following services are included:

- [Bamboo Server](https://www.atlassian.com/software/bamboo)
- [D3Compare](https://github.com/michael-benedetti/d3compare)
- [Kube-Prometheus-Stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Heimdall](https://heimdall.site/)
- [Pi-Hole](https://pi-hole.net/)
- [Statping](https://github.com/statping/statping)
- [Unifi Controller](https://hub.docker.com/r/linuxserver/unifi-controller)

Two additional yamls are provided but not deployed automatically in `run.sh`:

- [A Simple Minecraft Paper Server](https://papermc.io/)
- [DVWA](https://dvwa.co.uk/)
