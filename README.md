# Terraform GKE SQL Project
## _My First Terraform Project, Ever_


## Goals

- Show a public “Hello world” application running on GCP
- Application running on a private network with access to an SQL Instance
- Make the solution scalable and cost effective


## Technologies

- Google Cloud Console
- Terraform
- Kubernetes
- Visual Studio Code

# Task 1
This is accomplished by applying the following YAML file to the built k8s infrastructure
```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
spec:
  selector:
    matchLabels:
      run: my-nginx
  replicas: 2
  template:
    metadata:
      labels:
        run: my-nginx
    spec:
      containers:
      - name: my-nginx
        image: nginx
        ports:
        - containerPort: 80
```

I then apply a service to expose the app publicly
```sh
apiVersion: v1
kind: Service
metadata:
  name: hello-world-lb
  labels:
    run: my-nginx
spec:
  type: LoadBalancer
  ports:
  - port: 8080
    targetPort: 80
    protocol: TCP
    name: http
  - port: 443
    protocol: TCP
    name: https
  selector:
    run: my-nginx
```

# Task 2

I built the Kubernetes cluster on a private VPC "vpc-appsbro-01", aswell as the SQL database.

10.0.0.0/18
>Subnets: 
>k8s-pod-range	10.48.0.0/14	 
>k8s-service-range	10.52.0.0/20

The only application that will be avaliable publicly will be the applications that are explicitly exposed  "hello-world" & "sql-app"

The SQL Instance % DB was built with:
```sh
resource "google_sql_database_instance" "instance" {
  provider = google-beta

  name              = var.sql_id
  project           = var.project
  region            = var.region
  database_version  = var.sql_ver
  root_password     = var.db_password

  #depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled    = true
      private_network = google_compute_network.vpc_webapp.id
    }
  }
}


resource "google_sql_database" "database" {
  name     = var.sql_db
  instance = var.sql_id

  depends_on = [google_sql_database_instance.instance]
  
  
}

resource "google_sql_user" "users" {
 name     = var.db_user
 host = var.db_user_access
 instance = var.sql_id
 password = var.db_password


depends_on = [google_sql_database_instance.instance]
}
```


The SQL App is deployed on the Kubernetes cluster using the below,
I got the application from the below and updated the values to apply to my infrastructure.
```sh
https://github.com/GoogleCloudPlatform/golang-samples
```
```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sql-app
  namespace: default
spec:
  selector:
    matchLabels:
      app: gke-cloud-sql-app
  template:
    metadata:
      labels:
        app: gke-cloud-sql-app
    spec:
      serviceAccountName: ksa-cloud-sql
      containers:
      - name: gke-cloud-sql-app
        image: europe-west2-docker.pkg.dev/webapp-dev-0-001/repo/gke-sql:latest
        # This app listens on port 8080 for web traffic by default.
        ports:
        - containerPort: 8080
        env:
        - name: PORT
          value: "8080"
        - name: INSTANCE_HOST
          value: "127.0.0.1"
        - name: DB_PORT
          value: "3306"
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: gke-cloud-sql-secrets
              key: username
        - name: DB_PASS
          valueFrom:
            secretKeyRef:
              name: gke-cloud-sql-secrets
              key: password
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: gke-cloud-sql-secrets
              key: database
      - name: cloud-sql-proxy
        # This uses the latest version of the Cloud SQL proxy
        # It is recommended to use a specific version for production environments.
        # See: https://github.com/GoogleCloudPlatform/cloudsql-proxy
        image: gcr.io/cloudsql-docker/gce-proxy:latest
        command:
          - "/cloud_sql_proxy"

          # If connecting from a VPC-native GKE cluster, you can use the
          # following flag to have the proxy connect over private IP
          - "-ip_address_types=PRIVATE"

          # tcp should be set to the port the proxy should listen on
          # and should match the DB_PORT value set above.
          # Defaults: MySQL: 3306, Postgres: 5432, SQLServer: 1433
          - "-instances=webapp-dev-0-001:europe-west2:webapp-sql=tcp:3306"
        securityContext:
          # The default Cloud SQL proxy image runs as the
          # "nonroot" user and group (uid: 65532) by default.
          runAsNonRoot: true
```

# Task 3

The benefits of Kubernetes

- Easy to scale the deployment
- Software updates can be applied with no downtime and no impact to end user
- High Availability and Redundancy, when a pod dies it is replaced

Instance managed groups is another way of managing scalability

# Task 4

Cost Optimisation options can be managed through load against CPU and/or HTTP traffic. 
Using Instance Groups or K8s

Cost Optimisation can also be managed by changing the machine build. Using only the required amount of CPU and Storage with little overhead. Google also makes optimisation suggestions

# Task 5

Best practise - allow as little control as possible.
Example - The network engineer needs access to administrate the firewalls. This can be done on a Per Organization/Project/Role level, if there only need access to one project - just apply permissions to that one project. Do not grant Organization right which will give them access to 100+ projects. This opens the door for human error and possible "end of bussiness" events. 

[Reference for best practise:](https://cloud.google.com/docs/enterprise/best-practices-for-enterprise-organizations#control-access)


[Data exfiltration options:](https://cloud.google.com/docs/security/data-loss-prevention/preventing-data-exfiltration)

In Google Cloud, the Data Loss Prevention (DLP) lets you understand and manage sensitive data. It provides fast, scalable classification and optional redaction for sensitive data elements like credit card numbers, names, Social Security numbers, passport numbers, US and selected international driver’s license numbers, and phone numbers. Cloud DLP supports text, structured data, and images – just submit data to Cloud DLP or specify data stored on your Cloud Storage, BigQuery, and Datastore instances. The findings from Cloud DLP can be used to automatically monitor or inform configuration of IAM settings, data residency, or other policies. Cloud DLP can also help you redact or mask certain parts of this data in order to reduce the sensitivity or help with data minimization as part of a least-privileged or need-to-know policy. Techniques available are masking, format-preserving encryption, tokenization, and bucketing across structured or free text data.

# CI/CD

To carry out the CI/CD task of the project I used CloudBuild

This required me to apply editor rights to the CloudBuild service account
```sh
CLOUDBUILD_SA="$(gcloud projects describe $PROJECT_ID \
    --format 'value(projectNumber)')@cloudbuild.gserviceaccount.com"
```
```sh
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member serviceAccount:$CLOUDBUILD_SA --role roles/editor
```

This is likely more permission then is allowed in a production enviorment, with enough time and scope a role can be created on a more granular level to allign with company requirements.

I used the GCP GUI to create a trigger condition inside CloudBuild and associate it with my GitHub.
- Event Trigger = Push To Branch
- Source = Matcham89/terraform-gke-sql (GitHub App)
- Branch = Dev
- Configuration = Auto
- Location = Repo
> If I had a custom ServiceAccount, this is where I would have applied it

I attached the cloud build YAML to my repo
```sh
steps:
- id: 'branch name'
  name: 'alpine'
  entrypoint: 'sh'  
  args: 
  - '-c'
  - | 
      echo "***********************"
      echo "$BRANCH_NAME"
      echo "***********************"
- id: 'tf init'
  name: 'hashicorp/terraform:1.0.0'
  entrypoint: 'sh'
  args: 
  - '-c'
  - |
      if [ -d "enviroments/$BRANCH_NAME/" ]; then
        cd enviroments/$BRANCH_NAME
        terraform init
      else
        for dir in enviroments/*/
        do 
          cd ${dir}   
          env=${dir%*/}
          env=${env#*/}
          echo ""
          echo "*************** TERRAFORM INIT ******************"
          echo "******* At enviroment: ${env} ********"
          echo "*************************************************"
          terraform init || exit 1
          cd ../../
        done
      fi 
# [START tf-plan]
- id: 'tf plan'
  name: 'hashicorp/terraform:1.0.0'
  entrypoint: 'sh'
  args: 
  - '-c'
  - | 
      if [ -d "enviroments/$BRANCH_NAME/" ]; then
        cd enviroments/$BRANCH_NAME
        terraform plan
      else
        for dir in enviroments/*/
        do 
          cd ${dir}   
          env=${dir%*/}
          env=${env#*/}  
          echo ""
          echo "*************** TERRAFOM PLAN ******************"
          echo "******* At environment: ${env} ********"
          echo "*************************************************"
          terraform plan || exit 1
          cd ../../
        done
      fi 
# [END tf-plan]

# [START tf-apply]
- id: 'tf apply'
  name: 'hashicorp/terraform:1.0.0'
  entrypoint: 'sh'
  args: 
  - '-c'
  - | 
      if [ -d "enviroments/$BRANCH_NAME/" ]; then
        cd enviroments/$BRANCH_NAME      
        terraform apply -auto-approve
      else
        echo "***************************** SKIPPING APPLYING *******************************"
        echo "Branch '$BRANCH_NAME' does not represent an oficial environment."
        echo "*******************************************************************************"
      fi
# [END tf-apply]      
```

With this in place, any time a change was made and pushed to the relevant branch (in this example "dev") the updates would be applied to the currently deployed infrastructure.

# Dev VS Production

I created to Projects
- 	terraform-dev-env-351309
- 	terraform-production-env

Each project has its own CloudBuild trigger and Repo Branch.
- dev = dev branch
- prod = prod branch

Once changed made to dev have been tested and approved, they can be moved into the production file and applied to the production branch.










