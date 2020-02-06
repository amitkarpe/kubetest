# Kubernetes Cluster Test
This project is to test whether current Kubernetes cluster is working or not.

Run following commands to test docker environment:

```
make docker

```


Run following commands to test the Kubernetes environment:

```
make k8s

```

Run following commands to test the Skaffold environment:

```
make run  # One time (build and) Deployment

make dev # Continuous (build and) Deployment

```

