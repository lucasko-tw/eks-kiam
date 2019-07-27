



define assert-set
  @[ -n "$($1)" ] || (echo "$(1) not defined in $(@)"; exit 1)
endef


ASSUME_ROLE=
# arn:aws:iam::123456789012:role/kiam-server
# in terraform, it would be aws_iam_role.server_role.arn

kiam/deploy:
	$(call assert-set,ASSUME_ROLE)
	# cert-manager
	# documentation:  https://docs.cert-manager.io/en/latest/getting-started/install/kubernetes.html
	kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml
	kubectl create namespace cert-manager
	kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
	helm repo add jetstack https://charts.jetstack.io || true
	helm repo update
	helm install   --name cert-manager   --namespace cert-manager  --version v0.8.1    jetstack/cert-manager
	kubectl -n cert-manager get pod,service
	sleep 20

	# certificate for kiam-server & kiam-agent
	kubectl create namespace kiam
	kubectl apply -f  certificate-issuer.yaml
	kubectl apply -f  certificate.yaml
	sleep 20

	# deploy kiam-server & kiam-agent
	helm install stable/kiam  --name kiam --namespace=kiam --set server.assumeRoleArn=$(ASSUME_ROLE)  --debug -f ./values.yaml
	kubectl --namespace=kiam get pods -l "app=kiam,release=kiam"


pod/deploy:
	kubectl apply -f  ./pod.yaml
	sleep 7
	kubectl -n test exec -it tomcat7 --  curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
	kubectl -n test exec -it tomcat7 --  curl http://169.254.169.254/latest/meta-data/iam/security-credentials/app_role

pod/delete:
	kubectl delete -f ./pod.yaml
