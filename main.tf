provider "google" {}

resource "google_compute_network" "kubernetes-the-hard-way" {
  name                    = "kubernetes-the-hard-way"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "kubernetes" {
  name          = "kubernetes"
  region        = "europe-west3"
  ip_cidr_range = "10.240.0.0/24"
  network       = "${google_compute_network.kubernetes-the-hard-way.self_link}"
}

resource "google_compute_firewall" "kubernetes-the-hard-way-allow-internal" {
  name    = "kubernetes-the-hard-way-allow-internal"
  network = "${google_compute_network.kubernetes-the-hard-way.name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = ["10.240.0.0/24", "10.200.0.0/16"]
}

resource "google_compute_firewall" "kubernetes-the-hard-way-allow-external" {
  name    = "kubernetes-the-hard-way-allow-external"
  network = "${google_compute_network.kubernetes-the-hard-way.name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_address" "kubernetes-the-hard-way" {
  name         = "kubernetes-the-hard-way"
  address_type = "EXTERNAL"
  region       = "${google_compute_subnetwork.kubernetes.region}"
}

resource "google_compute_instance" "controllers" {
  name         = "controller-${count.index}"
  machine_type = "n1-standard-1"
  zone         = "europe-west3-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
      size  = 30
    }
  }

  network_interface {
    subnetwork    = "${google_compute_subnetwork.kubernetes.name}"
    network_ip    = "10.240.0.1${count.index}"
    access_config = {}
  }

  can_ip_forward = "true"

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  tags  = ["kubernetes-the-hard-way", "controller"]
  count = 3
}

resource "google_compute_instance" "workers" {
  name         = "worker-${count.index}"
  machine_type = "n1-standard-1"
  zone         = "europe-west3-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
      size  = 200
    }
  }

  network_interface {
    subnetwork    = "${google_compute_subnetwork.kubernetes.name}"
    network_ip    = "10.240.0.2${count.index}"
    access_config = {}
  }

  can_ip_forward = "true"

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  tags  = ["kubernetes-the-hard-way", "worker"]
  count = 3
}
