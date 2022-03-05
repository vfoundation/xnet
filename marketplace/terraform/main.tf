terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.71.0"
    }
  }
}

provider "google" {
  # credentials = file("<NAME>.json")

  project = var.project
  region  = var.region
  zone    = var.zone
}

resource "google_storage_bucket" "install_bucket" {
  name                        = "${var.project}-install-bucket"
  location                    = var.storage_bucket_location
  force_destroy               = true
  uniform_bucket_level_access = true
  storage_class               = var.ingestion_storage_bucket_storage_class

  provisioner "local-exec" {
    command = "./create-cloud-function-zip.sh"
  }
}

resource "google_storage_bucket" "ingestion_bucket" {
  name                        = "${var.project}${var.ingestion_storage_bucket_suffix}"
  location                    = var.storage_bucket_location
  force_destroy               = true
  uniform_bucket_level_access = true
  storage_class               = var.ingestion_storage_bucket_storage_class
}

resource "google_runtimeconfig_config" "datashare_runtime_config" {
  name        = "${var.deployment_name}-startup-config"
  description = "Runtime configuration for Datashare"
}

resource "google_runtimeconfig_variable" "datashare_runtime_config_success" {
  parent = google_runtimeconfig_config.datashare_runtime_config.name
  name   = "/success/my-instance"
  text   = "wait"
}

resource "google_runtimeconfig_variable" "datashare_runtime_config_failure" {
  parent = google_runtimeconfig_config.datashare_runtime_config.name
  name   = "/failure/my-instance"
  text   = "wait"
}

resource "time_sleep" "vm_startup_success" {
  depends_on      = [google_container_cluster.primary]
  create_duration = "5m"
}

#resource "time_sleep" "vm_startup_success" {
#  create_duration = "5m"
#  triggers = {
# This sets up a dependency on the runtime config success object
#    vm_startup_success = google_runtimeconfig_variable.datashare_runtime_config_success.text
#  }
#}

resource "google_compute_firewall" "datashare_firewall" {
  name    = "${var.deployment_name}-firewall"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["80", "8080", "1000-2000"]
  }

  source_tags = ["datashare"]
}

# TODO - this is automatically added to Firewalls and then fails to delete the VPC network
# TODO - include Firewall rule and add VPC network to firewall rule or force delete the VPC network
resource "google_compute_network" "vpc_network" {
  name = "${var.deployment_name}-network"
}

resource "google_compute_instance" "vm_instance" {
  name         = "${var.deployment_name}-vm"
  machine_type = var.vm_machine_type
  tags         = ["datashare"]
  zone         = var.zone
  depends_on = [
    google_container_cluster.primary,
  ]

  boot_disk {
    initialize_params {
      image = "https://www.googleapis.com/compute/v1/projects/gcp-financial-services-public/global/images/${var.vm_image_version}"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }

  service_account {
    email = var.gcp_service_account
    scopes = ["https://www.googleapis.com/auth/cloud.useraccounts.readonly",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/cloudruntimeconfig"]
  }

  metadata = {
    instanceName           = "${var.deployment_name}-vm"
    useRuntimeConfigWaiter = true
    waiterConfigName       = var.config_name
    deployApiToGke         = var.deploy_api_to_cloudrun_gke
    #sourceImage: https://www.googleapis.com/compute/v1/projects/gcp-financial-services-public/global/images/{{ imageNames[selectedImageIndex] }}
    gceServiceAccount          = var.gcp_service_account
    ingestionBucketName        = "${var.project}${var.ingestion_storage_bucket_suffix}"
    configName                 = "${var.deployment_name}-startup-config"
    datashareGitReleaseVersion = var.datashare_version
    apiServiceAccountName      = var.api_service_account_name
    apiServiceAccountDesc      = var.api_service_account_descr
    apiCustomRole              = var.api_custom_role
    istioExcludeIpRanges       = var.istio_exclude_ip_ranges
    oauthClientId              = var.datashare_oauth_client_id
    dataProducers              = var.datashare_data_producers
    gkeZone                    = var.gke_zone
    gkeClusterName             = var.gke_cluster_name
  }
  metadata_startup_script = file("./vm-startup-script.sh")

}

# Kubernetes cluster setup
resource "google_container_cluster" "primary" {
  name               = var.deployment_name
  location           = var.gke_zone
  initial_node_count = var.gke_node_count
  min_master_version = var.gke_version
  network            = google_compute_network.vpc_network.name

  addons_config {
    http_load_balancing {
      disabled = false
    }
    cloudrun_config {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  workload_identity_config {
    identity_namespace = "${var.project}.svc.id.goog"
  }

  node_config {
    service_account = var.gcp_service_account
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring"
    ]
    labels = {
      datashare = "true"
    }
    tags = ["datashare"]
  }

  timeouts {
    create = "30m"
    update = "40m"
  }
}



# For Cloud Function source code file
resource "google_storage_bucket_object" "cloud_function_source_code" {
  name   = var.datashare_ingestion_source_code_filename
  bucket = google_storage_bucket.install_bucket.name
  source = "/tmp/datashare-toolkit/ingestion/batch/${var.datashare_ingestion_source_code_filename}"
}

resource "google_cloudfunctions_function" "datashare_cloud_function" {
  name        = "myProcess"
  description = "Datashare ingestion function"
  runtime     = "nodejs14"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.install_bucket.name
  source_archive_object = google_storage_bucket_object.cloud_function_source_code.name
  trigger_http          = true
  timeout               = 60
  entry_point           = "processEvent"
  labels = {
    datashare = "success"
  }

  # This looks like it is the correct setup
  #depends_on = [time_sleep.vm_startup_success.triggers["vm_startup_success"]]
  #depends_on = [time_sleep.vm_startup_success]
  #depends_on = [google_compute_instance.vm_instance]

  environment_variables = {
    VERBOSE_MODE  = "true",
    ARCHIVE_FILES = "false",
  }
}
