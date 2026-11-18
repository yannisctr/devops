#!/usr/bin/env bash
# Charge le profil créé dans un dossier temporaire pour la démonstration.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    echo 'Utilisation : source scripts/minikube-env.sh' >&2
    exit 2
fi

if [[ ! -r /tmp/tp-devops-tools-path ]] ||
    ! read -r TP_DEVOPS_MINIKUBE_DIR < /tmp/tp-devops-tools-path ||
    [[ ! -x $TP_DEVOPS_MINIKUBE_DIR/minikube ||
       ! -x $TP_DEVOPS_MINIKUBE_DIR/kubectl ||
       ! -s $TP_DEVOPS_MINIKUBE_DIR/kubeconfig ]]; then
    echo 'Profil temporaire introuvable. Pour un nouveau poste, suivre la procédure Minikube du README.' >&2
    unset TP_DEVOPS_MINIKUBE_DIR
    return 1
fi

case ":$PATH:" in
    *":$TP_DEVOPS_MINIKUBE_DIR:"*) ;;
    *) export PATH="$TP_DEVOPS_MINIKUBE_DIR:$PATH" ;;
esac
export MINIKUBE_HOME="$TP_DEVOPS_MINIKUBE_DIR"
export KUBECONFIG="$TP_DEVOPS_MINIKUBE_DIR/kubeconfig"
unset TP_DEVOPS_MINIKUBE_DIR
