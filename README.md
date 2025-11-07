# Inspektor Gadget Contribfest: Enhancing the Observability and Security of Your K8s Clusters Through an easy to use Framework

Welcome to our contribfest. Please follow this guide to get access to the dev
environment and the different exercises we have prepared for you.

## Prerequisites

We provide a cloud environment with everything installed. However, you can run
it on your local machine by installing the following tools:
- ssh client (to access the dev VM)
- [az CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [kubectl
  gadget](https://inspektor-gadget.io/docs/latest/quick-start/#long-running-deployment-on-all-worker-nodes)

## Dev environment

In order to facilitate the exercises, we provide a cloud environment composed
by:
- A Kubernetes cluster deployed in Azure Kubernetes Service (AKS) with
  Prometheus and Grafana installed
- A development VM with all the needed tools installed to interact with the
  cluster and to create new gadgets

### Activating the Dev Environment

Go to https://experience.cloudlabs.ai/#/odl/b5f301cd-bacb-45d0-b642-2be884f221b6
to activate your dev environment, use the activation code provided during the
presentation, fill your information data and click on "Submit"

![alt text](./images/registration1.png)

On the next screen, click on "Launch Lab", then wait until it's ready.

![alt text](./images/labloading.png)

One the lab is ready, it'll log you in a Windows VM, we don't use it, instead,
check on the side panel looking for the Azure portal credentials:

![alt text](./images/azurecreds.png)

These are the credentials you'll use to log into the Azure portal and when using
`az login`.

### Accessing the dev VM

Login into the [azure portal](https://portal.azure.com/) then click into
"Virtual Machines"

![alt text](./images/vms.png)

and then click on the `demo-vm`. Write down the IP address from the overview
tab:

![alt text](./images/vmoverview.png)

and the password from the tags tab:

![alt text](./images/vmpassword.png)

and use them to ssh into the machine:

```bash
$ ssh azureuser@<IP_ADDRESS>
azureuser@demo-vm:~$
```

### Accessing the Kubernetes Cluster

#### From the dev VM

The dev VM has kubectl already configured to access the demo cluster, so you can
use it directly.

```bash
$ kubectl get nodes
NAME                                STATUS   ROLES    AGE   VERSION
aks-nodepool1-30504426-vmss000000   Ready    <none>   24m   v1.32.7
aks-nodepool1-30504426-vmss000001   Ready    <none>   24m   v1.32.7
```

#### From your local machine

You need to install the [Azure
CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) and login using
the credentials provided before:

```bash
az login
```

Then, get the credentials for the cluster:

```bash
az aks get-credentials --resource-group AKSRG --name aks-kubeconna2025
```

```bash
$ kubectl get nodes
NAME                                STATUS   ROLES    AGE   VERSION
aks-nodepool1-30504426-vmss000000   Ready    <none>   27m   v1.32.7
aks-nodepool1-30504426-vmss000001   Ready    <none>   27m   v1.32.7
```

## Deploying Inspektor Gadget

Now that you have access to the cluster, it's time to deploy Inspektor Gadget.

> [!WARNING]
> If you're using your local machine, make sure you have
> [kubectl-gadget](https://inspektor-gadget.io/docs/latest/quick-start/#long-running-deployment-on-all-worker-nodes)
> installed.

To deploy Inspektor Gadget, run the following command:

```bash
kubectl gadget deploy
```

### Running your first Gadget

Now that you have Inspektor Gadget deployed, let's run your first gadget. Let's monitor processes executions by using the trace_exec gadget:

```bash
kubectl gadget run trace exec
```

In another terminal, create a pod that will generate some process executions:

```bash
$ kubectl run --restart=Never --image=busybox myapp1-pod --labels="name=myapp1-pod,myapp=app-one,role=demo" -- sh -c 'while /bin/true ; do date ; cat /proc/version ; /bin/sleep 1 ; done'
pod/myapp1-pod created
```

You should see the process executions in the first terminal:

```bash
K8S.NODE            K8S.NAMESPACE               K8S.PODNAME                 K8S.CONTAINERNAME           COMM                        PID            TID PCOMM                    PPID ARGS           ERR… USER           LOGINUSER      GROUP
aks-nodepool1-3050  default                     myapp1-pod                  myapp1-pod                  true                    2957112        2957112 sh                    2589510 /bin/true           root           uid:4294967295 root
aks-nodepool1-3050  default                     myapp1-pod                  myapp1-pod                  date                    2957113        2957113 sh                    2589510 /bin/date           root           uid:4294967295 root
```

Now that you have run your first gadget, it's time to explore more advanced use cases.

## Exercises

- [Troubleshoot your cluster with Gadgets](./labs/01-troubleshooting/README.md)
- [Export metrics to Prometheus / Grafana](./labs/02-monitoring/README.md)
- [Create your own Gadget](./labs/03-creating-your-own-gadget/README.md)
- [Contribute to Inspektor Gadget](./labs/04-contributing/README.md)

## Thanks

Thanks for the whole Inspektor Gadget team for the work on the project, and
specially to @burak-ok, @mqasimsarfraz and @flyth who prepared a contribfest
early this year that served as base for this one:
https://github.com/inspektor-gadget/Contribfest-KubeCon-Europe2025
