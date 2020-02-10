image = 'amitkarpe/nginx'
port = '80'
ns = 'kubetest'

all: build push run test

docker: docker-build docker-push docker-run docker-test

dev: 
	skaffold dev -n $(ns)

run: 
	skaffold run -n $(ns)
	curl $$(minikube service kubetest -n kubetest  --url)

docker-build:
	DOCKER_BUILDKIT=1 docker build -t $(image) .

docker-push:
	docker push $(image)
#	docker login -u amitkarpe -p XXXXXXX

docker-run:
	docker stop nginx | echo "" | sleep 5
	docker run --rm --name nginx -p $(port):80 -d $(image)

docker-test:
	#curl -s localhost:$(port)
	docker exec -it nginx curl localhost

docker-clean:
	docker image rm -f $(image)

set-namespace:
	@kubectl create ns kubetest | true
	@kubectl config set-context --current --namespace=kubetest
	@echo "\033[92mSet namespace as $(ns)\033[0m"

k8s: set-namespace k8s-deploy k8s-test

k8s-deploy: 
	@echo ""
	kubectl run kubetest --image=$(image) --port 80 --expose -n $(ns) | true
	@echo ""
	@sleep 5
	@echo "\033[92mGet objects details\033[0m"
	@echo ""
	kubectl get ep,svc,deploy,pod -o wide -n $(ns)
	@echo ""

k8s-test:
	kubectl patch svc kubetest -p '{"spec":{"type":"NodePort"}}'
	sleep 3
	@echo ""
	curl $$(minikube service kubetest -n kubetest  --url)

delete-all:
	docker image rm -f $(image)
	kubectl delete all --all -n $(ns)
