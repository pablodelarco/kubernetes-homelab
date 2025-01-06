# 🏠 <img src="https://github.com/user-attachments/assets/30540933-e9fa-49e3-b819-7ba64f104878" width="31" height="31"> Kubernetes Homelab

Welcome to my Kubernetes Homelab repository! This is where I document my journey about cloud-native technologies and self-hosting applications. My homelab is more than just a learning tool—it's a space where I experiment with new ideas, automate processes, and have fun solving challenges.

As a Cloud Solutions Architect, I work with Kubernetes daily, and this homelab is an extension of my passion for technology. Here, I aim to deploy and manage applications while focusing on scalability, backup strategies, and operational simplicity.

---

## 🚀 Why a Homelab?

The purpose of this homelab is twofold:
1. **Learning by Doing**: By self-hosting, I explore the complexities of deploying and managing real-world applications.
2. **All-in-One Environment**: This homelab serves as a single, integrated environment for testing, developing, and automating cloud-native workflows.

---

## 🖥️ My Hardware

To keep things simple yet powerful, my homelab runs on the following hardware:
- **Beelink Mini PC 12 Pro**: Powered by an AMD Ryzen 7 5800H, with 16GB RAM and 500GB NVMe SSD for robust performance.
- **Raspberry Pi 4 (4GB RAM)**: A lightweight companion for edge workloads and testing Kubernetes in constrained environments.

This combination offers flexibility and low energy consumption while supporting diverse workloads.

---

## 🔧 Tools and Applications

The homelab runs a variety of applications, deployed using Kubernetes and managed declaratively through GitOps. Here’s an overview of the setup:

- **Cluster Orchestration**: Kubernetes provides the foundation for managing workloads, ensuring high availability and scalability.
- **Database Management**: PostgreSQL handles application data, with regular automated backups to an object store.
- **Automation with GitOps**: Using ArgoCD, all deployments and updates are handled through a GitOps workflow. Changes to this repository trigger automatic synchronization, ensuring the cluster state matches the desired configuration.
- **Persistent Storage**: Local SSDs are used for high-performance storage, with plans to integrate additional storage solutions for backups.

---

## 🌟 Guiding Principles

1. **Automation First**: Every process—from deployment to backups—is automated to reduce manual effort.
2. **Declarative Configurations**: All configurations are stored as code in this repository, ensuring transparency and repeatability.
3. **Simplicity and Performance**: Tools and applications are chosen to strike a balance between simplicity and performance.

---

## 📂 What’s in This Repository?

This repository is structured to organize and simplify the management of my Kubernetes homelab:

- **Applications**: Each application is stored in its own folder under `apps/`, with deployment configurations using Helm charts or raw manifests.
- **Cluster Configuration**: Kubernetes cluster setup and networking configurations are defined in the `infrastructure/` directory.
- **Automation**: GitHub Actions workflows are included to trigger ArgoCD syncs automatically when changes are made.

---

## 📈 My Goals

- **Explore Kubernetes**: Dive deep into advanced Kubernetes concepts, from networking to persistent storage.
- **Build Resilience**: Design a self-hosted environment with reliable backups and minimal downtime.
- **Share Knowledge**: Document my progress and learnings to help others interested in setting up their own homelab.

---

## 🚧 Ongoing Experiments

1. **Deploying Edge Workloads**: Leveraging the Raspberry Pi for lightweight edge computing.
2. **Monitoring and Observability**: Integrating tools like Prometheus and Grafana for cluster monitoring.
3. **CI/CD Pipelines**: Enhancing automation workflows with GitHub Actions.

---

This homelab is a work in progress, and I look forward to expanding it further. Feel free to explore the repository, provide feedback, or draw inspiration for your own Kubernetes journey!
