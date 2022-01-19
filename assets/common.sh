#!/usr/bin/env bash

# For the full copyright and license information, please view the LICENSE
# file that was distributed with this source code.

# setup_kubectl prepares kubectl and exports the KUBECONFIG environment variable.
setup_kubectl() {
  local payload
  payload=$1

  # the entry name for auth of kubeconfig
  local -r AUTH_NAME=auth
  # the entry name for cluster of kubeconfig
  local -r CLUSTER_NAME=cluster
  # the entry name for context of kubeconfig
  local -r CONTEXT_NAME=kubernetes-resource

  KUBECONFIG="$(mktemp "$TMPDIR/kubernetes-resource-kubeconfig.XXXXXX")"
  export KUBECONFIG

  # Optional. The path of kubeconfig file
  local kubeconfig_file
  kubeconfig_file="$(jq -r '.source.kubeconfig_file // ""' < "$payload")"
  # Optional. The content of kubeconfig
  local kubeconfig
  kubeconfig="$(jq -r '.source.kubeconfig // ""' < "$payload")"

  if [[ -n "$kubeconfig_file"  ]]; then
    if [[ ! -f "$kubeconfig_file" ]]; then
      echoerr "kubeconfig file '$kubeconfig_file' does not exist"
      exit 1
    fi
    cat "$kubeconfig_file" > "$KUBECONFIG"
  elif [[ -n "$kubeconfig" ]]; then
    echo "$kubeconfig" > "$KUBECONFIG"
  else
    # Update AWS EKS region via aws-cli
    local aws_eks_cluster_name
    aws_eks_cluster_name="$(jq -r '.source.aws_eks_cluster_name // ""' < "$payload")"
    local aws_eks_region
    aws_eks_region="$(jq -r '.source.aws_eks_region // ""' < "$payload")"

    if [[ -n "$aws_eks_cluster_name" && -n "$aws_eks_region" ]]; then
    aws eks --region $aws_eks_region update-kubeconfig --name $aws_eks_cluster_name > /dev/null
    fi
  fi

  # Optional. The namespace scope. Defaults to default if doesn't specify in kubeconfig.
  local namespace
  namespace="$(jq -r '.source.namespace // ""' < "$payload")"
  if [[ -n "$namespace" ]]; then
    kubectl config set-context "$(kubectl config current-context)" --namespace="$namespace" > /dev/null
  fi

  # Optional. Assume AWS IAM Role
  local aws_iam_role
  aws_iam_role="$(jq -r '.source.aws_eks_assume_role // ""' < "$payload")"
  if [[ -n "$aws_iam_role" ]]; then
    aws sts assume-role --role-arn $aws_iam_role --role-session-name Concourse > file.json
    export AWS_ACCESS_KEY_ID=$(cat file.json | grep -oP '(?<="AccessKeyId": ")[^"]*')
    export AWS_SECRET_ACCESS_KEY=$(cat file.json | grep -oP '(?<="SecretAccessKey": ")[^"]*')
    export AWS_SESSION_TOKEN=$(cat file.json | grep -oP '(?<="SessionToken": ")[^"]*')
    rm file.json
  fi

}

# current_namespace outputs the current namespace.
current_namespace() {
  local namespace

  namespace="$(kubectl config view -o "jsonpath={.contexts[?(@.name==\"$(kubectl config current-context)\")].context.namespace}")"
  [[ -z "$namespace" ]] && namespace=default
  echo $namespace
}

# current_cluster outputs the address and port of the API server.
current_cluster() {
  local cluster

  cluster="$(kubectl config view -o "jsonpath={.contexts[?(@.name==\"$(kubectl config current-context)\")].context.cluster}")"
  kubectl config view -o "jsonpath={.clusters[?(@.name==\"${cluster}\")].cluster.server}"
}

# wait_until_pods_ready waits for all pods to be ready in the current
# namespace, which are excluded terminating and failed/succeeded pods.
# $1: The number of seconds that waits until all pods are ready.
# $2: The interval (sec) on which to check whether all pods are ready.
# $3: A label selector to identify a set of pods which to check whether those are ready. Defaults to every pods in the namespace.
wait_until_pods_ready() {
  local period interval selector template

  period="$1"
  interval="$2"
  selector="$3"

  echo "Waiting for pods to be ready for ${period}s (interval: ${interval}s, selector: ${selector:-''})"

  # The list of "<pod-name> <ready(True|False|`null`)>" which is excluded terminating and failed/succeeded pods.
  template="$(cat <<EOL
{{- range .items -}}
{{- if and (not .metadata.deletionTimestamp) (ne .status.phase "Failed") (ne .status.phase "Succeeded") -}}
{{.metadata.name}}{{range .status.conditions}}{{if eq .type "Ready"}} {{.status}}{{end}}{{end}}{{"\\n"}}
{{- end -}}
{{- end -}}
EOL
)"

  local statuses not_ready ready
  for ((i=0; i<period; i+=interval)); do
    sleep "$interval"

    statuses="$(kubectl get po --selector="$selector" -o template --template="$template")"
    # Some pods don't have "Ready" condition, so we can't determine "not Ready" using "False".
    not_ready="$(echo -n "$statuses" | grep -v -c "True" ||:)"
    ready="$(echo -n "$statuses" | grep -c "True" ||:)"

    echo "Waiting for pods to be ready... ($ready/$((not_ready + ready)))"

    if [[ "$not_ready" -eq 0 ]]; then
      return 0
    fi
  done

  echo "Waited for ${period}s, but the following pods are not ready yet."
  echo "$statuses" | awk '{if ($2 != "True") print "- " $1}'
  return 1
}

# echoerr prints an error message in red color.
echoerr() {
  echo -e "\\e[01;31mERROR: $*\\e[0m"
}

# exe executes the command after printing the command trace to stdout
exe() {
  echo "+ $*"; "$@"
}

# on_exit prints the last error code if it isning  0.
on_exit() {
  local code

  code=$?
  [[ $code -ne 0 ]] && echo && echoerr "Failed with error code $code"
  return $code
}
