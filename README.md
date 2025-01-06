# 🏠 <img src="https://github.com/user-attachments/assets/30540933-e9fa-49e3-b819-7ba64f104878" width="31" height="31"> Kubernetes Homelab

Welcome to my Kubernetes Homelab repository! This is where I document my journey about cloud-native technologies and self-hosting applications. This homelab is more than a playground—it's a platform where I explore ideas, automate workflows, and solve complex challenges while having fun.

As a **Cloud Solutions Architect**, Kubernetes is part of my daily toolkit. This homelab represents my passion for learning and experimenting with technology, focusing on scalability, backup strategies, and operational simplicity.

---

## 🚀 Why a Homelab?

The purpose of this homelab is:
1. **Learning by Doing**: By self-hosting, I tackle the complexities of deploying and managing real-world applications.
2. **All-in-One Environment**: This homelab serves as a single, integrated environment for testing, developing, and automating cloud-native workflows.

---

## 🖥️ My Hardware

To keep things simple yet powerful, my homelab runs on the following hardware:
- **Beelink Mini PC 12 Pro**: Powered by an Intel N100, with 16GB RAM and 500GB NVMe SSD.
- **Raspberry Pi 4**: A lightweight option for testing Kubernetes in constrained environments (4GB RAM with 120GB SSD).

This combination offers flexibility and low energy consumption while supporting diverse workloads.

---

## 🔧 Tools and Applications

The homelab runs a variety of applications, deployed using Kubernetes and managed declaratively through GitOps. Here’s an overview of the setup:

- **Kubernetes**: The backbone for workload orchestration, ensuring high availability and scalability.
- **ArgoCD**: Automates deployments and updates via GitOps workflows, keeping the cluster state consistent with repository configurations.
- **Longhorn**: Distributed storage solution for resilient and scalable data management.
- **Prometheus and Grafana**: Monitoring and observability for tracking cluster performance and health.
- **Home Assistant**: An open-source home automation platform to manage smart devices in the homelab.
- **Uptime Kuma**: A modern uptime monitoring tool for tracking the status of services and websites.
- **Homarr**: A sleek and customizable dashboard to centralize access to various applications.
- **Kube-Prometheus-Stack**: Comprehensive monitoring and alerting stack with Prometheus, Grafana, and Alertmanager.

---

## 📂 What’s in This Repository?

This repository is structured to organize and simplify the management of my Kubernetes homelab:

- `apps/`: Contains deployment configurations (Helm charts or raw manifests) for each application.
- `argocd-apps/`: Includes ArgoCD-specific application manifests and GitOps configurations for managing deployments declaratively.
- `cluster/`: Defines Kubernetes cluster-wide configurations, such as networking, storage, and infrastructure setup.



---

## 📈 My Goals

- **Deepen Kubernetes Knowledge**: Dive deep into advanced Kubernetes concepts, such as networking, GitOps or federation.
- **Enhance Resilience**: Design a self-hosted environment with reliable backups and minimal downtime.
- **Share Knowledge**: Document my progress and learnings to help others interested in setting up their own homelab.

---

This homelab is a work in progress, and I look forward to expanding it further. Feel free to explore the repository, provide feedback, or draw inspiration for your own Kubernetes journey!
