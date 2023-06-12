# Облачный провайдер - Yandex cloud
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">=0.84.0"
    }
  }
}