# GUVI React Application Deployment with Jenkins CI/CD and Monitoring

## Project Overview

This project deploys a React OnlineShop application to separate
Development (DEV) and Production (PROD) environments using Docker,
Docker Hub, Jenkins Multibranch Pipeline, Prometheus, Blackbox Exporter,
and Alertmanager email notifications.

The `dev` branch deploys to the DEV container on port `8081`. The
`master` branch deploys to the PROD container on port `80`. Prometheus
uses Blackbox Exporter to monitor both HTTP endpoints and sends
`ApplicationDown` notifications through Alertmanager when an endpoint
remains unavailable for the configured duration.

## Architecture

``` text
                         GitHub repository
                         dev       master
                           \\         /
                        Jenkins Multibranch
                         Pipeline (Jenkinsfile)
                           /         \\
                    Build \& Push   Build \& Push
                         |             |
                    Docker Hub     Docker Hub
                    DEV image     PROD image
                         |             |
                         v             v
                  guvi-react-dev  guvi-react-prod
                  host port 8081  host port 80
                         \\             /
                          \\           /
                       Blackbox Exporter
                               |
                           Prometheus
                         ApplicationDown
                               |
                         Alertmanager
                               |
                        Gmail notifications
                     FIRING and RESOLVED emails
```

## Technology Stack

* AWS EC2 --- Linux host for the application, Jenkins, and monitoring
containers
* Amazon Linux 2023 --- EC2 operating system
* Docker Engine and Docker Compose --- container build and runtime
* Nginx --- serves the prebuilt React application
* GitHub --- source repository and `dev` / `master` branches
* Jenkins --- Multibranch Pipeline CI/CD
* Docker Hub --- separate DEV and PROD image repositories
* Prometheus --- metrics collection and alert-rule evaluation
* Blackbox Exporter --- HTTP endpoint probing
* Alertmanager --- alert routing and email notifications
* Gmail SMTP --- notification delivery

## Deployment Environments

\---

Environment   Git branch    Docker Hub image                 Container                   Host port

\---

DEV           `dev`         `sethuaws/guvi-react-app-dev`    `guvi-react-dev`               `8081`

## PROD          `master`      `sethuaws/guvi-react-app-prod`   `guvi-react-prod`                `80`

Application URLs used during validation:

* DEV: `http://13.211.30.236:8081`
* PROD: `http://13.211.30.236`

> These are the EC2 public-IP endpoints used during this project run.
> They may change if the instance is stopped and restarted without an
> Elastic IP.

## Repository Structure

``` text
.
├── Dockerfile
├── .dockerignore
├── .gitignore
├── docker-compose.yml
├── docker-compose.monitoring.yml
├── Jenkinsfile
├── build.sh
├── deploy.sh
├── build/
├── monitoring/
│   ├── blackbox.yml
│   ├── alertmanager.yml.template
│   └── prometheus/
│       ├── prometheus.yml
│       └── alerts.yml
└── screenshots/
    ├── 01-production-application-homepage.png
    ├── 02-dockerhub-dev-repository.png
    ├── 03-dockerhub-prod-repository.png
    ├── 04-alertmanager-firing-email.png
    ├── 05-alertmanager-resolved-email.png
    ├── 06-jenkins-multibranch-pipeline.png
    ├── 07-react-dev-application.png
    ├── 08-react-prod-application.png
    ├── 09-prometheus-targets-up.png
    ├── 10-prometheus-alert-rules.png
    └── 11-docker-running-containers.png
```

The `build/` directory contains the prebuilt React application copied
into the Nginx image. The deployment flow in this implementation
packages that existing build; it does not run a fresh Node/React build
stage in Jenkins.

## Docker Image

The Dockerfile uses Nginx Alpine to serve the prebuilt React files:

``` dockerfile
FROM nginx:alpine
RUN rm -rf /usr/share/nginx/html/\*
COPY build/ /usr/share/nginx/html/
EXPOSE 80
CMD \["nginx", "-g", "daemon off;"]
```

The build script selects the image repository from the branch name,
builds `latest` and commit-specific tags, and pushes both tags to Docker
Hub.

* `dev` → `sethuaws/guvi-react-app-dev`
* `master` → `sethuaws/guvi-react-app-prod`

The deploy script pulls the selected image, replaces the corresponding
container, and performs an HTTP health check.

## Jenkins CI/CD

A Jenkins Multibranch Pipeline job named `guvi-react-cicd` scans the
GitHub repository and discovers the `dev` and `master` branches using
the `Jenkinsfile`.

Pipeline stages:

1. **Checkout** --- checks out the branch source.
2. **Build and Deploy** --- runs for `dev` and `master`.
3. **Docker authentication** --- uses the Jenkins credential ID
`dockerhub-creds` and `--password-stdin`.
4. **Build and push** --- runs `build.sh` to build and push the
branch-specific image.
5. **Deploy** --- runs `deploy.sh` to deploy the correct image and
validate the HTTP response.

The Multibranch Pipeline was configured with periodic scanning
(one-minute interval) for branch changes. A GitHub webhook was not used
in this setup; Jenkins periodic scanning detected the test commit and
triggered the branch build.

### Jenkins credential

Create a Jenkins credential of type **Username with password**:

* ID: `dockerhub-creds`
* Username: Docker Hub username
* Password: Docker Hub access token

Do not store the Docker Hub token in the repository or Jenkinsfile.

## Monitoring and Alerting

### Prometheus and Blackbox Exporter

Prometheus scrapes Blackbox Exporter using the `http\_2xx` probe module.
The monitored application endpoints are:

* DEV: `http://host.docker.internal:8081`
* PROD: `http://host.docker.internal:80`

The target labels identify the environment as `dev` and `prod`. The
Prometheus Targets screenshot shows both application probes as `UP`,
along with the Prometheus self-scrape target.

### Alert rule

The configured rule is:

``` yaml
groups:
  - name: application-alerts
    rules:
      - alert: ApplicationDown
        expr: probe\_success == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.environment }} application is DOWN"
          description: "HTTP health check failed for {{ $labels.instance }}"
```

When a probe fails continuously for one minute, Prometheus fires
`ApplicationDown`. Alertmanager routes the alert to the configured email
receiver. Resolved notifications are enabled.

### Email configuration

Alertmanager uses Gmail SMTP on port `587` with TLS. The credentials and
recipient are supplied through a local `.env` file and a generated
Alertmanager configuration file.

**Never commit these files or their contents:**

* `.env`
* `monitoring/alertmanager.yml` (generated file containing SMTP
credentials)

Keep the `.env` file restricted to the server user and use a Gmail App
Password rather than an account password. The repository should contain
only `monitoring/alertmanager.yml.template`, without real credentials.

### Monitoring access

Prometheus and Alertmanager were bound to localhost on the EC2 host:

* Prometheus: `http://localhost:9090`
* Alertmanager: `http://localhost:9093`

They were accessed from the workstation using an SSH local port-forward.
Their management ports were not opened to the public internet.

## Run and Verify

Run these commands from the project directory on the EC2 instance.

### Check application and monitoring containers

``` bash
docker ps --format "table {{.Names}}\\t{{.Image}}\\t{{.Status}}\\t{{.Ports}}"
```

Expected containers:

* `guvi-react-dev`
* `guvi-react-prod`
* `prometheus`
* `blackbox-exporter`
* `alertmanager`

### Check application endpoints from EC2

``` bash
curl -I http://localhost:8081/
curl -I http://localhost:80/
```

### Check Prometheus targets

Open the Prometheus UI through the SSH tunnel and visit:

``` text
http://localhost:9090/targets
```

Both DEV and PROD Blackbox targets should show `UP`.

### Check alert rules

Visit:

``` text
http://localhost:9090/alerts
```

When both applications are healthy, `ApplicationDown` should be
inactive.

### Check Alertmanager

Open:

``` text
http://localhost:9093
```

### Test an alert

A controlled test was performed by stopping the DEV container, waiting
for the alert rule's one-minute pending period, and confirming the
FIRING email. The DEV container was then started again and a RESOLVED
email was received.

``` bash
docker stop guvi-react-dev
# Wait at least 90 seconds and check Prometheus / Alertmanager and Gmail.
docker start guvi-react-dev
```

Do not leave the DEV container stopped after the test.

## AWS and Security Notes

* The project reused an existing EC2 instance rather than creating
another instance, to avoid unnecessary infrastructure cost.
* The instance used during the project was a `c7i-flex.large` in AWS
region `ap-southeast-2` (Sydney).
* HTTP application ports `80` and `8081` were used for the PROD and
DEV endpoints.
* SSH and Jenkins access were restricted to the operator's public IP
at the time of setup.
* Prometheus (`9090`) and Alertmanager (`9093`) were bound to
`127.0.0.1`; Blackbox Exporter (`9115`) was kept internal to the
Docker network.
* Do not publish Docker Hub tokens, Gmail App Passwords, private SSH
keys, `.env`, or generated secret configuration.
* Review the EC2 security group and rotate credentials if any secret
has accidentally been exposed.

## Evidence Screenshots

The `screenshots/` directory contains 11 screenshots captured during
implementation and verification:

1. Production application homepage
2. Docker Hub DEV repository
3. Docker Hub PROD repository
4. Alertmanager FIRING email
5. Alertmanager RESOLVED email
6. Jenkins Multibranch Pipeline with successful `dev` and `master`
branch builds
7. React DEV application
8. React PROD application
9. Prometheus targets showing DEV, PROD, and Prometheus as UP
10. Prometheus `ApplicationDown` alert rule
11. Docker containers showing all five application and monitoring
containers running

See [`screenshots/README-EVIDENCE.md`](screenshots/README-EVIDENCE.md)
for the evidence index.



\### EC2 Instance Selection – Infrastructure Constraint



The assignment initially suggested using a `t2.micro` EC2 instance. However, the `t2.micro` instance type was not available in the selected AWS region (`ap-southeast-2`, Sydney) during deployment.



To overcome this availability limitation and continue the project without interruption, we selected the `c7i-flex.large` instance type.



\*\*Instance details:\*\*

\- Requested instance type: `t2.micro`

\- Actual instance type: `c7i-flex.large`

\- AWS Region: `ap-southeast-2` (Sydney)

\- Operating System: Amazon Linux 2023



\*\*Reason for deviation:\*\* The requested `t2.micro` instance type was unavailable, so `c7i-flex.large` was selected as an alternative to complete the deployment, Jenkins CI/CD pipeline, Docker containers, and monitoring setup.



\*\*Note:\*\* The alternative instance type has higher resource capacity and potentially higher running costs than `t2.micro`. The instance was reused for the project to avoid creating additional EC2 resources.



## GitHub Repository

Project repository:
https://github.com/sethuraman98/guvi-react-deployment

## Conclusion

This project demonstrates branch-based container image creation and
deployment, separate DEV and PROD application environments, Jenkins
Multibranch Pipeline automation, HTTP availability monitoring, and email
notifications for application downtime and recovery.

