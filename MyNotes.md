# Actuator
- technical monitoring API for your application. DevOps tool

The actuator endpoints in this project are:
- http://localhost:8080/actuator/health — tells you whether the app is healthy
- http://localhost:8080/actuator/info — general app info
- http://localhost:8080/actuator/prometheus — metrics in Prometheus format

# Prometheus format
-  is plain text where every metric is written as a name + optional labels + numeric value

metric_name{labels} value

http://localhost:8080/actuator/prometheus ->


jvm_memory_used_bytes{area="heap",id="G1 Eden Space"} 1.2345678E7

http_server_requests_seconds_count{method="GET",status="200",uri="/api/message"} 5  MEANS /api/message received 5 successful GET requests

process_uptime_seconds 123.45 MEANS this Java process has been running for 123.45 seconds

### Metrics flow
Spring Boot
    ↓
/actuator/prometheus
    ↓
text full of numbers
    ↓
Prometheus reads and stores them periodically
    ↓
Grafana turns them into graphs/dashboards


# Docker

## No docker

machine
    ↓
Java + Maven
    ↓
Spring Boot

## With Docker
machine
    ↓
Docker
    ↓
container
    ↓
Spring Boot

## Docker deployment

### Open desktop app, run in terminal: 
docker build -t devops-cloud-lab:local .

docker build        build an image
-t                  give it a name/tag
devops-cloud-lab    image name
:local              tag
.                   use the Dockerfile in this folder

### Next step to see all images:
docker images

### Start the container
docker run --rm -p 8080:8080 devops-cloud-lab:local

my PC port 8080
        ↓
container port 8080

### Docker flow
Dockerfile - recipe
   ↓
Image - packaged application made from that recipe.
   ↓
Container - running instance of that image.

# Next step: Docker Compose + Prometheus + Grafana.

We can see the app works inside one container. Now we run three containers together:
Spring Boot app
Prometheus
Grafana

Stop the running container and run:

docker compose up --build

Docker Compose reads compose.yaml and starts the whole mini-system.

App:
http://localhost:8080

Prometheus:
http://localhost:9090

Grafana:
http://localhost:3000 username: admin, password: admin

## Check Prometheus targets
http://localhost:9090/targets - Prometheus target Spring Boot is up

Spring Boot
    ↓ exposes
/actuator/prometheus
    ↓ scraped by
Prometheus

## Grafana reading the data from Prometheus
http://localhost:3000

username: admin
password: admin

Connections → Data sources → Add data source → Prometheus.

http://prometheus:9090 

NOT localhost:9090 because Grafana is inside its own Docker container. Inside Docker Compose:

Grafana container
      ↓
http://prometheus:9090
      ↓
Prometheus container

Docker Compose gives each service a hostname equal to its service name, so prometheus resolves to the Prometheus container.

Save & test

Then create a dashboard:
Dashboards
→ New
→ New dashboard
→ Add visualization

Select the Prometheus data source.

## Grafana dashboard queries
Put in different visualisation panels:

process_uptime_seconds - how many seconds your Spring Boot process has been running.

jvm_memory_used_bytes - JVM memory usage
better: sum(jvm_memory_used_bytes) - use Code mode, not Builder

http_server_requests_seconds_count
Better: sum(rate(http_server_requests_seconds_count[1m])) - how many HTTP requests per second are currently arriving?

### Monitoring chain:
You call /api/message
        ↓
Spring Boot records metrics
        ↓
Actuator exposes /actuator/prometheus
        ↓
Prometheus scrapes them
        ↓
Grafana queries Prometheus
        ↓
Graph

# GitHub Actions / CI (Continuous Integration)

## Old scheme:
Spring Boot
   ↓
Docker image
   ↓
Prometheus + Grafana

## New scheme
git push
   ↓
GitHub Actions
   ↓
mvn test
   ↓
mvn package
   ↓
docker build

Every time I push code, GitHub automatically checks whether the project still builds.

We have this file:
.github/workflows/ci.yml 
-----------------------------
name: CI

on:
  push:
    branches: ["main"]
  pull_request:

jobs:
  test-and-build:
    runs-on: ubuntu-latest  // GitHub gives us a temporary Linux machine.

    steps:
      - name: Checkout repository
        uses: actions/checkout@v5 // copies my repository onto that Linux machine.

      - name: Set up Java 
        uses: actions/setup-java@v5  
        with:
          distribution: temurin
          java-version: "21"
          cache: maven

      - name: Run tests
        run: mvn --batch-mode test  

      - name: Build application
        run: mvn --batch-mode package -DskipTests //creates the .jar.

      - name: Build Docker image
        run: docker build -t devops-cloud-lab:${{ github.sha }} .  //checks that the Docker image can also be built.

------------------

Thus, Github independently proves my apps works on a clean Linux machine.

## CI means Continuous Integration
I push code to GitHub
        ↓
GitHub automatically runs checks
        ↓
tests
        ↓
build
        ↓
Docker image build

Instead of manually asking:
“Does my project still compile?” GitHub checks it every time I change the code.

This file defines the CI process:
.github/workflows/ci.yml

The full mechanism:
Developer changes code
        ↓
git push
        ↓
CI starts automatically
        ↓
mvn test
        ↓
mvn package
        ↓
docker build

RESULT: ✅ CI passed or ❌ CI failed


## Creating a new repo on GitHub
git init
git add .
git commit -m "Initial DevOps cloud lab"
git branch -M main
git remote add origin https://github.com/jannagudumac/devops-cloud-lab.git
git push -u origin main

## Actions on GitHub
We can see CI.yml launched and if successful it will have a green tick (or one can see separate actions in the details)

# Publish the Docker image automatically to GitHub Container Registry (GHCR)

## Current flow
push code
→ test
→ build jar
→ build Docker image
→ image disappears when the GitHub runner dies

## Improved flow
push code
→ test
→ build jar
→ build Docker image
→ push image to GHCR
(later Kubernetes can pull that image)


## New CI.yml:
name: CI

on:
  push:
    branches: ["main"]
  pull_request:

permissions:
  contents: read
  packages: write

jobs:
  test-build-push:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v5

      - name: Set up Java
        uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: "21"
          cache: maven

      - name: Run tests
        run: mvn --batch-mode test

      - name: Build application
        run: mvn --batch-mode package -DskipTests

      - name: Log in to GitHub Container Registry
        if: github.event_name == 'push'
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build Docker image
        run: |
          docker build \
            -t ghcr.io/${{ github.repository_owner }}/devops-cloud-lab:${{ github.sha }} \
            -t ghcr.io/${{ github.repository_owner }}/devops-cloud-lab:latest \
            .

      - name: Push Docker image
        if: github.event_name == 'push'
        run: |
          docker push ghcr.io/${{ github.repository_owner }}/devops-cloud-lab:${{ github.sha }}
          docker push ghcr.io/${{ github.repository_owner }}/devops-cloud-lab:latest
-----------------------------------

git add .github/workflows/ci.yml
git commit -m "Publish Docker image to GHCR"
git push

## Packages on GitHub
After GitHub Action finishes look at Packages, there will be:

devops-cloud-lab with a tag latest and another tag with the Git commit SHA.

That SHA tag is important because latest changes over time, while this points to one exact build:

ghcr.io/jannagudumac/devops-cloud-lab:bfe8b7ca434ce1bdad007d06ce6745c3a9cc0d96

### Package = a published Docker image in GitHub Packages
source code
   ↓
Docker build
   ↓
Docker image
   ↓
GitHub Container Registry stores it

So instead of the image existing only on my laptop, GitHub now keeps a copy online.

Why this matters: another machine—or later Kubernetes—can pull exactly that image:

docker pull ghcr.io/YOUR_USERNAME/devops-cloud-lab:latest

and then run it:

docker run -p 8080:8080 ghcr.io/YOUR_USERNAME/devops-cloud-lab:latest

That machine does not need the source code or Maven. It downloads the ready-made container image.

GitHub repository
= source code

GitHub Actions
= the robot that builds/tests it

GitHub Package / GHCR image
= the built Docker artifact stored online

this package is basically the bridge between CI and deployment.

# Kubernetes - a manager for containers.

Docker by itself can run a container:
docker run ...

Kubernetes sits one level above that and says:
“I want 2 copies of this container running all the time. If one dies, recreate it. Give them networking. Give them configuration. Later, update them safely.”

Kubernetes cluster
│
├── Deployment
│     ↓
│   creates Pods
│
├── Pods
│     ↓
│   contain the Docker container
│
├── Service
│     ↓
│   gives stable access to the Pods
│
└── ConfigMap
      ↓
    gives configuration to the Pods

# Kubernetes locally 
Kubernetes files go into k8s/

Docker image
    ↓
Kubernetes Deployment
    ↓
creates Pods
    ↓
Service gives them one stable address

For Windows + Docker Desktop, the easiest route is usually kind.

## Check
kubectl version --client
kind version

### installing Kind for Windows
curl.exe -Lo kind.exe https://kind.sigs.k8s.io/dl/v0.33.0/kind-windows-amd64

mkdir C:\Tools

Move-Item .\kind.exe C:\Tools\kind.exe

[Environment]::SetEnvironmentVariable(
    "Path",
    [Environment]::GetEnvironmentVariable("Path", "User") + ";C:\Tools",
    "User"
)

## Create a local cluster
kind create cluster --name devops-lab

## Load Docker image into the cluster
kind load docker-image devops-cloud-lab:local --name devops-lab

## Apply Kubernetes files
kubectl apply -f k8s/namespace.yml
kubectl apply -f k8s/configmap.yml
kubectl apply -f k8s/deployment.yml
kubectl apply -f k8s/service.yml

## Inspect what Kubernetes created
kubectl -n devops-lab get pods

We see 2 Pods, because our deployment says:
replicas: 2

NAME                               READY   STATUS    RESTARTS   AGE
devops-cloud-lab-8946cffdb-kf49r   0/1     Running   0          14s
devops-cloud-lab-8946cffdb-p47f9   0/1     Running   0          14s

## Expose the service to Windows machine
kubectl -n devops-lab port-forward service/devops-cloud-lab 8080:80

RESULT: Forwarding from 127.0.0.1:8080 -> 8080

Check: http://localhost:8080/api/message
{
  "message": "Hello from Kubernetes"
}

That value comes from your ConfigMap, not from the original application default.

## Core Kubernetes concepts:
- Pod = running container
- Deployment = manages the pods
- Service = stable network access to the pods
- ConfigMap = configuration supplied from outside the application (NOT for secret info, Kubernetes has another object Secret for that)

## How does the /api/message endpoint get "Hello from Kubernetes"
ConfigMap
APP_MESSAGE="Hello from Kubernetes"
        ↓
Deployment
        ↓
Pod
        ↓
Spring Boot container
        ↓
application.yml reads APP_MESSAGE
        ↓
/api/message

{"message":"Hello from Kubernetes"}

# Kubernetes exercice: desired state reconciliation.

prove that Kubernetes is actually managing your app, not just running it:

kubectl -n devops-lab get pods

NAME                               READY   STATUS    RESTARTS   AGE
devops-cloud-lab-8946cffdb-kf49r   1/1     Running   0          8m15s
devops-cloud-lab-8946cffdb-p47f9   1/1     Running   0          8m15s

Delete one pod manually: 
kubectl -n devops-lab delete pod devops-cloud-lab-8946cffdb-p47f9

After (ready changes after several seconds to 1/1)
kubectl -n devops-lab get pods
NAME                               READY   STATUS    RESTARTS   AGE
devops-cloud-lab-8946cffdb-kf49r   1/1     Running   0          9m14s
devops-cloud-lab-8946cffdb-nqm8h   0/1     Running   0          8s

## RESULT:  Kubernetes created a replacement pod automatically 
Deployment says:
"I want 2 replicas"

Actual state:
1 pod remains

Kubernetes notices mismatch

Desired state = 2
Actual state = 1

→ creates another pod

This is one of the most important Kubernetes concepts: desired state reconciliation.

## Scaling to 4 pods:
kubectl -n devops-lab scale deployment devops-cloud-lab --replicas=4

NAME                               READY   STATUS    RESTARTS   AGE
devops-cloud-lab-8946cffdb-kf49r   1/1     Running   0          12m
devops-cloud-lab-8946cffdb-lxw5f   1/1     Running   0          27s
devops-cloud-lab-8946cffdb-nqm8h   1/1     Running   0          3m36s
devops-cloud-lab-8946cffdb-pm274   1/1     Running   0          27s

Go back:
kubectl -n devops-lab scale deployment devops-cloud-lab --replicas=2

## Rolling update

Change in configmap.yml:
APP_MESSAGE: "Hello from Kubernetes v2"

Then apply it:
kubectl apply -f k8s/configmap.yml

But important: existing pods usually won’t restart just because the ConfigMap changed.
So trigger a rollout:
kubectl -n devops-lab rollout restart deployment devops-cloud-lab

To see rollout happen in real time:
kubectl -n devops-lab get pods -w

Old pods disappear and new ones appear gradually.

See new pods:
kubectl -n devops-lab get pods

To see if deployment is successful:
kubectl -n devops-lab rollout status deployment devops-cloud-lab

### Mapping Kubernetes to port 8081 to avoid Docker Compose conflict
kubectl -n devops-lab port-forward service/devops-cloud-lab 8081:80

BUT! kubectl port-forward is temporary, will have to be run again next day

### Result: 
http://localhost:8081/api/message

### Rolling upd flow:
{
  "message": "Hello from Kubernetes v2"
}

2 old pods running

↓ create new pod

1 new pod becomes READY

↓ remove one old pod

↓ create second new pod

second new pod becomes READY

↓ remove final old pod

2 new pods running

# Terraform 
- Describe the infrastructure I want in files, then let Terraform create it

Instead of clicking around AWS manually, you write something like:

resource "aws_instance" "app" {
  ami           = "..."
  instance_type = "t3.micro"
}

and Terraform talks to AWS for you.

## Terraform workflow
Terraform files
   ↓
terraform init
   ↓
terraform validate
   ↓
terraform plan
   ↓
see what WOULD be created
   ↓
terraform apply
   ↓
AWS resources created

## Terraform files
terraform/aws-ec2/
├── main.tf
├── variables.tf
├── outputs.tf
└── versions.tf

Docker
= packages your application

Kubernetes
= manages running containers

Terraform
= creates/configures infrastructure

## Installing Terraform
https://developer.hashicorp.com/terraform/install
- AMD64 version -> unzip -> put into C:Tools

## Installing AWS CLI
irm https://awscli.amazonaws.com/v2/install.ps1 | iex

## AWS authentication
aws login

make an account

set up region:

aws configure set region eu-west-3

Billing and Cost Management → Budgets → Create budget. Make a simple monthly cost budget, for example $5, and add an email alert at a low threshold like $1 actual spend. AWS Budgets supports notifications tied to a budget, so this gives you an early warning if anything starts costing money.

aws login

aws sts get-caller-identity

# AWS is a rentable IT infrastructure on the internet

Instead of owning a physical server in your room, you can ask Amazon:
“Give me a Linux machine.”
“Give me a database.”
“Give me storage.”
“Give me a network.”
“Run my containers.”

For my project, the most relevant AWS pieces are:
- EC2 = a virtual computer/server in the cloud
- VPC = the network around that server
- Security Group = firewall rules
- ECR = Docker image registry
- RDS = managed database
- EKS = managed Kubernetes

## The simplest flow
Your laptop
   ↓
Terraform
   ↓
AWS
   ↓
EC2 virtual machine
   ↓
Docker / my app

AWS answers the question:
“Where does my application actually run when it’s not on my laptop?”

For now: 
Spring Boot runs on my PC
Docker runs on my PC
Kubernetes runs locally inside Docker
Prometheus/Grafana run locally

AWS gives me a real remote environment.

Terraform
= instructions for AWS

AWS
= actual cloud infrastructure

Instead of manually clicking:
Create EC2
Choose Linux
Choose size
Configure network
Open port 8080


Terraform can describe that in code:
resource "aws_instance" "app" {
  instance_type = "t3.micro"
}

and then:
terraform apply

creates it for you.

# Goal for the project: 

Terraform
   ↓
creates 1 small EC2 machine
   ↓
I deploy my Dockerized Spring Boot app there

# Continue with Terraform

go into the Terraform folder:

devops-cloud-lab\terraform\aws-ec2

Run:

terraform init
= downloads the AWS provider Terraform needs

## RESULT:

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

terraform validate
= checks whether the .tf files are syntactically/logically valid

terraform plan
= shows exactly what Terraform WOULD create


## RESULT:
Plan: 2 to add, 0 to change, 0 to destroy.


plan is safe in the sense that it does not create resources. The AWS provider can use credentials from the AWS CLI, so we do not need to put secrets in our Terraform files. 

HashiCorp explicitly warns against putting AWS credentials directly into provider configuration.

### What plan shows
Terraform is proposing to create 2 AWS resources:
1. EC2 instance
   aws_instance.app
   
   This is my small virtual Linux server.
   Important bits:
   instance_type = "t3.micro"
   region        = "eu-west-3"
   
   So: one small machine in Paris.
2. Security Group
   aws_security_group.app
   
   The firewall around the EC2 machine.
   It currently allows:
   TCP port 8080
   from 0.0.0.0/0
   
   which means:
   anyone on the internet can access port 8080 on that server.
That’s intentional for this project because later my Spring Boot app will listen on 8080.

### ROOT = too powerful, making a new AWS user
Thus we need to separate IAM user/role for Terraform with limited permissions and rerun the same plan under that identity

In AWS console:
IAM → Users → Create user and name it:
terraform-devops-lab

do not give it console access. This user is just for Terraform/CLI.

Attach Policies directly:
AmazonEC2FullAccess
AmazonSSMReadOnlyAccess

After creating the user open it and:
Security credentials
→ Access keys
→ Create access key
-> CLI


In PowerShell, create a named profile:
aws configure --profile terraform-lab

It will ask:
AWS Access Key ID:
AWS Secret Access Key:
Default region name:
Default output format:

Use:
region: eu-west-3
output: json

Then verify the new identity:
aws sts get-caller-identity --profile terraform-lab

You want the ARN to contain something like:
user/terraform-devops-lab

rather than:
root

### Make Terraform use the new profile:

In:
terraform/aws-ec2/main.tf

provider "aws" {
  region = var.aws_region
  profile = "terraform-lab"
}

then from devops-cloud-lab\terraform\aws-ec2:
terraform plan

Same result as before:
Plan: 2 to add, 0 to change, 0 to destroy.

### Final step: terraform apply

from devops-cloud-lab\terraform\aws-ec2:
terraform apply
-> yes

Then it will create:
1 EC2 server
1 Security Group

### RESULT:
aws_security_group.app: Creating...
aws_security_group.app: Creation complete after 3s[id=sg-0ec7e6ab9a4c43d79]
aws_instance.app: Creating...
aws_instance.app: Still creating... [00m10s elapsed]
aws_instance.app: Creation complete after 13s [id=i-0c54d5dfaf1231c27]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

public_ip = "13.38.43.88"

# Checkpoint: we have a real EC2 server running in AWS
Terraform
   ↓
AWS
   ├── Security Group
   └── EC2 Linux server
          public IP: 13.38.43.88

But the server is basically empty right now. Next we make Terraform configure it automatically so it installs Docker and runs our GHCR image.*

## Make sure the package on GitHub is public:

Packages → devops-cloud-lab → Package settings → Change visibility → Public.

## Then edit the aws_instance "app" block in terraform/aws-ec2/main.tf. 

Add this inside it:

user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y docker

    systemctl enable docker
    systemctl start docker

    docker pull ghcr.io/jannagudumac/devops-cloud-lab:latest

    docker run -d \
      --name devops-cloud-lab \
      --restart unless-stopped \
      -p 8080:8080 \
      ghcr.io/jannagudumac/devops-cloud-lab:latest
  EOF

## Run: terraform plan
RESULT:
Plan: 1 to add, 0 to change, 1 to destroy.

Terraform is not destroying my whole setup. It will:
- keep the existing security group
- destroy the old EC2 instance
- create a new EC2 instance with the user_data startup script

REASON: + user_data = ... # forces replacement AND
user_data_replace_on_change = false -> true

Terraform is saying:
“This EC2 instance was created without that startup script. Since you now want startup configuration to be part of the instance, I need to replace it.”

The new instance will boot and automatically run:
dnf install -y docker
systemctl start docker
docker pull ghcr.io/jannagudumac/devops-cloud-lab:latest
docker run ...

## run: terraform apply -> EC2 instance is live!
RESULT:

Apply complete! Resources: 1 added, 0 changed, 1 destroyed.

Outputs:

public_ip = "13.36.170.131"

## Check whether the startup script installed Docker and launched my app

http://13.36.170.131:8080/api/message

{
  "message": "Hello from DevOps Cloud Lab"
}

## Terraform flow:

GitHub source code
   ↓
GitHub Actions
   ↓
Docker image
   ↓
GHCR
   ↓
Terraform creates EC2
   ↓
EC2 startup script installs Docker
   ↓
Docker pulls your image
   ↓
Spring Boot runs on AWS

# Bonus: add security scanning to CI (Trivy)

In .github/workflows/ci.yml after Build Docker image and before Push Docker Image add:

- name: Scan Docker image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ghcr.io/${{ github.repository_owner }}/devops-cloud-lab:latest
    format: table
    exit-code: 0
    severity: CRITICAL,HIGH

build image
   ↓
scan image
   ↓
push image

NOTE: with exit-code: 0 Trivy will report vulnerabilities but not fail the CI.

## With security added: 
Docker image
     ↓
Trivy
     ↓
checks installed libraries/packages
     ↓
finds known vulnerabilities

## CI becomes:
git push
   ↓
tests
   ↓
build
   ↓
Docker image
   ↓
security scan
   ↓
GHCR

