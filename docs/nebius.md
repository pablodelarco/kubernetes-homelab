. I've compiled the final instructions for you below. You can copy and paste this Markdown directly into your report or file.

# Creating and modifying Managed Service for Kubernetes® node groups

Clusters in Managed Service for Kubernetes use Compute virtual machines as nodes to run applications. In this guide, you will learn how to create node groups, add them to clusters, modify and delete them.

To learn how to manage clusters outside of their node groups, see [How to create and modify Managed Service for Kubernetes® clusters](https://docs.nebius.com/kubernetes/clusters/manage).

## Prerequisites

Before creating a node group, first create a cluster. For more information, see [How to create clusters](https://docs.nebius.com/kubernetes/clusters/manage#create).

## How to create node groups

Node groups define the characteristics of the virtual machines (VMs) that run your workloads. Each node group includes identical nodes created with the same template.

### Regular node groups

1. In the sidebar, go to **Compute** → **Kubernetes**.
2. Click the name of the cluster where you want to create a node group.
3. On the cluster page, switch to the **Node groups** tab.
4. Click **Create node group**.
5. On the page that opens, enter the **Name** for the node group (e.g., `mk8s-node-group-test`).
6. (Optional) Enable the **Assign public IPv4 addresses** toggle if you want the nodes to be accessible from the internet.
7. Under **Size**, specify the **Number of nodes**. Ensure the **Enable autoscaling** toggle is off if you want a fixed size.
8. Under **Computing resources**, choose the hardware configuration for your nodes:
* **Without GPU**: For standard workloads.
* **With GPU**: For compute-intensive AI and ML workloads.


9. Select the **VM type**:
* **Regular**: Standard VMs for high-availability production workloads.
* **Preemptible**: Lower-cost VMs that may be terminated by the platform at any time.


10. Select an **Available platform** and a **Preset** (a combination of vCPUs and RAM) that fits your workload requirements.
11. (Optional) **GPU settings**: When using a platform **With GPU**, you can manage the software stack:
* **Automated setup**: By default, the system pre-installs NVIDIA drivers and the Container Toolkit. You can select the specific **CUDA driver version** from the available options.
* **Manual setup**: Disable this option only if you need to install specific driver versions or use a custom operator.


12. Select the **Operating system** for the nodes (e.g., `Ubuntu 24.04 LTS`).
13. Under **Node storage**, select the **Disk type** and specify the **Size** in GiB.
* **SSD**: Standard solid-state drive for general-purpose workloads.
* **SSD NRD**: Network-replicated SSD providing higher reliability through data duplication across the network.
* **SSD IO**: High-performance SSD optimized for I/O-intensive operations with lower latency.


14. (Optional) Under **Shared filesystems**, click **+ Attach shared filesystem** to mount existing network storage.
15. In the **Access** section, click **+ Create** to add a **Username and SSH key**.
16. (Optional) Under **Additional**, select or create a **Service account** that will perform actions on behalf of the nodes.
17. Click **Create node group**.

The maximum number of nodes per node group is 100.

### Preemptible node groups

Preemptible nodes use virtual machines that can be stopped by Nebius AI Cloud at any time. These VMs are more cost-efficient than regular ones and suitable for workloads with interruptions, such as batch processing or training ML models.

1. Follow the steps for creating a regular node group.
2. In the **Computing resources** section, under **VM type**, select **Preemptible**.
3. Complete the remaining configuration and click **Create node group**.

## How to modify node groups

You can change the configuration of an existing node group via the web console.

### Edit and update node groups

1. In the sidebar, go to **Compute** → **Kubernetes**.
2. Select the cluster and open the **Node groups** tab.
3. Click the name of the node group you wish to change.
4. On the node group details page, switch to the **Settings** tab. Here you can update and modify the parameters of the group.

### Deployment strategy and quotas

When you modify a node group's template, Managed Kubernetes performs a rolling update:

* Creates a replacement node.
* Cordons the existing node (marks it as unschedulable).
* Drains the existing node (evicts all pods from it).
* Deletes the existing node.

Managed Kubernetes uses the deployment strategy to determine the order and number of nodes updated at once. Ensure your quotas on the **Administration** → **Quotas** page allow for additional nodes during this process (e.g., if using a surge strategy).

## Node group parameters

### Kubernetes version on nodes

All nodes in a group get the same version of Kubernetes. By default, nodes use the same version as the parent cluster's control plane. For more information, see [Kubernetes versions in Managed Service for Kubernetes](https://www.google.com/search?q=https://docs.nebius.com/kubernetes/versions).

### Deployment strategy

The strategy is defined in the **Maintenance** section (visible when editing or in advanced creation settings):

* **Max unavailable**: The maximum number of nodes that can be offline during an update.
* **Max surge**: The maximum number of additional nodes that can be created during an update.
* **Drain timeout**: The time limit for evicting pods before a node is deleted.

### Specifying parameters

Parameters are specified using the web console's interactive elements:

* **Toggles**: Used for **Assign public IPv4 addresses** and **Enable autoscaling**.
* **Selection cards**: Used for **Computing resources** (With GPU/Without GPU) and **Available platform**.
* **Dropdowns**: Used for **Preset**, **Operating system**, and **Service account**.

## How to delete node groups

1. In the sidebar, go to **Compute** → **Kubernetes**.
2. Open the cluster and go to the **Node groups** tab.
3. Click the **...** (three dots) menu next to the node group you want to remove.
4. Select **Delete**.
5. Confirm the action in the dialog box.

## Examples

**Creating a GPU node group (H100)**
To create a high-performance group for large-scale AI workloads (e.g., two nodes with 8 GPUs each):

1. Under **Size**, set the **Number of nodes** to `2`.
2. Under **Computing resources**, select **With GPU**.
3. **Platform**: Select `gpu-h100-sxm`.
4. **Preset**: Choose `8 GPUs - 128 vCPUs - 1600 GiB RAM`.
5. **GPU settings**: Ensure **Automated setup** is enabled to pre-install drivers.
6. Under **Node storage**, select **SSD** and specify the **Size** as `100` GiB.
7. Follow the remaining steps to specify access and click **Create node group**.

**Modifying a node group for autoscaling**
To handle varying workloads:

1. Navigate to the node group's **Settings** tab.
2. Under **Size**, switch the **Enable autoscaling** toggle to **On**.
3. Set the **Minimum** and **Maximum** number of nodes.
4. Click **Save changes**.