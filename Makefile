image = 'amitkarpe/nginx'
port = '80'
ns = 'kubetest'
all: build push run test
build:
	docker build -t $(image) .
push:
	docker push $(image)
#	docker login -u amitkarpe -p XXXXXXX

run:
	docker stop nginx | echo "" | sleep 5
	docker run --rm --name nginx -p $(port):80 -d $(image)

test:
	#curl -s localhost:$(port)
	docker exec -it nginx curl localhost

clean:
	docker image rm -f $(image)

set-namespace:
	@kubectl create ns kubetest | true
	@kubectl config set-context --current --namespace=kubetest
	@echo "\033[92mSet namespace as $(ns)\033[0m"

k8s-deploy: set-namespace
	@echo ""
#	$col_yellow
	kubectl run nginx --image=$(image) --port 80 --expose -n $(ns) | true
	@echo ""
	@sleep 2
	@echo "\033[92mGet objects details\033[0m"
	@echo ""
	kubectl get ep,svc,deploy,pod -o wide -n $(ns)
	@echo ""
delete-all:
	docker image rm -f $(image)
	kubectl delete all --all -n $(ns)
