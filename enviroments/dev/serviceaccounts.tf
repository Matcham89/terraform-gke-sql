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
