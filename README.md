# EKS Resource

A Concourse resource for controlling the Kubernetes cluster inside the AWS EKS cluster.

*This resource is designed to be used on AWS EKS alongside Concourse Helm deployment.*

## K8s Versions

This resource supports and is compatible with `Kubernetes 1.21`.

## Source Configuration

- `kubeconfig_file`: *Optional.* Specify the location of your kubeconfig.
- `kubeconfig`: *Optional.* Write your kubeconfig directly in the pipeline. Example:

    ```yaml
    kubeconfig: |
      apiVersion: v1
      clusters:
      - cluster:
        ...
    ```

- `context`: *Optional.* The context to use when specifying a `kubeconfig` or `kubeconfig_file`
- `aws_eks_cluster_name`: *Optional.* the AWS EKS cluster name.
- `aws_eks_region`: *Optional.* the AWS region (eg. `eu-central-1`).
  - must be supplied if `aws_eks_cluster_name` is supplied
- `aws_iam_role`: *Optional.* the AWS IAM role ARN to assume.
  - The IAM Role automatically generates the following:
  - `aws_access_key_id`: *Optional.* AWS access key to use.
  - `aws_secret_access_key`: *Optional.* AWS secret key to use.
  - `aws_session_token`: *Optional.* AWS session token (assumed role) to use.
- `namespace`: *Optional.* The namespace scope. Defaults to `default`. If set along with `kubeconfig`, `namespace` takes priority.
- `helm_repo_add`: *Optional.* Specify the helm repository to use.

## Behavior

### `check`: Do nothing

### `in`: Do nothing

### `out`: Control the Kubernetes cluster

Control the Kubernetes cluster with `kubectl`, `aws` or `helm`.

## Parameters

### Note: you need at least 1 of the following:

- `kubectl`: *Optional.* Specify the operation that you want to perform with kubectl.
- `aws`: *Optional.* Specify the operation that you want to perform with aws.
- `helm`: *Optional.* Specify the operation you wish to do with helm.

### Other parameters

- `context`: *Optional.* The context to use when specifying a `kubeconfig` or `kubeconfig_file`
- `wait_until_ready`: *Optional.* The number of seconds that waits until all pods are ready. 0 means don't wait. Defaults to `30`.
- `wait_until_ready_interval`: *Optional.* The interval (sec) on which to check whether all pods are ready. Defaults to `3`.
- `wait_until_ready_selector`: *Optional.* [A label selector](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#label-selectors) to identify a set of pods which to check whether those are ready. Defaults to every pods in the namespace.

## Examples

```yaml
resource_types:
- name: kubernetes
  type: docker-image
  source:
    repository: zlabjp/kubernetes-resource
    tag: "1.17"

resources:
- name: kubernetes-production
  type: kubernetes
  source:
    server: https://192.168.99.100:8443
    namespace: production
    token: {{kubernetes-production-token}}
    certificate_authority: {{kubernetes-production-cert}}
- name: my-app
  type: git
  source:
    ...

jobs:
- name: kubernetes-deploy-production
  plan:
  - get: my-app
    trigger: true
  - put: kubernetes-production
    params:
      kubectl: apply -f my-app/k8s -f my-app/k8s/production
      wait_until_ready_selector: app=myapp
```

### Force update deployment

```yaml
jobs:
- name: force-update-deployment
  serial: true
  plan:
  - put: mycluster
    params:
      kubectl: |
        patch deploy nginx -p '{"spec":{"template":{"metadata":{"labels":{"updated_at":"'$(date +%s)'"}}}}}'
      wait_until_ready_selector: run=nginx
```

### Use a remote kubeconfig file fetched by s3-resource

```yaml
resources:
- name: k8s-prod
  type: kubernetes

- name: kubeconfig-file
  type: s3
  source:
    bucket: mybucket
    versioned_file: config
    access_key_id: ((s3-access-key))
    secret_access_key: ((s3-secret))

- name: my-app
  type: git
  source:
    ...

jobs:
- name: k8s-deploy-prod
  plan:
  - aggregate:
    - get: my-app
      trigger: true
    - get: kubeconfig-file
  - put: k8s-prod
    params:
      kubectl: apply -f my-app/k8s -f my-app/k8s/production
      wait_until_ready_selector: app=myapp
      kubeconfig_file: kubeconfig-file/config
```

## License

This software is released under the MIT License.
