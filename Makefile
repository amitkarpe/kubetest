image = 'amitkarpe/nginx'
all: build push run test
build:
	docker build -t $(image) .
push:
	docker push $(image)
#	docker login -u amitkarpe -p XXXXXXX

run:
	docker stop nginx | echo "" | sleep 10
	docker run --rm --name nginx -p 8001:80 -d $(image)

test:
	curl -s localhost:8001

clean:
	docker image rm $(image)

deploy:
	kubectl run nginx --image=nginx:1.16-alpine --port 80 --expose -n nginx

k8s:
	kubectl run --expose --port 80 frontend --image=amitkarpe/nginx --dry-run -o yaml > k8s-pod.yaml
	
