# DevOps Cloud Lab

A small Spring Boot service used to practice real DevOps concepts. 
Check MyNotes.md for detailed information about concepts.

## Stack

- Java 21
- Spring Boot
- Maven
- Docker / Docker Compose
- GitHub Actions
- Kubernetes
- Terraform
- AWS
- Prometheus
- Grafana

## Learning path

Do these in order.

### 1. Run as a normal Java application

```bash
mvn test
mvn spring-boot:run
```

Open:

- http://localhost:8080/
- http://localhost:8080/api/message
- http://localhost:8080/api/counter
- http://localhost:8080/actuator/health
- http://localhost:8080/actuator/prometheus

### 2. Run with Docker

```bash
docker build -t devops-cloud-lab:local .
docker run --rm -p 8080:8080 -e APP_MESSAGE="Hello from Docker" devops-cloud-lab:local
```

### 3. Run app + Prometheus + Grafana

```bash
docker compose up --build
```

Then open:

- App: http://localhost:8080
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000
- Grafana login: `admin` / `admin`

In Grafana, add Prometheus as a data source with:

```text
http://prometheus:9090
```

### 4. GitHub Actions

Push the repository to GitHub.

The workflow in `.github/workflows/ci.yml` will:

1. check out the repository;
2. install Java 21;
3. run Maven tests;
4. package the app;
5. build the Docker image.

### 5. Kubernetes locally

Recommended first: use `kind` or Docker Desktop Kubernetes.

Build the image:

```bash
docker build -t devops-cloud-lab:local .
```

If you use kind:

```bash
kind create cluster --name devops-lab
kind load docker-image devops-cloud-lab:local --name devops-lab
kubectl apply -f k8s/namespace.yml
kubectl apply -f k8s/configmap.yml
kubectl apply -f k8s/deployment.yml
kubectl apply -f k8s/service.yml
kubectl -n devops-lab get pods
kubectl -n devops-lab port-forward service/devops-cloud-lab 8080:80
```

Now open http://localhost:8080/api/message.

### 6. Terraform / AWS

**Do not run `terraform apply` blindly. AWS resources can cost money.**

Start by inspecting and validating:

```bash
cd terraform/aws-ec2
terraform init
terraform fmt
terraform validate
terraform plan
```

Only after understanding the plan should you run:

```bash
terraform apply
```

When you are finished experimenting:

```bash
terraform destroy
```

## What to add later

- GitHub Container Registry publication
- Trivy vulnerability scanning
- PostgreSQL
- Kubernetes Secrets
- Helm
- Kubernetes monitoring
- automatic deployment after CI
- HTTPS / ingress
- Terraform remote state

## Why this project exists

The point is not the API. The point is to demonstrate the complete path from source code to repeatable build, containerisation, continuous integration, infrastructure as code, orchestration, health checks and observability.
