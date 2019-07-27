


### Terrform for eks

```hcl-terraform
git clone https://github.com/terraform-aws-modules/terraform-aws-eks.git

cd terraform-aws-eks/examples/eks_test_fixture

```

### Terraform Setting

create IAM roles in **kiam.tf**

More details in [IAM.md](https://github.com/uswitch/kiam/blob/master/docs/IAM.md)

```sh
vim kiam.tf
```


set up roles for your nodes

```sh
vim main.tf
```

```hcl-terraform

worker_groups = [
    {
      instance_type = "t2.medium"
      subnets = "${module.vpc.private_subnets[0]}"
      asg_desired_capacity = "1"
      asg_max_size = 1
      asg_min_size = 1
      key_name="test"
      kubelet_extra_args = "--node-labels=kubernetes.io/role=node "
    },
    {
      instance_type = "t2.small"
      subnets = "${module.vpc.private_subnets[0]}"
      asg_desired_capacity = "1"
      asg_max_size = 1
      asg_min_size = 1
      key_name="test"
      iam_role_id="${aws_iam_role.server_node.id}"
      kubelet_extra_args = "--node-labels=kubernetes.io/role=master "

    }
]
```
  > 1. label your nodes to be master,node
  > 2. master node uses customized **iam_role_id**

Run terraform

```sh
terraform apply
```  
  

```sh 
kubectl get nodes

NAME                                        STATUS   ROLES    AGE    VERSION
ip-172-1-2-3.eu-west-1.compute.internal     Ready    master   164m   v1.12.7
ip-172-4-5-6.eu-west-1.compute.internal     Ready    node     165m   v1.12.7

```

### Deploy cert-manager

```sh
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml
kubectl create namespace cert-manager
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
helm repo add jetstack https://charts.jetstack.io || true
helm repo update
helm install   --name cert-manager   --namespace cert-manager  --version v0.8.1    jetstack/cert-manager
kubectl -n cert-manager get pod,service
```



### Deploy kiam server/agent

```sh
# certificate for kiam-server & kiam-agent
kubectl create namespace kiam
kubectl apply -f  certificate-issuer.yaml
kubectl apply -f  certificate.yaml
sleep 20

# deploy kiam-server & kiam-agent
helm install stable/kiam  --name kiam --namespace=kiam --set server.assumeRoleArn=arn:aws:iam::123456789012:role/kiam-server  --debug -f ./values.yaml
kubectl --namespace=kiam get pods -l "app=kiam,release=kiam"
```


```sh
NAME        	REVISION	UPDATED                 	STATUS  	CHART              	APP VERSION	NAMESPACE
cert-manager	1       	Tue Jul  9 12:20:54 2019	DEPLOYED	cert-manager-v0.8.1	v0.8.1     	cert-manager
kiam        	1       	Tue Jul  9 12:21:39 2019	DEPLOYED	kiam-2.4.3         	3.2        	kiam
```



```sh
kubectl -n cert-manager get pods,certificate,secret,issuer


NAME                                           READY   STATUS    RESTARTS   AGE
pod/cert-manager-776cd4f499-8hk6f              1/1     Running   0          2m10s
pod/cert-manager-cainjector-744b987848-lg6wd   1/1     Running   0          2m10s
pod/cert-manager-webhook-645c7c4f5f-l4ngx      1/1     Running   0          2m10s

NAME                                                              READY   SECRET                             AGE
certificate.certmanager.k8s.io/cert-manager-webhook-ca            True    cert-manager-webhook-ca            2m
certificate.certmanager.k8s.io/cert-manager-webhook-webhook-tls   True    cert-manager-webhook-webhook-tls   2m

NAME                                         TYPE                                  DATA   AGE
secret/cert-manager-cainjector-token-r7gqs   kubernetes.io/service-account-token   3      2m10s
secret/cert-manager-token-2vmks              kubernetes.io/service-account-token   3      2m10s
secret/cert-manager-webhook-ca               kubernetes.io/tls                     3      2m8s
secret/cert-manager-webhook-token-wrc9d      kubernetes.io/service-account-token   3      2m10s
secret/cert-manager-webhook-webhook-tls      kubernetes.io/tls                     3      2m4s
secret/default-token-g2rmx                   kubernetes.io/service-account-token   3      2m15s

NAME                                                      AGE
issuer.certmanager.k8s.io/cert-manager-webhook-ca         2m
issuer.certmanager.k8s.io/cert-manager-webhook-selfsign   2m
```




```sh
kubectl -n kiam get pods,certificate,secret,issuer

NAME                    READY   STATUS    RESTARTS   AGE
pod/kiam-agent-s7mjr    1/1     Running   2          2m17s
pod/kiam-server-85wwc   1/1     Running   0          2m17s

NAME                                                     READY   SECRET                           AGE
certificate.certmanager.k8s.io/kiam-agent-certificate    True    kiam-agent-certificate-secret    2m
certificate.certmanager.k8s.io/kiam-server-certificate   True    kiam-server-certificate-secret   2m
certificate.certmanager.k8s.io/root-ca-cert              True    root-ca-cert                     2m

NAME                                    TYPE                                  DATA   AGE
secret/default-token-hfw2j              kubernetes.io/service-account-token   3      2m41s
secret/kiam-agent-certificate-secret    kubernetes.io/tls                     3      2m34s
secret/kiam-agent-token-l65jm           kubernetes.io/service-account-token   3      2m17s
secret/kiam-server-certificate-secret   kubernetes.io/tls                     3      2m34s
secret/kiam-server-token-mzfmd          kubernetes.io/service-account-token   3      2m17s
secret/root-ca-cert                     kubernetes.io/tls                     3      2m40s

NAME                                                       AGE
issuer.certmanager.k8s.io/root-ca-issuer                   2m
issuer.certmanager.k8s.io/self-signed-certificate-issuer   2m

```

```sh
kubectl apply -f  ./pod.yaml


namespace/test created
pod/tomcat7 created

sleep 20

kubectl -n test exec -it tomcat7 --  curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
app_role

kubectl -n test exec -it tomcat7 --  curl http://169.254.169.254/latest/meta-data/iam/security-credentials/app_role

{  
   "Code":"Success",
   "Type":"AWS-HMAC",
   "AccessKeyId":"XXXXXXXXX",
   "SecretAccessKey":"XXXXXXXXX",
   "Token":"XXXXXXXXXXX",
   "Expiration":"2017-09-09T11:36:40Z",
   "LastUpdated":"2017-09-09T11:21:40Z"
}
```

```sh
kubectl delete -f  ./pod.yaml
```