#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

environment=${1:-}
source_sha=${2:-}
registry=${3:-}
if [[ ! $environment =~ ^(val|prod)$ || ! $source_sha =~ ^[0-9a-f]{40}$ || ! $registry =~ ^(local|[a-z0-9][a-z0-9_-]*)$ || $# != 3 ]]; then
    echo "Usage: $0 {val|prod} SHA_GIT {COMPTE_DOCKERHUB|local}" >&2
    exit 2
fi
if [[ $registry == mon_compte_docker_hub || $registry == compte_docker_hub ]]; then
    echo 'Indique le compte Docker Hub qui a publié les images de ce SHA, ou utilise le mode local de Minikube.' >&2
    exit 2
fi

context=${KUBE_CONTEXT:-tp-devops}
kube() { kubectl --context "$context" "$@"; }
kube cluster-info >/dev/null
source_tree=$(git rev-parse "$source_sha^{tree}")
if [[ $(git rev-parse HEAD^{tree}) != "$source_tree" || -n $(git status --porcelain) ]]; then
    echo 'Utilise un checkout propre du contenu exact correspondant à la version.' >&2
    exit 1
fi
read_release() {
    kube -n val get configmap todo-release -o "jsonpath={.data.$1}"
}
if [[ $environment == prod ]]; then
    if [[ $(read_release sha) != "$source_sha" || $(read_release registry) != "$registry" ]]; then
        echo 'Cette version doit avoir passé le smoke test en VAL.' >&2
        exit 1
    fi
    if [[ $registry != local ]]; then
        git fetch origin main
        if [[ $(git rev-parse FETCH_HEAD^{tree}) != "$source_tree" ]]; then
            echo 'Le contenu de la version validée doit être promu sur origin/main.' >&2
            exit 1
        fi
    fi
fi

tmp=$(mktemp -d)
forward=''
cleanup() {
    if [[ -n $forward ]]; then
        kill "$forward" 2>/dev/null || true
        wait "$forward" 2>/dev/null || true
    fi
    rm -r "$tmp"
}
trap cleanup EXIT
cp -R k8s "$tmp/"
overlay="$tmp/k8s/$environment"
printf 'images:\n' >> "$overlay/kustomization.yaml"
release_args=()
for service in frontend backend database; do
    image="$registry/tp-$service"
    if [[ $registry == local ]]; then
        version="newTag: $source_sha"
    elif [[ $environment == prod ]]; then
        version="digest: $(read_release "$service")"
    else
        if ! digest=$(docker buildx imagetools inspect "$image:$source_sha" --format '{{json .Manifest}}' |
            jq -er '.digest | select(test("^sha256:[0-9a-f]{64}$"))'); then
            echo "Image Docker Hub inaccessible : $image:$source_sha" >&2
            echo 'Vérifier le compte et la publication de ce SHA dans GitHub Actions. Pour une démo sans Docker Hub, suivre le mode local du README.' >&2
            exit 1
        fi
        version="digest: $digest"
    fi
    if [[ $version == "digest: "* && ! $version =~ ^digest:\ sha256:[0-9a-f]{64}$ ]]; then
        echo "Digest invalide pour $image" >&2
        exit 1
    fi
    printf '  - name: tp-%s\n    newName: %s\n    %s\n' "$service" "$image" "$version" >> "$overlay/kustomization.yaml"
    release_args+=("--from-literal=$service=${version#*: }")
done

kube apply -f "$overlay/namespace.yaml"
if ! secret=$(kube -n "$environment" get secret todo-db --ignore-not-found -o name); then
    exit 1
fi
if [[ -z $secret ]]; then
    umask 077
    printf '%s' "$(openssl rand -hex 32)" > "$tmp/password"
    printf '%s' "$(openssl rand -hex 32)" > "$tmp/root-password"
    kube -n "$environment" create secret generic todo-db --from-file="$tmp/password" --from-file="$tmp/root-password"
fi

kube apply -k "$overlay"
for service in database backend frontend; do
    kube -n "$environment" rollout status "deployment/$service" --timeout=300s
done
kube -n "$environment" port-forward svc/frontend :80 > "$tmp/forward" 2>&1 &
forward=$!
port=''
for attempt in {1..30}; do
    port=$(sed -n 's/^Forwarding from 127\.0\.0\.1:\([0-9]*\) -> 80$/\1/p' "$tmp/forward")
    [[ -n $port ]] && break
    if ! kill -0 "$forward" 2>/dev/null; then
        cat "$tmp/forward" >&2
        exit 1
    fi
    sleep 1
done
[[ -n $port ]] || { cat "$tmp/forward" >&2; exit 1; }
bash scripts/smoke-test.sh "http://127.0.0.1:$port"
kube -n "$environment" create configmap todo-release --from-literal="sha=$source_sha" --from-literal="registry=$registry" \
    "${release_args[@]}" --dry-run=client -o yaml | kube apply -f -
kube -n "$environment" get pods,svc,pvc
