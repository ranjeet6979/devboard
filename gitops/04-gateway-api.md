# 04 — Gateway API (Envoy Gateway)

The Gateway API is the modern replacement for Ingress:
- **GatewayClass** — which controller handles gateways (set once)
- **Gateway** — a load balancer + listener (creates an AWS NLB)
- **HTTPRoute** — routing rules (send `/` here, `/api/ai` there)

The Gateway and HTTPRoute ship *with the app* (in `k8s/` and the Helm chart), so
here you only install the controller and the GatewayClass.

## Install Envoy Gateway

```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.2.1 -n envoy-gateway-system --create-namespace
kubectl -n envoy-gateway-system rollout status deploy/envoy-gateway

root@ip-20-0-1-248:/opt/devboard/terraform# helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.2.1 -n envoy-gateway-system --create-namespace
kubectl -n envoy-gateway-system rollout status deploy/envoy-gateway
Pulled: docker.io/envoyproxy/gateway-helm:v1.2.1
Digest: sha256:deeb4f9ff3ac801e45f0457dbdc5ff11a74c4637b170e4bddb5f7c1a9ccb38cf
NAME: eg
LAST DEPLOYED: Sat Aug 15 08:13:25 2026
NAMESPACE: envoy-gateway-system
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
NOTES:
**************************************************************************
*** PLEASE BE PATIENT: Envoy Gateway may take a few minutes to install ***
**************************************************************************

Envoy Gateway is an open source project for managing Envoy Proxy as a standalone or Kubernetes-based application gateway.

Thank you for installing Envoy Gateway! 🎉

Your release is named: eg. 🎉

Your release is in namespace: envoy-gateway-system. 🎉

To learn more about the release, try:

  $ helm status eg -n envoy-gateway-system
  $ helm get all eg -n envoy-gateway-system

To have a quickstart of Envoy Gateway, please refer to https://gateway.envoyproxy.io/latest/tasks/quickstart.

To get more details, please visit https://gateway.envoyproxy.io and https://github.com/envoyproxy/gateway.
Waiting for deployment "envoy-gateway" rollout to finish: 0 of 1 updated replicas are available...
deployment "envoy-gateway" successfully rolled out
```
(Check the [releases](https://github.com/envoyproxy/gateway/releases) for a newer
version. Installing Envoy Gateway also installs the Gateway API CRDs.)

## Create the GatewayClass

```bash
kubectl apply -f gitops/gateway/gatewayclass.yaml
root@ip-20-0-1-248:/opt/devboard# kubectl apply -f gitops/gateway/gatewayclass.yaml
gatewayclass.gateway.networking.k8s.io/envoy created
kubectl get gatewayclass envoy        # ACCEPTED=True
root@ip-20-0-1-248:/opt/devboard# kubectl get gatewayclass envoy 
NAME    CONTROLLER                                      ACCEPTED   AGE
envoy   gateway.envoyproxy.io/gatewayclass-controller   True       9s
```

## Get the Load Balancer URL from AWS

```bash
kubectl get svc -n envoy-gateway-system
```
This will give you the services from the envoy-gateway-system and the service LoadBalancer will have the AWS NLB URL

Next: [05-argocd.md](05-argocd.md)
