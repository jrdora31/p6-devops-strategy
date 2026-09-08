terraform {
  # L'adresse et les credentials du state GitLab microcrm-network sont fournis
  # à l'exécution par les variables TF_HTTP_*.
  backend "http" {}
}
