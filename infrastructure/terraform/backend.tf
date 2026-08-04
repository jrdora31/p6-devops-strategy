terraform {
  # Les adresses et credentials du state GitLab sont fournis à l'exécution par
  # les variables TF_HTTP_*. Aucun secret de backend n'est écrit dans ce dépôt.
  backend "http" {}
}
