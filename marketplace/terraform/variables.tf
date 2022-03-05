variable "ingestion_storage_bucket_suffix" {
  default = "-datashare-ingestion"
}

variable "ingestion_storage_bucket_storage_class" {
  default = "STANDARD"
}

variable "config_name" {
  default = "datashare-startup-config"
}

variable "api_service_account_name" {
  default = "ds-api-mgr"
}

variable "api_service_account_descr" {
  default = "DS API Manager"
}

variable "api_custom_role" {
  default = "custom.ds.api.mgr"
}

variable "istio_exclude_ip_ranges" {
  default = "169.254.169.254/32"
}

variable "project" {}

#variable "credentials_file" { }

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-c"
}

variable "deployment_name" {
  type    = string
  default = "datashare"
}

variable "vm_image_version" {
  default = "gcp-financial-services-debian-datashare-20210817"
}

variable "vm_series" {
  default     = "N1"
  description = "The startup VMs series type"
}

variable "vm_machine_type" {
  default     = "f1-micro"
  description = "The startup VMs machine type"
}

# TODO figure out the correct way to enter this value
variable "vm_boot_disk" {
  default     = ""
  description = "Startup VM boot disk."
}

variable "vm_boot_disk_size" {
  default     = 10
  description = "Startup VM boot disk size in GB."
}

# TODO need to determine correct value here.
variable "vm_network_interface" {
  default     = "default"
  description = "Default network interface for startup VM."
}

variable "datashare_version" {
  default     = "0.7.2"
  description = "The startup VMs machine type"

  validation {
    condition     = "0.7.2" == var.datashare_version
    error_message = "You can only enter the lastest release of 0.7.0."
  }
}

variable "storage_bucket_location" {
  default     = "US"
  description = "The location of the Google Cloud storage bucket used for ingestion."

  validation {
    condition     = var.storage_bucket_location == "US" || var.storage_bucket_location == "EU" || var.storage_bucket_location == "ASIA"
    error_message = "You can only enter the lastest release of 0.7.2."
  }
}

variable "deploy_api_to_cloudrun_gke" {
  default     = true
  description = "Deploys the API to Cloud Run on GKE."
}

variable "gcp_service_account" {
  description = "Service used to deploy all the Datashare resources."
}

variable "gke_cluster_name" {
  default     = "datashare"
  description = "Name of the GKE cluster."
}

variable "gke_zone" {
  default     = "us-central1-a"
  description = "The zone in which to deploy GKE."
}
variable "gke_node_count" {
  default     = 4
  description = "The number of nodes to assign to the GKE cluster."
}

variable "gke_version" {
  default     = "1.18"
  description = "GKE version."
}

variable "datashare_oauth_client_id" {
  description = "The OAuth client ID, which is used by the Datashare UI to send requests to the Datashare API."
}

variable "datashare_data_producers" {
  description = "Command delemited list of Datashare admins that have read/write access to Datashare APIs."
}

variable "datashare_api_domain_name" {
  description = "Datashare API domain name (suggested: api.datashare.yourdomain.com)."
}

variable "datashare_ui_domain_name" {
  description = "Datashare domain name (suggested: datashare.yourdomain.com)."
}

variable "datashare_ingestion_source_code_filename" {
  default     = "datashare-toolkit-cloud-function.zip"
  description = "Datashare domain name (suggested: datashare.yourdomain.com)."
}
