#VPC creation
resource "google_compute_network" "vpc_webapp" {
  name                              = var.vpc
  routing_mode                      = var.vpc_route_mode
  auto_create_subnetworks           = false
  mtu                               = 1460
  delete_default_routes_on_create   = false

}

#private subnet for k8s workers
resource "google_compute_subnetwork" "vpc_private" {
    name = var.subnet
    ip_cidr_range = "10.0.0.0/18" #16000 subnets
    region = var.region
    network = var.vpc
    private_ip_google_access = true

#k8s pods secondary range
    secondary_ip_range {
        range_name = "k8s-pod-range"
        ip_cidr_range = "10.48.0.0/14"
    }
#k8s service range     
    secondary_ip_range {
        range_name = "k8s-service-range"
        ip_cidr_range = "10.52.0.0/20"
    }
}


#!!!!!FIREWALL RULES!!!!!!!!

#allow ssh into vpc
resource "google_compute_firewall" "allow_ssh" {
    name = "allow-ssh"
    network = google_compute_network.vpc_webapp.name
    
    #ssh port definition
    allow {
        protocol = "tcp"
        ports = ["22"]
    }

    source_ranges = [ "0.0.0.0/0" ] 
}

#cloud router used with NAT allow vms without public IP addresses to access internet
resource "google_compute_router" "router01" {
  name = var.router
  region = var.region
  network = var.vpc

  depends_on = [
    google_compute_network.vpc_webapp
  ]
}

#NAT instructions for VPC router
resource "google_compute_router_nat" "nat" {
    name = "nat"
    router = var.router
    region  = var.region

    source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
    nat_ip_allocate_option = "MANUAL_ONLY"

    subnetwork {
        name = google_compute_subnetwork.vpc_private.id
        source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
    }

    nat_ips = [google_compute_address.nat.self_link]

    depends_on = [
    google_compute_network.vpc_webapp
  ]
}

resource "google_compute_address" "nat" {
    name = "nat"
    address_type = "EXTERNAL"
    network_tier = "PREMIUM"
}




######################
######K8S CONFIG######
######################

resource "google_service_account" "kubernetes" {
    account_id = var.k8s_svca
    display_name = var.k8s_svca
}


#control plane configuration
resource "google_container_cluster" "cluster_id" {
    name = var.k8scluster
    location = var.subregion
    remove_default_node_pool = true
    initial_node_count = 1
    network = var.vpc
    subnetwork = var.subnet
    logging_service = "logging.googleapis.com/kubernetes"
    monitoring_service = "monitoring.googleapis.com/kubernetes"
    networking_mode = "VPC_NATIVE"


    depends_on = [
      google_compute_network.vpc_webapp
    ]

    #additional zonal location
    node_locations = [
        var.nodelocations
    ]
    addons_config {
        http_load_balancing {
            disabled = true
        }
        horizontal_pod_autoscaling {
            disabled = false
        }
    }
    release_channel {
        channel = "REGULAR"
    }
    
    workload_identity_config {
        workload_pool = "${var.project}.svc.id.goog"
    }

    ip_allocation_policy {
        cluster_secondary_range_name = "k8s-pod-range"
        services_secondary_range_name = "k8s-service-range"
    }
    
    private_cluster_config {
        enable_private_nodes = true
        enable_private_endpoint = false
        master_ipv4_cidr_block = "172.16.0.0/28"
    }
}

################
# NODE CONFIG #
################

 
resource "google_container_node_pool" "asuna" {
    name = var.k8snode1
    cluster = google_container_cluster.cluster_id.id
    node_count = 1

    management {
    auto_repair = true
    auto_upgrade = true
    }


    node_config {
    preemptible = false
    machine_type = var.k8snode_machine
    

    service_account = google_service_account.kubernetes.email
    oauth_scopes = [ "https://www.googleapis.com/auth/cloud-platform" ]

    }
    depends_on = [
      google_container_cluster.cluster_id
    ]
}

resource "google_container_node_pool" "kirito" {
    name = var.k8snode2
    cluster = google_container_cluster.cluster_id.id

    management {
        auto_repair = true
        auto_upgrade = true
        }

  autoscaling {
        min_node_count = var.min_node_count
        max_node_count = var.max_node_count
        }
    
    #ideal for pipeline
    node_config {
        preemptible = true
        machine_type = var.k8snode_machine

           

    #taint {
     #   key = "instance_type"
      #  value = "asuna"
       # effect = "NO_SCHEDULE"
     #   }
    #
    service_account = google_service_account.kubernetes.email
    oauth_scopes = [ "https://www.googleapis.com/auth/cloud-platform" ]
    }
    depends_on = [
      google_container_cluster.cluster_id
    ]
}


################
#  SQLCONFIG #
################

#resource "google_compute_global_address" "private_ip_address" {
 # provider = google-beta
 # project = var.project
 # name          = "private-ip-address"
 # purpose       = "VPC_PEERING"
 # address_type  = "INTERNAL"
 # prefix_length = 16
 # network       = google_compute_network.vpc_webapp.id
#}

#resource "google_service_networking_connection" "private_vpc_connection" {
#  provider = google-beta

#  network                 = google_compute_network.vpc_webapp.id
#  service                 = "servicenetworking.googleapis.com"
#  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
#}


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
      #private_network = google_compute_network.vpc_webapp.id
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


####################
#  REPO     CONFIG #
####################


resource "google_artifact_registry_repository" "repo" {
  provider = google-beta
  project = var.project
  location = var.region
  repository_id = var.repo
  description = var.repo_description
  format = var.repo_format
}
 


####################
#  ACCOUNT CONFIG #
####################

#dedicated service account

resource "google_project_iam_member" "k8s_iam" {
    project = var.project
    role = "roles/cloudsql.client" 
    member = "serviceAccount:${var.k8s_svca}@${var.project}.iam.gserviceaccount.com"   
}

resource "google_project_iam_member" "repo_iam" {
    project = var.project
    role = "roles/storage.admin" 
    member = "serviceAccount:${var.k8s_svca}@${var.project}.iam.gserviceaccount.com"   
}

resource "google_project_iam_member" "storage_iam" {
    project = var.project
    role = "roles/artifactregistry.reader" 
    member = "serviceAccount:${var.k8s_svca}@${var.project}.iam.gserviceaccount.com"   
}


resource "google_service_account_iam_member" "k8s_workload_id" {
    service_account_id = google_service_account.kubernetes.id
    role = "roles/iam.workloadIdentityUser"
    member = "serviceAccount:${var.project}.svc.id.goog[default/ksa-cloud-sql]"

    depends_on = [
      google_container_cluster.cluster_id
    ]
}
