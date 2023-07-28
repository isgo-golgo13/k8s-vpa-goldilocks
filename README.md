# K8s VPA Goldilocks
K8s CNCF Self-Service Vertical Pod Autoscaler (VPA) Controller Goldilocks Automating Pod Resources and Pod Resource Cost Analytics.

![goldilocks-logo](docs/goldilocks-logo.png)


## VPA Prerequisites

To reserve the correct configuration sizing of K8s resources, a required step is to analyze the current resource usage of the containers. For that there are two procedures, the first is through the use of PromQL Query that calculates the average CPU allocation activity for all the containers associated with its workload. Understanding a workload as a `Deployment`, a `StatefulSet`, or a `DaemonSet`. The second procedure is for K8s developers to provide a `Vertical Pod Autoscaler` (VPA) as part of the application Helm Chart as a **vpa.yaml** file and during traffic load testing of the app, to turn on the VPA in its correct profiler configuration and have the VPA collect and provision the correct `target` request values to supply to the Pod's `resources.request.cpu` and `resources.request.memory` configurations. The section that follows `Autoscaling in K8s using VPA and VPA Operation Strategies` provides developers how this works into their K8s applications. These two steps, in-particular the second step are 100% required for ALL app teams provisioning their services to K8s. 

**HPA is cannot run with VPA**. Turn off HPA during VPA testing only in `development` environments. The HPA and VPA contend for cpu and memory resources as keys for getting triggered. The exception is if HPA is triggered through an application metric such as `request queue length` using a message queuing platform such as NATS or Azure Event Service and incorporates KEDA (Kubernetes Event-Driven Autoscaler). In this case the VPA and HPA can co-exist.

### Pre-requisites on the K8s Cluster

- The K8s Cluster (any of standard K8s clusters GKE, AKS, ...) requires metrics-server installed and active.
The metrics-server will collect K8s resource use statistics (cpu, memory, user-defined metrics) to give the Vertical Pod Autoscaler (VPA) the info it requires to actively escalate your K8s resources to vertically scale. 

### Understanding the Pod QoS Offerings

There are three levels of QoS for K8s Pods.

- QoS **Guaranteed** (First Class QoS)
- QoS **Burstable** (Second Class QoS)
- QoS **Best Effort** (Third Class QoS)


#### Guaranteed QoS
The config for QoS **Guaranteed** in the Pod spec for resource configs is as follows:

```Yaml
resources:
  requests:
    cpu: 15m
    memory: 105M
  limits:
    cpu: 15m
    memory: 105M
```

Configuring the `resources.requests.cpu/memory` equal to defined `resources.limits.cpu/memory` provides a ceiling cap which prevents the containers in the Pod to allocate additional cpu and memory resources during the lifecycle of the active Pod. This is a first-class QoS configuration. This configuration provides a strict requirement for the K8s Scheduler to `guarantee` schedule to the `K8s Node` without risk of starving pre-existing non-related Pods in existing or adjacent tenant namespaces. The limits configuration prevents cpu throttling (artificial latency).


#### Burstable QoS
The config for QoS **Burstable** in the Pod spec for resource configs is as follows:

```Yaml
resources:
  requests:
    cpu: 15m
    memory: 105M
```

Configuring the `resources.requests.cpu/memory` and **NOT** configuring `resources.limits.cpu/memory` This configuration is a second-class QoS configuration. This configuration allows the Pod to allocate additional cpu and memory request levels the K8s Node offers (the bursting) and starve pre-existing Pods from the cluster or prevent new Pods to get scheduled. This configuration does not define a cpu and memory ceiling cap for Deployment. 


#### Best Effort QoS
The config for QoS **Best Effort** in the Pod spec for resource configs is as follows:

```Yaml
resources: []
```

**NOT** configuring the `resources.requests.cpu/memory` and **NOT** configuring `resources.limits.cpu/memory` This configuration is a third-class QoS configuration. This configuration reduces the scheduling chances for the Pod as the K8s Kubelet on the worker Node relays resource availability status to the K8s Scheduler and gives a low-probability chance (best effort) in deploying Pod without declaring a low-cap or a high-cap for its required cpu and memory resources. 


## CNCF Goldilocks Overview
Goldilocks automates the provisoning of the VPA into a K8s Cluster and provides a VPA Analytics Dashscreen to allow K8s SREs to configure or reconfigure the correct Pod spec resources for cpu/memory requests and cpu/memory limits. Goldilocks VPA is a K8s Controller that layers over K8s core VPA controllers.

## Prerequisites

Goldilocks has the following prerequisites.

- K8s Cluster Cloud (AKS, GKE)
- K8s Cluster Docker-in-Docker (K3D, KinD)
- K8s VPA pre-installed on K8s Cluster
- K8s Metric Server on K8s Cluster 
- Golang 1.11+


## K8s Clusters Provided (K3D, AKS*)

### K3D Cluster 

To install locally a `K8s in Docker` cluster to run `Goldilocks` look to the `iac/k8s/kind-k8s` directory for a `k3d-cluster-config.yaml` and execute at the shell as follows:

``` shell
k3d cluster create --config=k3d-cluster-config.yaml
```

## Installing VPA

```shell
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm install my-vpa fairwinds-stable/vpa --version 2.2.0
```


## Installing Goldilocks

Goldilocks provides a K8s Helm Chart from official Helm Chart Registry `artficacthub.io`. To install the chart, a `goldilocks` namespace is required for the install.

```shell
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm install goldilocks fairwinds-stable/goldilocks --namespace goldilocks
```

## Targeting K8s Deployments using Goldilocks 

Deploy K8s application through K8s Helm Chart , K8s Kustomize or K8s YAML configs) into a K8s `Namespace` as follows.


Using K8s YAML (No K8s Helm Chart)
```shell
kubectl create ns <app-ns> 
kubectl apply -f app.yaml
```

Now apply the Goldilocks K8s label to the previosly created app namespace
```shell
kubectl label ns <app-ns> goldilocks.fairwinds.com/enabled=true
```
Now executing the following.

```shell
kubectl get vpa -n <app-ns>
```
After labeling the pre-existing namespace `app-ns` with the `goldilocks.fairwinds.com/enabled=true` tags the namespace and auto-injects a VPA that references its target deployment using the VPA internal`targetRef` to refer to the `metadata.name` value of the previous deployed `Deployment`. The listing shows the following.

```shell
NAME                                        MODE   CPU   MEM   PROVIDED   AGE
goldilocks-gokit-gorillakit-enginesvc       Off                           27s
```

After a 60 seconds executing the `kubectl get vpa -n <app-ns>` again will show the VPA auto-calculated resource recommendations data.

```shell
NAME                                    MODE   CPU   MEM         PROVIDED   AGE
goldilocks-gokit-gorillakit-enginesvc   Off    15m   104857600   True       22h
```

For every distinct K8s Deployment deployed to namespace `app-ns` a new VPA will get generated to target that specific Deployment. This avoids the extra work to create using Helm templates or Kustomize YAML or YAML-direct resources for VPA for every new Deployment. 



## VPA vs Goldilocks VPA

Deploying non-Goldilocks VAP (raw VPA) requires.

- Deploy of VPA CRDS and Controller 
- Deploy of VPA per-Deployment (1:1)
- Collect VPA calculations

Deploying Goldilocks VAP requires.

- Deploy of VPA CRDS and Controller 
- Apply Goldilocks K8s `Label` per-Deployment tenant `Namespace`
- Auto-collect VPA calculations (Goldilocks Dash)

### VPA Recommendations Data vs Goldilocks VPA Recommendations Data

If using the VPA (non-Goldilocks version) as previously discussed there is a **1:1** association of a VPA for every distinct `K8s Deployment`. 

To collect the per-VPA calculated resource recommendations the following is required to execute.

```shell
kubectl describe vpa <vpa-instance-name> -n <vpa-ns>
```

This will show the following.

```Yaml
Spec:
  Target  Ref:
    API Version: apps/v1
    Kind: Deployment
    Name: gokit-gorillakit-enginesvc
    UpdatePolicy:
       Update Mode: Off
  Status:

Recommendations:

    Container  Recommendations:
      Container Name: gokit-gorillakit-enginesvc
      Lower Bound: 
        cpu:  15m
        memory: 100M
      Target:
        cpu: 15m
        memory: 105M
      Uncapped:
        cpu: 100m
        memory: 500M
      Upper Bound: 
        cpu: 250M
        memory: 1G
```

If using the Goldilocks VPA as previously discussed there is a **1:1** association of a VPA for every distinct `K8s Deployment`. 

```shell
NAME                                    MODE   CPU   MEM         PROVIDED   AGE
goldilocks-gokit-gorillakit-enginesvc   Off    15m   104857600   True       22h
```


## References

### Goldilocks Official K8s Helm Chart
`https://artifacthub.io/packages/helm/fairwinds-stable/goldilocks`

### Goldilocks Page
`https://www.fairwinds.com/goldilocks`