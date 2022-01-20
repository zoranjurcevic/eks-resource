<!-- PROJECT LOGO -->
<br />
<p align="center">
  <a href="https://github.com/zoranjurcevic/eks-resource">
    <img src="docs/img/concourse.png" alt="Logo" width="100" height="100">
  </a>

  <h3 align="center">EKS Resource</h3>

  <p align="center">
    A Concourse CI/CD resource for the Helm deployment inside EKS
    <br />
    <a href="">Report Bug</a>
    ·
    <a href="">Request Feature</a>
  </p>
</p>

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
- name: eks-resource
  type: docker-image
  source:
    repository: zoranjurc/eks-resource
    tag: latest

resources:
- name: eks
  type: eks-resource
  source: 
    aws_eks_cluster_name: ((aws.cluster-name))
    aws_iam_role: ((aws.iam-role))
    aws_eks_region: eu-central-1
- name: my-app
  type: git
  source:
    ...

jobs:
- name: kubernetes-deploy-production
  plan:
  - get: my-app
    trigger: true
  - put: eks
    params:
      kubectl: apply -f my-app/k8s -f my-app/k8s/production
      wait_until_ready_selector: app=myapp
```

### Deploy an instance to EC2

```yaml
jobs:
- name: deploy-ec2
  serial: true
  plan:
  - put: eks
    params:
      aws: ec2 run-instances --image-id ((aws.image-id)) --count 1 --region eu-central-1 \ 
      --instance-type t2.micro --key-name ((aws.key-name)) --security-group-ids ((aws.security-group)) \
      --subnet-id ((aws.subnet-id)) --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=demotest}]'
```

### Use helm to update PostgreSQL

```yaml
resources:
- name: eks
  type: eks-resource
  source: 
    aws_eks_cluster_name: ((aws.cluster-name))
    aws_iam_role: ((aws.iam-role))
    aws_eks_region: eu-central-1
- name: my-app
  type: git
  source:
    ...

jobs:
- name: update-helm-deployment
  plan:
  - get: my-app
    trigger: true
  - put: eks
    params:
      helm: upgrade -f my-app/postgres.yaml my-release bitnami/postgresql
```

## License

This software is released under the MIT License.
