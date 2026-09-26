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

# GitHub Actions / CI

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

## Creating a new repo on GitHub
git init
git add .
git commit -m "Initial DevOps cloud lab"
git branch -M main
git remote add origin https://github.com/jannagudumac/devops-cloud-lab.git
git push -u origin main