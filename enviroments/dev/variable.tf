
variable "project" {
  description = "id of the project being worked on"
  type        = string
  default     = "terraform-dev-env-351309"
}

variable "region" {
  description = "region of the project"
  type        = string
  default     = "europe-west2"
}

variable "subregion" {
  description = "sub - region location of the project"
  type        = string
  default     = "europe-west2-a"
}


variable "vpc" {
  description = "vpc network name"
  type        = string
  default     = "vpc-appsbro-01"
}



variable "subnet" {
  description = "vpc subnet name"
  type        = string
  default     = "subnet-appsbro-01"
}


variable "router" {
  description = "router identifacation"
  type        = string
  default     = "router-appsbro-01"
}


variable "vpc_route_mode" {
  description = "vpc routing mode"
  type        = string
  default     = "REGIONAL"
}


variable "k8scluster" {
  description = "kubernetes cluser id"
  type        = string
  default     = "k8s-appsbro-01"
}

variable "nodelocations" {
  description = "additional zonal location"
  type        = string
  default     = "europe-west2-c"
}


variable "k8snode1" {
  description = "kubernetes node 1 id"
  type        = string
  default     = "node-appsbro-01"
}

variable "k8snode2" {
  description = "kubernetes node 2 id"
  type        = string
  default     = "node-appsbro-02"
}

variable "k8snode_machine" {
  description = "k8snode machine type"
  type        = string
  default     = "e2-medium"
}


variable "k8s_svca" {
  description = "kubernetes service account id"
  type        = string
  default     = "kubernetes-svca"
}


variable "min_node_count" {
  description = "minimum kubernetes node count"
  type        = number
  default     = 2
}

variable "max_node_count" {
  description = "maximum kubernetes node count"
  type        = number
  default     = 10
}


variable "sql_id" {
  description = "sql instance id"
  type        = string
  default     = "sql-appsbro-001"
}


variable "sql_ver" {
  description = "sql instance version"
  type        = string
  default     = "MYSQL_8_0"
}

variable "sql_tier" {
  description = "sql instance machine tier"
  type        = string
  default     = "db-f1-micro"
}

variable "sql_db" {
  description = "SQL database id "
  type        = string
  default     = "database-appsbro-01"
}


variable "db_user" {
  description = "database user id"
  type        = string
  default     = "db-user-appsbro-01"
}


variable "db_user_access" {
  description = "database user id host access control"
  type        = string
  default     = "% (any host)"
}


  variable "db_password" {
description = "db password"
  type        = string
  default     = "Password123!"
}
  

variable "repo" {
  description = "name of the artifact repo"
  type        = string
  default     = "repo"
}

variable "repo_description" {
  description = "description of the artifact repo"
  type        = string
  default     = "sample-app"
}


variable "repo_format" {
  description = "FORMAT of the artifact repo"
  type        = string
  default     = "DOCKER"
}
