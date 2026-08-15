# 03 — Provision EKS with Terraform

The previous version of this project created the cluster with a 30-line
`eksctl` file. It worked, and it hid almost everything.

This chapter replaces it with Terraform. Not because Terraform is better at
making clusters — eksctl is genuinely excellent at that — but because **eksctl
silently built a VPC you never saw**: nine subnets across three availability
zones, an internet gateway, NAT, route tables, and two magic subnet tags that
decide where your load balancer can go. All of that was always there. You were
just never asked about it.

## What eksctl was doing for you

Read this table next to [`terraform/`](../terraform/). Your mental model is the
old eksctl file, so the mapping is the fastest way in. The row that matters
most is the one with an empty left cell.

| `gitops/eksctl/cluster.yaml` (deleted) | Terraform equivalent |
| --- | --- |
| `metadata.name: devboard` | `module.eks.name` |
| `metadata.region: us-west-2` | `provider "aws" { region }` |
| **— nothing —** | **`module.vpc`, ~50 explicit lines. This is the point of the chapter.** |
| `iam.withOIDC: true` | still created; Pod Identity doesn't need it, but leave it on |
| `instanceType: t3.medium` | `instance_types = ["t3.large"]` |
| `desiredCapacity: 3` | `desired_size = 3` |
| `volumeSize: 20` | `block_device_mappings.xvda.ebs.volume_size` — **not** `disk_size` |
| `ssh.enableSsm: true` | the module attaches the SSM policy to the node role by default |
| `addons: [vpc-cni, coredns, kube-proxy]` | `addons = { vpc-cni = { before_compute = true }, ... }` |
| `aws-ebs-csi-driver` + `wellKnownPolicies` | the addon + `module.ebs_csi_pod_identity` |
| `metrics-server` | `addons.metrics-server` |
| — | `eks-pod-identity-agent` — **new**, and required for External Secrets |

## Apply

```bash
cd terraform
terraform plan      # read this. ~70 resources.
terraform apply     # ~15-20 min, mostly the control plane
```
```hcl
root@ip-20-0-1-248:/opt/devboard/terraform# terraform plan 
module.eks.module.eks_managed_node_group["default"].data.aws_iam_policy_document.assume_role_policy[0]: Reading...
module.external_secrets_pod_identity.data.aws_iam_policy_document.assume[0]: Reading...
module.external_secrets_pod_identity.data.aws_iam_policy_document.base[0]: Reading...
module.external_secrets_pod_identity.data.aws_region.current[0]: Reading...
module.ebs_csi_pod_identity.data.aws_region.current[0]: Reading...
module.eks.data.aws_caller_identity.current[0]: Reading...
module.eks.data.aws_partition.current[0]: Reading...
module.external_secrets_pod_identity.data.aws_partition.current[0]: Reading...
module.external_secrets_pod_identity.data.aws_region.current[0]: Read complete after 0s [id=us-west-2]
module.eks.module.eks_managed_node_group["default"].data.aws_iam_policy_document.assume_role_policy[0]: Read complete after 0s [id=2560088296]
module.eks.data.aws_partition.current[0]: Read complete after 0s [id=aws]
module.external_secrets_pod_identity.data.aws_iam_policy_document.assume[0]: Read complete after 0s [id=819195744]
module.ebs_csi_pod_identity.data.aws_region.current[0]: Read complete after 0s [id=us-west-2]
module.external_secrets_pod_identity.data.aws_partition.current[0]: Read complete after 0s [id=aws]
module.external_secrets_pod_identity.data.aws_iam_policy_document.base[0]: Read complete after 0s [id=1132004489]
module.ebs_csi_pod_identity.data.aws_iam_policy_document.assume[0]: Reading...
data.aws_availability_zones.available: Reading...
module.eks.data.aws_caller_identity.current[0]: Read complete after 0s [id=899805259876]
data.aws_caller_identity.current: Reading...
module.eks.data.aws_iam_policy_document.assume_role_policy[0]: Reading...
module.eks.module.kms.data.aws_caller_identity.current[0]: Reading...
module.external_secrets_pod_identity.data.aws_caller_identity.current[0]: Reading...
module.ebs_csi_pod_identity.data.aws_iam_policy_document.base[0]: Reading...
module.eks.module.kms.data.aws_partition.current[0]: Reading...
module.eks.data.aws_iam_policy_document.assume_role_policy[0]: Read complete after 0s [id=2830595799]
module.ebs_csi_pod_identity.data.aws_iam_policy_document.assume[0]: Read complete after 0s [id=819195744]
module.eks.module.kms.data.aws_partition.current[0]: Read complete after 0s [id=aws]
module.ebs_csi_pod_identity.data.aws_caller_identity.current[0]: Reading...
module.eks.module.kms.data.aws_caller_identity.current[0]: Read complete after 0s [id=899805259876]
module.ebs_csi_pod_identity.data.aws_iam_policy_document.base[0]: Read complete after 0s [id=1132004489]
module.ebs_csi_pod_identity.data.aws_partition.current[0]: Reading...
module.ebs_csi_pod_identity.data.aws_partition.current[0]: Read complete after 0s [id=aws]
module.external_secrets_pod_identity.data.aws_caller_identity.current[0]: Read complete after 0s [id=899805259876]
module.ebs_csi_pod_identity.data.aws_caller_identity.current[0]: Read complete after 0s [id=899805259876]
data.aws_caller_identity.current: Read complete after 0s [id=899805259876]
module.eks.data.aws_iam_session_context.current[0]: Reading...
data.aws_availability_zones.available: Read complete after 0s [id=us-west-2]
module.ebs_csi_pod_identity.data.aws_iam_policy_document.ebs_csi[0]: Reading...
module.ebs_csi_pod_identity.data.aws_iam_policy_document.ebs_csi[0]: Read complete after 0s [id=3979039874]
module.eks.data.aws_iam_session_context.current[0]: Read complete after 0s [id=arn:aws:sts::899805259876:assumed-role/devboard-bastion-admin-role/i-06070d0e6189873bc]
module.external_secrets_pod_identity.data.aws_iam_policy_document.external_secrets[0]: Reading...
module.external_secrets_pod_identity.data.aws_iam_policy_document.external_secrets[0]: Read complete after 0s [id=3999450956]
module.eks.module.eks_managed_node_group["default"].data.aws_ssm_parameter.ami[0]: Reading...
module.eks.module.eks_managed_node_group["default"].data.aws_ssm_parameter.ami[0]: Read complete after 1s [id=/aws/service/eks/optimized-ami/1.34/amazon-linux-2023/x86_64/standard/recommended/release_version]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create
 <= read (data resources)

Terraform will perform the following actions:

  # aws_secretsmanager_secret.postgres will be created
  + resource "aws_secretsmanager_secret" "postgres" {
      + arn                            = (known after apply)
      + description                    = "DevBoard in-cluster Postgres credentials. Value set out of band; see gitops/06-secrets-with-secrets-manager.md."
      + force_overwrite_replica_secret = false
      + id                             = (known after apply)
      + name                           = "devboard/postgres"
      + name_prefix                    = (known after apply)
      + policy                         = (known after apply)
      + recovery_window_in_days        = 0
      + region                         = "us-west-2"
      + tags                           = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                       = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }

      + replica (known after apply)
    }

  # helm_release.argocd[0] will be created
  + resource "helm_release" "argocd" {
      + atomic                     = false
      + chart                      = "argo-cd"
      + cleanup_on_fail            = false
      + create_namespace           = true
      + dependency_update          = false
      + disable_crd_hooks          = false
      + disable_openapi_validation = false
      + disable_webhooks           = false
      + force_update               = false
      + id                         = (known after apply)
      + lint                       = false
      + max_history                = 0
      + metadata                   = (known after apply)
      + name                       = "argocd"
      + namespace                  = "argocd"
      + pass_credentials           = false
      + recreate_pods              = false
      + render_subchart_notes      = true
      + replace                    = false
      + repository                 = "https://argoproj.github.io/argo-helm"
      + reset_values               = false
      + reuse_values               = false
      + set_wo                     = (write-only attribute)
      + skip_crds                  = false
      + status                     = "deployed"
      + take_ownership             = false
      + timeout                    = 900
      + upgrade_install            = false
      + values                     = [
          + <<-EOT
                "configs":
                  "params":
                    "server.insecure": true
                "server":
                  "service":
                    "type": "ClusterIP"
            EOT,
        ]
      + verify                     = false
      + version                    = "10.3.0"
      + wait                       = true
      + wait_for_jobs              = false
    }

  # kubernetes_storage_class_v1.gp3 will be created
  + resource "kubernetes_storage_class_v1" "gp3" {
      + allow_volume_expansion = true
      + id                     = (known after apply)
      + parameters             = {
          + "encrypted" = "true"
          + "fsType"    = "ext4"
          + "type"      = "gp3"
        }
      + reclaim_policy         = "Delete"
      + storage_provisioner    = "ebs.csi.aws.com"
      + volume_binding_mode    = "WaitForFirstConsumer"

      + metadata {
          + annotations      = {
              + "storageclass.kubernetes.io/is-default-class" = "true"
            }
          + generation       = (known after apply)
          + name             = "gp3"
          + resource_version = (known after apply)
          + uid              = (known after apply)
        }
    }

  # module.ebs_csi_pod_identity.aws_eks_pod_identity_association.this["this"] will be created
  + resource "aws_eks_pod_identity_association" "this" {
      + association_arn      = (known after apply)
      + association_id       = (known after apply)
      + cluster_name         = "devboard"
      + disable_session_tags = false
      + external_id          = (known after apply)
      + id                   = (known after apply)
      + namespace            = "kube-system"
      + region               = "us-west-2"
      + role_arn             = (known after apply)
      + service_account      = "ebs-csi-controller-sa"
      + tags                 = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
    }

  # module.ebs_csi_pod_identity.aws_iam_policy.ebs_csi[0] will be created
  + resource "aws_iam_policy" "ebs_csi" {
      + arn              = (known after apply)
      + attachment_count = (known after apply)
      + description      = "Permissions to manage EBS volumes via the container storage interface (CSI) driver"
      + id               = (known after apply)
      + name             = (known after apply)
      + name_prefix      = "AmazonEKS_EBS_CSI-"
      + path             = "/"
      + policy           = jsonencode(
            {
              + Statement = [
                  + {
                      + Action   = [
                          + "ec2:ModifyVolume",
                          + "ec2:EnableFastSnapshotRestores",
                          + "ec2:DetachVolume",
                          + "ec2:DescribeVolumesModifications",
                          + "ec2:DescribeVolumes",
                          + "ec2:DescribeVolumeStatus",
                          + "ec2:DescribeTags",
                          + "ec2:DescribeSnapshots",
                          + "ec2:DescribeInstances",
                          + "ec2:DescribeInstanceTypes",
                          + "ec2:DescribeAvailabilityZones",
                          + "ec2:CreateSnapshot",
                          + "ec2:AttachVolume",
                        ]
                      + Effect   = "Allow"
                      + Resource = "*"
                    },
                  + {
                      + Action   = "ec2:CopyVolumes"
                      + Effect   = "Allow"
                      + Resource = "arn:aws:ec2:*:*:volume/vol-*"
                    },
                  + {
                      + Action    = "ec2:CreateTags"
                      + Condition = {
                          + StringEquals = {
                              + "ec2:CreateAction" = [
                                  + "CreateVolume",
                                  + "CreateSnapshot",
                                  + "CopyVolumes",
                                ]
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = [
                          + "arn:aws:ec2:*:*:volume/*",
                          + "arn:aws:ec2:*:*:snapshot/*",
                        ]
                    },
                  + {
                      + Action   = "ec2:DeleteTags"
                      + Effect   = "Allow"
                      + Resource = [
                          + "arn:aws:ec2:*:*:volume/*",
                          + "arn:aws:ec2:*:*:snapshot/*",
                        ]
                    },
                  + {
                      + Action    = [
                          + "ec2:CreateVolume",
                          + "ec2:CopyVolumes",
                        ]
                      + Condition = {
                          + StringLike = {
                              + "aws:RequestTag/ebs.csi.aws.com/cluster" = "true"
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = "arn:aws:ec2:*:*:volume/*"
                    },
                  + {
                      + Action    = [
                          + "ec2:CreateVolume",
                          + "ec2:CopyVolumes",
                        ]
                      + Condition = {
                          + StringLike = {
                              + "aws:RequestTag/CSIVolumeName" = "*"
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = "arn:aws:ec2:*:*:volume/*"
                    },
                  + {
                      + Action   = "ec2:CreateVolume"
                      + Effect   = "Allow"
                      + Resource = "arn:aws:ec2:*:*:snapshot/*"
                    },
                  + {
                      + Action    = "ec2:DeleteVolume"
                      + Condition = {
                          + StringLike = {
                              + "ec2:ResourceTag/ebs.csi.aws.com/cluster" = "true"
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = "*"
                    },
                  + {
                      + Action    = "ec2:DeleteVolume"
                      + Condition = {
                          + StringLike = {
                              + "ec2:ResourceTag/CSIVolumeName" = "*"
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = "*"
                    },
                  + {
                      + Action    = "ec2:DeleteVolume"
                      + Condition = {
                          + StringLike = {
                              + "ec2:ResourceTag/kubernetes.io/created-for/pvc/name" = "*"
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = "*"
                    },
                  + {
                      + Action    = [
                          + "ec2:LockSnapshot",
                          + "ec2:DeleteSnapshot",
                        ]
                      + Condition = {
                          + StringLike = {
                              + "ec2:ResourceTag/CSIVolumeSnapshotName" = "*"
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = "*"
                    },
                  + {
                      + Action    = [
                          + "ec2:LockSnapshot",
                          + "ec2:DeleteSnapshot",
                        ]
                      + Condition = {
                          + StringLike = {
                              + "ec2:ResourceTag/ebs.csi.aws.com/cluster" = "true"
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = "*"
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + policy_id        = (known after apply)
      + tags             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all         = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
    }

  # module.ebs_csi_pod_identity.aws_iam_role.this[0] will be created
  + resource "aws_iam_role" "this" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = [
                          + "sts:TagSession",
                          + "sts:AssumeRole",
                        ]
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "pods.eks.amazonaws.com"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + force_detach_policies = true
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = (known after apply)
      + name_prefix           = "devboard-ebs-csi-"
      + path                  = "/"
      + tags                  = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all              = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.ebs_csi_pod_identity.aws_iam_role_policy_attachment.ebs_csi[0] will be created
  + resource "aws_iam_role_policy_attachment" "ebs_csi" {
      + id         = (known after apply)
      + policy_arn = (known after apply)
      + role       = (known after apply)
    }

  # module.eks.data.aws_eks_addon_version.this["aws-ebs-csi-driver"] will be read during apply
  # (depends on a resource or a module with changes pending)
 <= data "aws_eks_addon_version" "this" {
      + addon_name         = "aws-ebs-csi-driver"
      + id                 = (known after apply)
      + kubernetes_version = "1.34"
      + most_recent        = true
      + region             = (known after apply)
      + version            = (known after apply)
    }

  # module.eks.data.aws_eks_addon_version.this["coredns"] will be read during apply
  # (depends on a resource or a module with changes pending)
 <= data "aws_eks_addon_version" "this" {
      + addon_name         = "coredns"
      + id                 = (known after apply)
      + kubernetes_version = "1.34"
      + most_recent        = true
      + region             = (known after apply)
      + version            = (known after apply)
    }

  # module.eks.data.aws_eks_addon_version.this["eks-pod-identity-agent"] will be read during apply
  # (depends on a resource or a module with changes pending)
 <= data "aws_eks_addon_version" "this" {
      + addon_name         = "eks-pod-identity-agent"
      + id                 = (known after apply)
      + kubernetes_version = "1.34"
      + most_recent        = true
      + region             = (known after apply)
      + version            = (known after apply)
    }

  # module.eks.data.aws_eks_addon_version.this["kube-proxy"] will be read during apply
  # (depends on a resource or a module with changes pending)
 <= data "aws_eks_addon_version" "this" {
      + addon_name         = "kube-proxy"
      + id                 = (known after apply)
      + kubernetes_version = "1.34"
      + most_recent        = true
      + region             = (known after apply)
      + version            = (known after apply)
    }

  # module.eks.data.aws_eks_addon_version.this["metrics-server"] will be read during apply
  # (depends on a resource or a module with changes pending)
 <= data "aws_eks_addon_version" "this" {
      + addon_name         = "metrics-server"
      + id                 = (known after apply)
      + kubernetes_version = "1.34"
      + most_recent        = true
      + region             = (known after apply)
      + version            = (known after apply)
    }

  # module.eks.data.aws_eks_addon_version.this["vpc-cni"] will be read during apply
  # (depends on a resource or a module with changes pending)
 <= data "aws_eks_addon_version" "this" {
      + addon_name         = "vpc-cni"
      + id                 = (known after apply)
      + kubernetes_version = "1.34"
      + most_recent        = true
      + region             = (known after apply)
      + version            = (known after apply)
    }

  # module.eks.data.tls_certificate.this[0] will be read during apply
  # (config refers to values not yet known)
 <= data "tls_certificate" "this" {
      + certificates = (known after apply)
      + id           = (known after apply)
      + url          = (known after apply)
    }

  # module.eks.aws_cloudwatch_log_group.this[0] will be created
  + resource "aws_cloudwatch_log_group" "this" {
      + arn                         = (known after apply)
      + deletion_protection_enabled = (known after apply)
      + id                          = (known after apply)
      + log_group_class             = (known after apply)
      + name                        = "/aws/eks/devboard/cluster"
      + name_prefix                 = (known after apply)
      + region                      = "us-west-2"
      + retention_in_days           = 7
      + skip_destroy                = false
      + tags                        = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "/aws/eks/devboard/cluster"
          + "Project"   = "devboard"
        }
      + tags_all                    = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "/aws/eks/devboard/cluster"
          + "Project"   = "devboard"
        }
    }

  # module.eks.aws_ec2_tag.cluster_primary_security_group["Cluster"] will be created
  + resource "aws_ec2_tag" "cluster_primary_security_group" {
      + id          = (known after apply)
      + key         = "Cluster"
      + region      = "us-west-2"
      + resource_id = (known after apply)
      + value       = "devboard"
    }

  # module.eks.aws_ec2_tag.cluster_primary_security_group["ManagedBy"] will be created
  + resource "aws_ec2_tag" "cluster_primary_security_group" {
      + id          = (known after apply)
      + key         = "ManagedBy"
      + region      = "us-west-2"
      + resource_id = (known after apply)
      + value       = "terraform"
    }

  # module.eks.aws_ec2_tag.cluster_primary_security_group["Project"] will be created
  + resource "aws_ec2_tag" "cluster_primary_security_group" {
      + id          = (known after apply)
      + key         = "Project"
      + region      = "us-west-2"
      + resource_id = (known after apply)
      + value       = "devboard"
    }

  # module.eks.aws_eks_access_entry.this["cluster_creator"] will be created
  + resource "aws_eks_access_entry" "this" {
      + access_entry_arn  = (known after apply)
      + cluster_name      = (known after apply)
      + created_at        = (known after apply)
      + id                = (known after apply)
      + kubernetes_groups = (known after apply)
      + modified_at       = (known after apply)
      + principal_arn     = "arn:aws:iam::899805259876:role/devboard-bastion-admin-role"
      + region            = "us-west-2"
      + tags              = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all          = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + type              = "STANDARD"
      + user_name         = (known after apply)
    }

  # module.eks.aws_eks_access_policy_association.this["cluster_creator_admin"] will be created
  + resource "aws_eks_access_policy_association" "this" {
      + associated_at = (known after apply)
      + cluster_name  = (known after apply)
      + id            = (known after apply)
      + modified_at   = (known after apply)
      + policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      + principal_arn = "arn:aws:iam::899805259876:role/devboard-bastion-admin-role"
      + region        = "us-west-2"

      + access_scope {
          + type = "cluster"
        }
    }

  # module.eks.aws_eks_addon.before_compute["eks-pod-identity-agent"] will be created
  + resource "aws_eks_addon" "before_compute" {
      + addon_name                  = "eks-pod-identity-agent"
      + addon_version               = (known after apply)
      + arn                         = (known after apply)
      + cluster_name                = (known after apply)
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + region                      = "us-west-2"
      + resolve_conflicts_on_create = "NONE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + tags                        = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                    = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }

      + namespace_config (known after apply)

      + timeouts {}
    }

  # module.eks.aws_eks_addon.before_compute["vpc-cni"] will be created
  + resource "aws_eks_addon" "before_compute" {
      + addon_name                  = "vpc-cni"
      + addon_version               = (known after apply)
      + arn                         = (known after apply)
      + cluster_name                = (known after apply)
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + region                      = "us-west-2"
      + resolve_conflicts_on_create = "NONE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + tags                        = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                    = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }

      + namespace_config (known after apply)

      + timeouts {}
    }

  # module.eks.aws_eks_addon.this["aws-ebs-csi-driver"] will be created
  + resource "aws_eks_addon" "this" {
      + addon_name                  = "aws-ebs-csi-driver"
      + addon_version               = (known after apply)
      + arn                         = (known after apply)
      + cluster_name                = (known after apply)
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + region                      = "us-west-2"
      + resolve_conflicts_on_create = "NONE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + tags                        = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                    = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }

      + namespace_config (known after apply)

      + timeouts {}
    }

  # module.eks.aws_eks_addon.this["coredns"] will be created
  + resource "aws_eks_addon" "this" {
      + addon_name                  = "coredns"
      + addon_version               = (known after apply)
      + arn                         = (known after apply)
      + cluster_name                = (known after apply)
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + region                      = "us-west-2"
      + resolve_conflicts_on_create = "NONE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + tags                        = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                    = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }

      + namespace_config (known after apply)

      + timeouts {}
    }

  # module.eks.aws_eks_addon.this["kube-proxy"] will be created
  + resource "aws_eks_addon" "this" {
      + addon_name                  = "kube-proxy"
      + addon_version               = (known after apply)
      + arn                         = (known after apply)
      + cluster_name                = (known after apply)
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + region                      = "us-west-2"
      + resolve_conflicts_on_create = "NONE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + tags                        = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                    = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }

      + namespace_config (known after apply)

      + timeouts {}
    }

  # module.eks.aws_eks_addon.this["metrics-server"] will be created
  + resource "aws_eks_addon" "this" {
      + addon_name                  = "metrics-server"
      + addon_version               = (known after apply)
      + arn                         = (known after apply)
      + cluster_name                = (known after apply)
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + region                      = "us-west-2"
      + resolve_conflicts_on_create = "NONE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + tags                        = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                    = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }

      + namespace_config (known after apply)

      + timeouts {}
    }

  # module.eks.aws_eks_cluster.this[0] will be created
  + resource "aws_eks_cluster" "this" {
      + arn                           = (known after apply)
      + bootstrap_self_managed_addons = false
      + certificate_authority         = (known after apply)
      + cluster_id                    = (known after apply)
      + created_at                    = (known after apply)
      + deletion_protection           = (known after apply)
      + enabled_cluster_log_types     = [
          + "audit",
          + "authenticator",
        ]
      + endpoint                      = (known after apply)
      + id                            = (known after apply)
      + identity                      = (known after apply)
      + name                          = "devboard"
      + platform_version              = (known after apply)
      + region                        = "us-west-2"
      + role_arn                      = (known after apply)
      + status                        = (known after apply)
      + tags                          = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                      = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + version                       = "1.34"

      + access_config {
          + authentication_mode                         = "API_AND_CONFIG_MAP"
          + bootstrap_cluster_creator_admin_permissions = false
        }

      + compute_config (known after apply)

      + control_plane_scaling_config (known after apply)

      + encryption_config {
          + resources = [
              + "secrets",
            ]

          + provider {
              + key_arn = (known after apply)
            }
        }

      + kube_api_server_config (known after apply)

      + kube_controller_manager_config (known after apply)

      + kube_scheduler_config (known after apply)

      + kubernetes_network_config {
          + ip_family         = "ipv4"
          + service_ipv4_cidr = (known after apply)
          + service_ipv6_cidr = (known after apply)

          + elastic_load_balancing (known after apply)
        }

      + storage_config (known after apply)

      + upgrade_policy (known after apply)

      + vpc_config {
          + cluster_security_group_id = (known after apply)
          + control_plane_egress_mode = (known after apply)
          + endpoint_private_access   = true
          + endpoint_public_access    = true
          + public_access_cidrs       = [
              + "0.0.0.0/0",
            ]
          + security_group_ids        = (known after apply)
          + subnet_ids                = (known after apply)
          + vpc_id                    = (known after apply)
        }
    }

  # module.eks.aws_iam_openid_connect_provider.oidc_provider[0] will be created
  + resource "aws_iam_openid_connect_provider" "oidc_provider" {
      + arn             = (known after apply)
      + client_id_list  = [
          + "sts.amazonaws.com",
        ]
      + id              = (known after apply)
      + tags            = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-eks-irsa"
          + "Project"   = "devboard"
        }
      + tags_all        = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-eks-irsa"
          + "Project"   = "devboard"
        }
      + thumbprint_list = (known after apply)
      + url             = (known after apply)
    }

  # module.eks.aws_iam_policy.cluster_encryption[0] will be created
  + resource "aws_iam_policy" "cluster_encryption" {
      + arn              = (known after apply)
      + attachment_count = (known after apply)
      + description      = "Cluster encryption policy to allow cluster role to utilize CMK provided"
      + id               = (known after apply)
      + name             = (known after apply)
      + name_prefix      = "devboard-cluster-ClusterEncryption"
      + path             = "/"
      + policy           = (known after apply)
      + policy_id        = (known after apply)
      + tags             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all         = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
    }

  # module.eks.aws_iam_role.this[0] will be created
  + resource "aws_iam_role" "this" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = [
                          + "sts:TagSession",
                          + "sts:AssumeRole",
                        ]
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "eks.amazonaws.com"
                        }
                      + Sid       = "EKSClusterAssumeRole"
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + force_detach_policies = true
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = (known after apply)
      + name_prefix           = "devboard-cluster-"
      + path                  = "/"
      + tags                  = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all              = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.eks.aws_iam_role_policy_attachment.cluster_encryption[0] will be created
  + resource "aws_iam_role_policy_attachment" "cluster_encryption" {
      + id         = (known after apply)
      + policy_arn = (known after apply)
      + role       = (known after apply)
    }

  # module.eks.aws_iam_role_policy_attachment.this["AmazonEKSClusterPolicy"] will be created
  + resource "aws_iam_role_policy_attachment" "this" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
      + role       = (known after apply)
    }

  # module.eks.aws_security_group.cluster[0] will be created
  + resource "aws_security_group" "cluster" {
      + arn                    = (known after apply)
      + description            = "EKS cluster security group"
      + egress                 = (known after apply)
      + id                     = (known after apply)
      + ingress                = (known after apply)
      + name                   = (known after apply)
      + name_prefix            = "devboard-cluster-"
      + owner_id               = (known after apply)
      + region                 = "us-west-2"
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-cluster"
          + "Project"   = "devboard"
        }
      + tags_all               = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-cluster"
          + "Project"   = "devboard"
        }
      + vpc_id                 = (known after apply)
    }

  # module.eks.aws_security_group.node[0] will be created
  + resource "aws_security_group" "node" {
      + arn                    = (known after apply)
      + description            = "EKS node shared security group"
      + egress                 = (known after apply)
      + id                     = (known after apply)
      + ingress                = (known after apply)
      + name                   = (known after apply)
      + name_prefix            = "devboard-node-"
      + owner_id               = (known after apply)
      + region                 = "us-west-2"
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Cluster"                        = "devboard"
          + "ManagedBy"                      = "terraform"
          + "Name"                           = "devboard-node"
          + "Project"                        = "devboard"
          + "kubernetes.io/cluster/devboard" = "owned"
        }
      + tags_all               = {
          + "Cluster"                        = "devboard"
          + "ManagedBy"                      = "terraform"
          + "Name"                           = "devboard-node"
          + "Project"                        = "devboard"
          + "kubernetes.io/cluster/devboard" = "owned"
        }
      + vpc_id                 = (known after apply)
    }

  # module.eks.aws_security_group_rule.cluster["ingress_nodes_443"] will be created
  + resource "aws_security_group_rule" "cluster" {
      + description              = "Node groups to cluster API"
      + from_port                = 443
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 443
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["egress_all"] will be created
  + resource "aws_security_group_rule" "node" {
      + cidr_blocks              = [
          + "0.0.0.0/0",
        ]
      + description              = "Allow all egress"
      + from_port                = 0
      + id                       = (known after apply)
      + protocol                 = "-1"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 0
      + type                     = "egress"
    }

  # module.eks.aws_security_group_rule.node["ingress_cluster_10251_webhook"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Cluster API to node 10251/tcp webhook"
      + from_port                = 10251
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 10251
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_cluster_443"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Cluster API to node groups"
      + from_port                = 443
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 443
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_cluster_4443_webhook"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Cluster API to node 4443/tcp webhook"
      + from_port                = 4443
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 4443
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_cluster_6443_webhook"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Cluster API to node 6443/tcp webhook"
      + from_port                = 6443
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 6443
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_cluster_8443_webhook"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Cluster API to node 8443/tcp webhook"
      + from_port                = 8443
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 8443
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_cluster_9443_webhook"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Cluster API to node 9443/tcp webhook"
      + from_port                = 9443
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 9443
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_cluster_kubelet"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Cluster API to node kubelets"
      + from_port                = 10250
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 10250
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_nodes_ephemeral"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Node to node ingress on ephemeral ports"
      + from_port                = 1025
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = true
      + source_security_group_id = (known after apply)
      + to_port                  = 65535
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_self_coredns_tcp"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Node to node CoreDNS"
      + from_port                = 53
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = true
      + source_security_group_id = (known after apply)
      + to_port                  = 53
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_self_coredns_udp"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Node to node CoreDNS UDP"
      + from_port                = 53
      + id                       = (known after apply)
      + protocol                 = "udp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = true
      + source_security_group_id = (known after apply)
      + to_port                  = 53
      + type                     = "ingress"
    }

  # module.eks.time_sleep.this[0] will be created
  + resource "time_sleep" "this" {
      + create_duration = "30s"
      + id              = (known after apply)
      + triggers        = {
          + "certificate_authority_data" = (known after apply)
          + "endpoint"                   = (known after apply)
          + "kubernetes_version"         = "1.34"
          + "name"                       = (known after apply)
          + "service_cidr"               = (known after apply)
        }
    }

  # module.external_secrets_pod_identity.aws_eks_pod_identity_association.this["this"] will be created
  + resource "aws_eks_pod_identity_association" "this" {
      + association_arn      = (known after apply)
      + association_id       = (known after apply)
      + cluster_name         = "devboard"
      + disable_session_tags = false
      + external_id          = (known after apply)
      + id                   = (known after apply)
      + namespace            = "external-secrets"
      + region               = "us-west-2"
      + role_arn             = (known after apply)
      + service_account      = "external-secrets"
      + tags                 = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
    }

  # module.external_secrets_pod_identity.aws_iam_policy.external_secrets[0] will be created
  + resource "aws_iam_policy" "external_secrets" {
      + arn              = (known after apply)
      + attachment_count = (known after apply)
      + description      = "Permissions for External Secrets"
      + id               = (known after apply)
      + name             = (known after apply)
      + name_prefix      = "AmazonEKS_ExternalSecrets-"
      + path             = "/"
      + policy           = jsonencode(
            {
              + Statement = [
                  + {
                      + Action   = [
                          + "secretsmanager:ListSecrets",
                          + "secretsmanager:BatchGetSecretValue",
                        ]
                      + Effect   = "Allow"
                      + Resource = "*"
                    },
                  + {
                      + Action   = [
                          + "secretsmanager:ListSecretVersionIds",
                          + "secretsmanager:GetSecretValue",
                          + "secretsmanager:GetResourcePolicy",
                          + "secretsmanager:DescribeSecret",
                        ]
                      + Effect   = "Allow"
                      + Resource = "arn:aws:secretsmanager:us-west-2:899805259876:secret:devboard/*"
                    },
                  + {
                      + Action   = "kms:Decrypt"
                      + Effect   = "Allow"
                      + Resource = "arn:aws:kms:*:*:key/*"
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + policy_id        = (known after apply)
      + tags             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all         = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
    }

  # module.external_secrets_pod_identity.aws_iam_role.this[0] will be created
  + resource "aws_iam_role" "this" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = [
                          + "sts:TagSession",
                          + "sts:AssumeRole",
                        ]
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "pods.eks.amazonaws.com"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + force_detach_policies = true
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = (known after apply)
      + name_prefix           = "devboard-external-secrets-"
      + path                  = "/"
      + tags                  = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all              = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.external_secrets_pod_identity.aws_iam_role_policy_attachment.external_secrets[0] will be created
  + resource "aws_iam_role_policy_attachment" "external_secrets" {
      + id         = (known after apply)
      + policy_arn = (known after apply)
      + role       = (known after apply)
    }

  # module.vpc.aws_default_network_acl.this[0] will be created
  + resource "aws_default_network_acl" "this" {
      + arn                    = (known after apply)
      + default_network_acl_id = (known after apply)
      + id                     = (known after apply)
      + owner_id               = (known after apply)
      + region                 = "us-west-2"
      + tags                   = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-default"
          + "Project"   = "devboard"
        }
      + tags_all               = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-default"
          + "Project"   = "devboard"
        }
      + vpc_id                 = (known after apply)

      + egress {
          + action          = "allow"
          + from_port       = 0
          + ipv6_cidr_block = "::/0"
          + protocol        = "-1"
          + rule_no         = 101
          + to_port         = 0
            # (1 unchanged attribute hidden)
        }
      + egress {
          + action          = "allow"
          + cidr_block      = "0.0.0.0/0"
          + from_port       = 0
          + protocol        = "-1"
          + rule_no         = 100
          + to_port         = 0
            # (1 unchanged attribute hidden)
        }

      + ingress {
          + action          = "allow"
          + from_port       = 0
          + ipv6_cidr_block = "::/0"
          + protocol        = "-1"
          + rule_no         = 101
          + to_port         = 0
            # (1 unchanged attribute hidden)
        }
      + ingress {
          + action          = "allow"
          + cidr_block      = "0.0.0.0/0"
          + from_port       = 0
          + protocol        = "-1"
          + rule_no         = 100
          + to_port         = 0
            # (1 unchanged attribute hidden)
        }
    }

  # module.vpc.aws_default_route_table.default[0] will be created
  + resource "aws_default_route_table" "default" {
      + arn                    = (known after apply)
      + default_route_table_id = (known after apply)
      + id                     = (known after apply)
      + owner_id               = (known after apply)
      + region                 = "us-west-2"
      + route                  = (known after apply)
      + tags                   = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-default"
          + "Project"   = "devboard"
        }
      + tags_all               = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-default"
          + "Project"   = "devboard"
        }
      + vpc_id                 = (known after apply)

      + timeouts {
          + create = "5m"
          + update = "5m"
        }
    }

  # module.vpc.aws_default_security_group.this[0] will be created
  + resource "aws_default_security_group" "this" {
      + arn                    = (known after apply)
      + description            = (known after apply)
      + egress                 = (known after apply)
      + id                     = (known after apply)
      + ingress                = (known after apply)
      + name                   = (known after apply)
      + name_prefix            = (known after apply)
      + owner_id               = (known after apply)
      + region                 = "us-west-2"
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-default"
          + "Project"   = "devboard"
        }
      + tags_all               = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-default"
          + "Project"   = "devboard"
        }
      + vpc_id                 = (known after apply)
    }

  # module.vpc.aws_eip.nat[0] will be created
  + resource "aws_eip" "nat" {
      + allocation_id        = (known after apply)
      + arn                  = (known after apply)
      + association_id       = (known after apply)
      + carrier_ip           = (known after apply)
      + customer_owned_ip    = (known after apply)
      + domain               = "vpc"
      + id                   = (known after apply)
      + instance             = (known after apply)
      + ipam_pool_id         = (known after apply)
      + network_border_group = (known after apply)
      + network_interface    = (known after apply)
      + private_dns          = (known after apply)
      + private_ip           = (known after apply)
      + ptr_record           = (known after apply)
      + public_dns           = (known after apply)
      + public_ip            = (known after apply)
      + public_ipv4_pool     = (known after apply)
      + region               = "us-west-2"
      + tags                 = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-us-west-2a"
          + "Project"   = "devboard"
        }
      + tags_all             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-us-west-2a"
          + "Project"   = "devboard"
        }
    }

  # module.vpc.aws_internet_gateway.this[0] will be created
  + resource "aws_internet_gateway" "this" {
      + arn      = (known after apply)
      + id       = (known after apply)
      + owner_id = (known after apply)
      + region   = "us-west-2"
      + tags     = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard"
          + "Project"   = "devboard"
        }
      + tags_all = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard"
          + "Project"   = "devboard"
        }
      + vpc_id   = (known after apply)
    }

  # module.vpc.aws_nat_gateway.this[0] will be created
  + resource "aws_nat_gateway" "this" {
      + allocation_id                      = (known after apply)
      + association_id                     = (known after apply)
      + auto_provision_zones               = (known after apply)
      + auto_scaling_ips                   = (known after apply)
      + availability_mode                  = (known after apply)
      + connectivity_type                  = "public"
      + id                                 = (known after apply)
      + network_interface_id               = (known after apply)
      + private_ip                         = (known after apply)
      + public_ip                          = (known after apply)
      + region                             = "us-west-2"
      + regional_nat_gateway_address       = (known after apply)
      + regional_nat_gateway_auto_mode     = (known after apply)
      + route_table_id                     = (known after apply)
      + secondary_allocation_ids           = (known after apply)
      + secondary_private_ip_address_count = (known after apply)
      + secondary_private_ip_addresses     = (known after apply)
      + subnet_id                          = (known after apply)
      + tags                               = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-us-west-2a"
          + "Project"   = "devboard"
        }
      + tags_all                           = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-us-west-2a"
          + "Project"   = "devboard"
        }
      + vpc_id                             = (known after apply)
    }

  # module.vpc.aws_route.private_nat_gateway[0] will be created
  + resource "aws_route" "private_nat_gateway" {
      + destination_cidr_block = "0.0.0.0/0"
      + id                     = (known after apply)
      + instance_id            = (known after apply)
      + instance_owner_id      = (known after apply)
      + nat_gateway_id         = (known after apply)
      + network_interface_id   = (known after apply)
      + origin                 = (known after apply)
      + region                 = "us-west-2"
      + route_table_id         = (known after apply)
      + state                  = (known after apply)

      + timeouts {
          + create = "5m"
        }
    }

  # module.vpc.aws_route.public_internet_gateway[0] will be created
  + resource "aws_route" "public_internet_gateway" {
      + destination_cidr_block = "0.0.0.0/0"
      + gateway_id             = (known after apply)
      + id                     = (known after apply)
      + instance_id            = (known after apply)
      + instance_owner_id      = (known after apply)
      + network_interface_id   = (known after apply)
      + origin                 = (known after apply)
      + region                 = "us-west-2"
      + route_table_id         = (known after apply)
      + state                  = (known after apply)

      + timeouts {
          + create = "5m"
        }
    }

  # module.vpc.aws_route_table.intra[0] will be created
  + resource "aws_route_table" "intra" {
      + arn              = (known after apply)
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + region           = "us-west-2"
      + route            = (known after apply)
      + tags             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-intra"
          + "Project"   = "devboard"
        }
      + tags_all         = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-intra"
          + "Project"   = "devboard"
        }
      + vpc_id           = (known after apply)
    }

  # module.vpc.aws_route_table.private[0] will be created
  + resource "aws_route_table" "private" {
      + arn              = (known after apply)
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + region           = "us-west-2"
      + route            = (known after apply)
      + tags             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-private"
          + "Project"   = "devboard"
        }
      + tags_all         = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-private"
          + "Project"   = "devboard"
        }
      + vpc_id           = (known after apply)
    }

  # module.vpc.aws_route_table.public[0] will be created
  + resource "aws_route_table" "public" {
      + arn              = (known after apply)
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + region           = "us-west-2"
      + route            = (known after apply)
      + tags             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-public"
          + "Project"   = "devboard"
        }
      + tags_all         = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-public"
          + "Project"   = "devboard"
        }
      + vpc_id           = (known after apply)
    }

  # module.vpc.aws_route_table_association.intra[0] will be created
  + resource "aws_route_table_association" "intra" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.intra[1] will be created
  + resource "aws_route_table_association" "intra" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.intra[2] will be created
  + resource "aws_route_table_association" "intra" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.private[0] will be created
  + resource "aws_route_table_association" "private" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.private[1] will be created
  + resource "aws_route_table_association" "private" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.private[2] will be created
  + resource "aws_route_table_association" "private" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.public[0] will be created
  + resource "aws_route_table_association" "public" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.public[1] will be created
  + resource "aws_route_table_association" "public" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.public[2] will be created
  + resource "aws_route_table_association" "public" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_subnet.intra[0] will be created
  + resource "aws_subnet" "intra" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2a"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.7.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-intra-us-west-2a"
          + "Project"   = "devboard"
        }
      + tags_all                                       = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-intra-us-west-2a"
          + "Project"   = "devboard"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.intra[1] will be created
  + resource "aws_subnet" "intra" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2b"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.8.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-intra-us-west-2b"
          + "Project"   = "devboard"
        }
      + tags_all                                       = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-intra-us-west-2b"
          + "Project"   = "devboard"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.intra[2] will be created
  + resource "aws_subnet" "intra" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2c"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.9.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-intra-us-west-2c"
          + "Project"   = "devboard"
        }
      + tags_all                                       = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-intra-us-west-2c"
          + "Project"   = "devboard"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.private[0] will be created
  + resource "aws_subnet" "private" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2a"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.4.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"                         = "devboard"
          + "ManagedBy"                       = "terraform"
          + "Name"                            = "devboard-private-us-west-2a"
          + "Project"                         = "devboard"
          + "kubernetes.io/role/internal-elb" = "1"
        }
      + tags_all                                       = {
          + "Cluster"                         = "devboard"
          + "ManagedBy"                       = "terraform"
          + "Name"                            = "devboard-private-us-west-2a"
          + "Project"                         = "devboard"
          + "kubernetes.io/role/internal-elb" = "1"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.private[1] will be created
  + resource "aws_subnet" "private" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2b"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.5.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"                         = "devboard"
          + "ManagedBy"                       = "terraform"
          + "Name"                            = "devboard-private-us-west-2b"
          + "Project"                         = "devboard"
          + "kubernetes.io/role/internal-elb" = "1"
        }
      + tags_all                                       = {
          + "Cluster"                         = "devboard"
          + "ManagedBy"                       = "terraform"
          + "Name"                            = "devboard-private-us-west-2b"
          + "Project"                         = "devboard"
          + "kubernetes.io/role/internal-elb" = "1"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.private[2] will be created
  + resource "aws_subnet" "private" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2c"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.6.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"                         = "devboard"
          + "ManagedBy"                       = "terraform"
          + "Name"                            = "devboard-private-us-west-2c"
          + "Project"                         = "devboard"
          + "kubernetes.io/role/internal-elb" = "1"
        }
      + tags_all                                       = {
          + "Cluster"                         = "devboard"
          + "ManagedBy"                       = "terraform"
          + "Name"                            = "devboard-private-us-west-2c"
          + "Project"                         = "devboard"
          + "kubernetes.io/role/internal-elb" = "1"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.public[0] will be created
  + resource "aws_subnet" "public" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2a"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.1.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"                = "devboard"
          + "ManagedBy"              = "terraform"
          + "Name"                   = "devboard-public-us-west-2a"
          + "Project"                = "devboard"
          + "kubernetes.io/role/elb" = "1"
        }
      + tags_all                                       = {
          + "Cluster"                = "devboard"
          + "ManagedBy"              = "terraform"
          + "Name"                   = "devboard-public-us-west-2a"
          + "Project"                = "devboard"
          + "kubernetes.io/role/elb" = "1"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.public[1] will be created
  + resource "aws_subnet" "public" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2b"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.2.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"                = "devboard"
          + "ManagedBy"              = "terraform"
          + "Name"                   = "devboard-public-us-west-2b"
          + "Project"                = "devboard"
          + "kubernetes.io/role/elb" = "1"
        }
      + tags_all                                       = {
          + "Cluster"                = "devboard"
          + "ManagedBy"              = "terraform"
          + "Name"                   = "devboard-public-us-west-2b"
          + "Project"                = "devboard"
          + "kubernetes.io/role/elb" = "1"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.public[2] will be created
  + resource "aws_subnet" "public" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2c"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.3.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"                = "devboard"
          + "ManagedBy"              = "terraform"
          + "Name"                   = "devboard-public-us-west-2c"
          + "Project"                = "devboard"
          + "kubernetes.io/role/elb" = "1"
        }
      + tags_all                                       = {
          + "Cluster"                = "devboard"
          + "ManagedBy"              = "terraform"
          + "Name"                   = "devboard-public-us-west-2c"
          + "Project"                = "devboard"
          + "kubernetes.io/role/elb" = "1"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_vpc.this[0] will be created
  + resource "aws_vpc" "this" {
      + arn                                  = (known after apply)
      + cidr_block                           = "10.0.0.0/16"
      + default_network_acl_id               = (known after apply)
      + default_route_table_id               = (known after apply)
      + default_security_group_id            = (known after apply)
      + dhcp_options_id                      = (known after apply)
      + enable_dns_hostnames                 = true
      + enable_dns_support                   = true
      + enable_network_address_usage_metrics = (known after apply)
      + id                                   = (known after apply)
      + instance_tenancy                     = "default"
      + ipv6_association_id                  = (known after apply)
      + ipv6_cidr_block                      = (known after apply)
      + ipv6_cidr_block_network_border_group = (known after apply)
      + main_route_table_id                  = (known after apply)
      + owner_id                             = (known after apply)
      + region                               = "us-west-2"
      + tags                                 = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard"
          + "Project"   = "devboard"
        }
      + tags_all                             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard"
          + "Project"   = "devboard"
        }
    }

  # module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0] will be created
  + resource "aws_eks_node_group" "this" {
      + ami_type               = "AL2023_x86_64_STANDARD"
      + arn                    = (known after apply)
      + capacity_type          = "ON_DEMAND"
      + cluster_name           = (known after apply)
      + disk_size              = (known after apply)
      + id                     = (known after apply)
      + instance_types         = [
          + "t3.large",
        ]
      + node_group_name        = (known after apply)
      + node_group_name_prefix = "default-"
      + node_role_arn          = (known after apply)
      + region                 = "us-west-2"
      + release_version        = "1.34.9-20260810"
      + resources              = (known after apply)
      + status                 = (known after apply)
      + subnet_ids             = (known after apply)
      + tags                   = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "default"
          + "NodeGroup" = "default"
          + "Project"   = "devboard"
        }
      + tags_all               = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "default"
          + "NodeGroup" = "default"
          + "Project"   = "devboard"
        }
      + version                = "1.34"

      + launch_template {
          + id      = (known after apply)
          + name    = (known after apply)
          + version = (known after apply)
        }

      + node_repair_config (known after apply)

      + scaling_config {
          + desired_size = 3
          + max_size     = 4
          + min_size     = 2
        }

      + update_config {
          + max_unavailable_percentage = 33
        }
    }

  # module.eks.module.eks_managed_node_group["default"].aws_iam_role.this[0] will be created
  + resource "aws_iam_role" "this" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRole"
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "ec2.amazonaws.com"
                        }
                      + Sid       = "EKSNodeAssumeRole"
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + description           = "EKS managed node group IAM role"
      + force_detach_policies = true
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = (known after apply)
      + name_prefix           = "default-eks-node-group-"
      + path                  = "/"
      + tags                  = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "NodeGroup" = "default"
          + "Project"   = "devboard"
        }
      + tags_all              = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "NodeGroup" = "default"
          + "Project"   = "devboard"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.eks.module.eks_managed_node_group["default"].aws_iam_role_policy_attachment.this["AmazonEC2ContainerRegistryReadOnly"] will be created
  + resource "aws_iam_role_policy_attachment" "this" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      + role       = (known after apply)
    }

  # module.eks.module.eks_managed_node_group["default"].aws_iam_role_policy_attachment.this["AmazonEKSWorkerNodePolicy"] will be created
  + resource "aws_iam_role_policy_attachment" "this" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
      + role       = (known after apply)
    }

  # module.eks.module.eks_managed_node_group["default"].aws_iam_role_policy_attachment.this["AmazonEKS_CNI_Policy"] will be created
  + resource "aws_iam_role_policy_attachment" "this" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      + role       = (known after apply)
    }

  # module.eks.module.eks_managed_node_group["default"].aws_launch_template.this[0] will be created
  + resource "aws_launch_template" "this" {
      + arn                    = (known after apply)
      + default_version        = (known after apply)
      + description            = "Custom launch template for default EKS managed node group"
      + id                     = (known after apply)
      + latest_version         = (known after apply)
      + name                   = (known after apply)
      + name_prefix            = "default-"
      + region                 = "us-west-2"
      + tags                   = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "NodeGroup" = "default"
          + "Project"   = "devboard"
        }
      + tags_all               = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "NodeGroup" = "default"
          + "Project"   = "devboard"
        }
      + update_default_version = true
      + vpc_security_group_ids = (known after apply)
        # (2 unchanged attributes hidden)

      + block_device_mappings {
          + device_name = "/dev/xvda"

          + ebs {
              + delete_on_termination      = "true"
              + encrypted                  = "true"
              + iops                       = (known after apply)
              + throughput                 = (known after apply)
              + volume_initialization_rate = (known after apply)
              + volume_size                = 30
              + volume_type                = "gp3"
            }
        }

      + metadata_options {
          + http_endpoint               = "enabled"
          + http_protocol_ipv6          = (known after apply)
          + http_put_response_hop_limit = 1
          + http_tokens                 = "required"
          + instance_metadata_tags      = (known after apply)
        }

      + tag_specifications {
          + resource_type = "instance"
          + tags          = {
              + "Cluster"   = "devboard"
              + "ManagedBy" = "terraform"
              + "Name"      = "default"
              + "NodeGroup" = "default"
              + "Project"   = "devboard"
            }
        }
      + tag_specifications {
          + resource_type = "network-interface"
          + tags          = {
              + "Cluster"   = "devboard"
              + "ManagedBy" = "terraform"
              + "Name"      = "default"
              + "NodeGroup" = "default"
              + "Project"   = "devboard"
            }
        }
      + tag_specifications {
          + resource_type = "volume"
          + tags          = {
              + "Cluster"   = "devboard"
              + "ManagedBy" = "terraform"
              + "Name"      = "default"
              + "NodeGroup" = "default"
              + "Project"   = "devboard"
            }
        }
    }

  # module.eks.module.kms.data.aws_iam_policy_document.this[0] will be read during apply
  # (config refers to values not yet known)
 <= data "aws_iam_policy_document" "this" {
      + id                        = (known after apply)
      + json                      = (known after apply)
      + minified_json             = (known after apply)
      + override_policy_documents = []
      + source_policy_documents   = []

      + statement {
          + actions   = [
              + "kms:*",
            ]
          + resources = [
              + "*",
            ]
          + sid       = "Default"

          + principals {
              + identifiers = [
                  + "arn:aws:iam::899805259876:root",
                ]
              + type        = "AWS"
            }
        }
      + statement {
          + actions   = [
              + "kms:CancelKeyDeletion",
              + "kms:Create*",
              + "kms:Delete*",
              + "kms:Describe*",
              + "kms:Disable*",
              + "kms:Enable*",
              + "kms:Get*",
              + "kms:ImportKeyMaterial",
              + "kms:List*",
              + "kms:Put*",
              + "kms:ReplicateKey",
              + "kms:Revoke*",
              + "kms:ScheduleKeyDeletion",
              + "kms:TagResource",
              + "kms:UntagResource",
              + "kms:Update*",
            ]
          + resources = [
              + "*",
            ]
          + sid       = "KeyAdministration"

          + principals {
              + identifiers = [
                  + "arn:aws:iam::899805259876:role/devboard-bastion-admin-role",
                ]
              + type        = "AWS"
            }
        }
      + statement {
          + actions   = [
              + "kms:Decrypt",
              + "kms:DescribeKey",
              + "kms:Encrypt",
              + "kms:GenerateDataKey*",
              + "kms:ReEncrypt*",
            ]
          + resources = [
              + "*",
            ]
          + sid       = "KeyUsage"

          + principals {
              + identifiers = [
                  + (known after apply),
                ]
              + type        = "AWS"
            }
        }
    }

  # module.eks.module.kms.aws_kms_alias.this["cluster"] will be created
  + resource "aws_kms_alias" "this" {
      + arn            = (known after apply)
      + id             = (known after apply)
      + name           = "alias/eks/devboard"
      + name_prefix    = (known after apply)
      + region         = "us-west-2"
      + target_key_arn = (known after apply)
      + target_key_id  = (known after apply)
    }

  # module.eks.module.kms.aws_kms_key.this[0] will be created
  + resource "aws_kms_key" "this" {
      + arn                                = (known after apply)
      + bypass_policy_lockout_safety_check = false
      + customer_master_key_spec           = "SYMMETRIC_DEFAULT"
      + description                        = "devboard cluster encryption key"
      + enable_key_rotation                = true
      + id                                 = (known after apply)
      + is_enabled                         = true
      + key_id                             = (known after apply)
      + key_usage                          = "ENCRYPT_DECRYPT"
      + multi_region                       = false
      + policy                             = (known after apply)
      + region                             = "us-west-2"
      + rotation_period_in_days            = (known after apply)
      + tags                               = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                           = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
    }

  # module.eks.module.eks_managed_node_group["default"].module.user_data.null_resource.validate_cluster_service_cidr will be created
  + resource "null_resource" "validate_cluster_service_cidr" {
      + id = (known after apply)
    }

Plan: 83 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + argocd_initial_password   = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  + cluster_endpoint          = (known after apply)
  + cluster_name              = "devboard"
  + cluster_version           = "1.34"
  + configure_kubectl         = "aws eks update-kubeconfig --name devboard --region us-west-2"
  + external_secrets_role_arn = (known after apply)
  + oidc_provider_arn         = (known after apply)
  + postgres_secret_arn       = (known after apply)
  + postgres_secret_name      = "devboard/postgres"
  + private_subnets           = [
      + (known after apply),
      + (known after apply),
      + (known after apply),
    ]
  + public_subnets            = [
      + (known after apply),
      + (known after apply),
      + (known after apply),
    ]
  + set_postgres_secret       = <<-EOT
        PGPASS=$(openssl rand -hex 32)
        aws secretsmanager put-secret-value \
          --secret-id devboard/postgres \
          --region us-west-2 \
          --secret-string "$(jq -nc --arg p "$PGPASS" \
              '{username:"devboard", password:$p, dbname:"devboard"}')"
    EOT
  + vpc_id                    = (known after apply)

───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to take exactly these actions if you run "terraform apply" now.
```
<br>Terraform apply output
```hcl
root@ip-20-0-1-248:/opt/devboard/terraform# terraform apply
module.ebs_csi_pod_identity.data.aws_caller_identity.current[0]: Reading...
module.eks.data.aws_caller_identity.current[0]: Reading...
module.ebs_csi_pod_identity.data.aws_partition.current[0]: Reading...
module.eks.data.aws_partition.current[0]: Reading...
module.ebs_csi_pod_identity.data.aws_iam_policy_document.assume[0]: Reading...
data.aws_caller_identity.current: Reading...
module.eks.data.aws_iam_policy_document.assume_role_policy[0]: Reading...
module.ebs_csi_pod_identity.data.aws_iam_policy_document.base[0]: Reading...
module.eks.data.aws_partition.current[0]: Read complete after 0s [id=aws]
module.eks.data.aws_caller_identity.current[0]: Read complete after 0s [id=899805259876]
module.ebs_csi_pod_identity.data.aws_iam_policy_document.assume[0]: Read complete after 0s [id=819195744]
module.ebs_csi_pod_identity.data.aws_caller_identity.current[0]: Read complete after 0s [id=899805259876]
module.eks.data.aws_iam_policy_document.assume_role_policy[0]: Read complete after 0s [id=2830595799]
module.ebs_csi_pod_identity.data.aws_iam_policy_document.base[0]: Read complete after 0s [id=1132004489]
module.ebs_csi_pod_identity.data.aws_partition.current[0]: Read complete after 0s [id=aws]
data.aws_caller_identity.current: Read complete after 0s [id=899805259876]
module.external_secrets_pod_identity.data.aws_iam_policy_document.base[0]: Reading...
data.aws_availability_zones.available: Reading...
module.eks.module.kms.data.aws_caller_identity.current[0]: Reading...
module.eks.module.eks_managed_node_group["default"].data.aws_iam_policy_document.assume_role_policy[0]: Reading...
module.external_secrets_pod_identity.data.aws_region.current[0]: Reading...
module.external_secrets_pod_identity.data.aws_iam_policy_document.assume[0]: Reading...
module.external_secrets_pod_identity.data.aws_partition.current[0]: Reading...
module.external_secrets_pod_identity.data.aws_region.current[0]: Read complete after 0s [id=us-west-2]
module.ebs_csi_pod_identity.data.aws_region.current[0]: Reading...
module.external_secrets_pod_identity.data.aws_partition.current[0]: Read complete after 0s [id=aws]
module.external_secrets_pod_identity.data.aws_iam_policy_document.assume[0]: Read complete after 0s [id=819195744]
module.ebs_csi_pod_identity.data.aws_region.current[0]: Read complete after 0s [id=us-west-2]
module.eks.module.eks_managed_node_group["default"].data.aws_iam_policy_document.assume_role_policy[0]: Read complete after 0s [id=2560088296]
module.external_secrets_pod_identity.data.aws_iam_policy_document.base[0]: Read complete after 0s [id=1132004489]
module.eks.module.kms.data.aws_caller_identity.current[0]: Read complete after 0s [id=899805259876]
module.eks.module.kms.data.aws_partition.current[0]: Reading...
module.external_secrets_pod_identity.data.aws_caller_identity.current[0]: Reading...
module.eks.data.aws_iam_session_context.current[0]: Reading...
module.eks.module.kms.data.aws_partition.current[0]: Read complete after 0s [id=aws]
module.external_secrets_pod_identity.data.aws_caller_identity.current[0]: Read complete after 0s [id=899805259876]
module.ebs_csi_pod_identity.data.aws_iam_policy_document.ebs_csi[0]: Reading...
data.aws_availability_zones.available: Read complete after 0s [id=us-west-2]
module.external_secrets_pod_identity.data.aws_iam_policy_document.external_secrets[0]: Reading...
module.ebs_csi_pod_identity.data.aws_iam_policy_document.ebs_csi[0]: Read complete after 0s [id=3979039874]
module.external_secrets_pod_identity.data.aws_iam_policy_document.external_secrets[0]: Read complete after 0s [id=3999450956]
module.eks.data.aws_iam_session_context.current[0]: Read complete after 0s [id=arn:aws:sts::899805259876:assumed-role/devboard-bastion-admin-role/i-06070d0e6189873bc]
module.eks.module.eks_managed_node_group["default"].data.aws_ssm_parameter.ami[0]: Reading...
module.eks.module.eks_managed_node_group["default"].data.aws_ssm_parameter.ami[0]: Read complete after 0s [id=/aws/service/eks/optimized-ami/1.34/amazon-linux-2023/x86_64/standard/recommended/release_version]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create
 <= read (data resources)

Terraform will perform the following actions:

  # aws_secretsmanager_secret.postgres will be created
  + resource "aws_secretsmanager_secret" "postgres" {
      + arn                            = (known after apply)
      + description                    = "DevBoard in-cluster Postgres credentials. Value set out of band; see gitops/06-secrets-with-secrets-manager.md."
      + force_overwrite_replica_secret = false
      + id                             = (known after apply)
      + name                           = "devboard/postgres"
      + name_prefix                    = (known after apply)
      + policy                         = (known after apply)
      + recovery_window_in_days        = 0
      + region                         = "us-west-2"
      + tags                           = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                       = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }

      + replica (known after apply)
    }

  # helm_release.argocd[0] will be created
  + resource "helm_release" "argocd" {
      + atomic                     = false
      + chart                      = "argo-cd"
      + cleanup_on_fail            = false
      + create_namespace           = true
      + dependency_update          = false
      + disable_crd_hooks          = false
      + disable_openapi_validation = false
      + disable_webhooks           = false
      + force_update               = false
      + id                         = (known after apply)
      + lint                       = false
      + max_history                = 0
      + metadata                   = (known after apply)
      + name                       = "argocd"
      + namespace                  = "argocd"
      + pass_credentials           = false
      + recreate_pods              = false
      + render_subchart_notes      = true
      + replace                    = false
      + repository                 = "https://argoproj.github.io/argo-helm"
      + reset_values               = false
      + reuse_values               = false
      + set_wo                     = (write-only attribute)
      + skip_crds                  = false
      + status                     = "deployed"
      + take_ownership             = false
      + timeout                    = 900
      + upgrade_install            = false
      + values                     = [
          + <<-EOT
                "configs":
                  "params":
                    "server.insecure": true
                "server":
                  "service":
                    "type": "ClusterIP"
            EOT,
        ]
      + verify                     = false
      + version                    = "10.3.0"
      + wait                       = true
      + wait_for_jobs              = false
    }

  # kubernetes_storage_class_v1.gp3 will be created
  + resource "kubernetes_storage_class_v1" "gp3" {
      + allow_volume_expansion = true
      + id                     = (known after apply)
      + parameters             = {
          + "encrypted" = "true"
          + "fsType"    = "ext4"
          + "type"      = "gp3"
        }
      + reclaim_policy         = "Delete"
      + storage_provisioner    = "ebs.csi.aws.com"
      + volume_binding_mode    = "WaitForFirstConsumer"

      + metadata {
          + annotations      = {
              + "storageclass.kubernetes.io/is-default-class" = "true"
            }
          + generation       = (known after apply)
          + name             = "gp3"
          + resource_version = (known after apply)
          + uid              = (known after apply)
        }
    }

  # module.ebs_csi_pod_identity.aws_eks_pod_identity_association.this["this"] will be created
  + resource "aws_eks_pod_identity_association" "this" {
      + association_arn      = (known after apply)
      + association_id       = (known after apply)
      + cluster_name         = "devboard"
      + disable_session_tags = false
      + external_id          = (known after apply)
      + id                   = (known after apply)
      + namespace            = "kube-system"
      + region               = "us-west-2"
      + role_arn             = (known after apply)
      + service_account      = "ebs-csi-controller-sa"
      + tags                 = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
    }

  # module.ebs_csi_pod_identity.aws_iam_policy.ebs_csi[0] will be created
  + resource "aws_iam_policy" "ebs_csi" {
      + arn              = (known after apply)
      + attachment_count = (known after apply)
      + description      = "Permissions to manage EBS volumes via the container storage interface (CSI) driver"
      + id               = (known after apply)
      + name             = (known after apply)
      + name_prefix      = "AmazonEKS_EBS_CSI-"
      + path             = "/"
      + policy           = jsonencode(
            {
              + Statement = [
                  + {
                      + Action   = [
                          + "ec2:ModifyVolume",
                          + "ec2:EnableFastSnapshotRestores",
                          + "ec2:DetachVolume",
                          + "ec2:DescribeVolumesModifications",
                          + "ec2:DescribeVolumes",
                          + "ec2:DescribeVolumeStatus",
                          + "ec2:DescribeTags",
                          + "ec2:DescribeSnapshots",
                          + "ec2:DescribeInstances",
                          + "ec2:DescribeInstanceTypes",
                          + "ec2:DescribeAvailabilityZones",
                          + "ec2:CreateSnapshot",
                          + "ec2:AttachVolume",
                        ]
                      + Effect   = "Allow"
                      + Resource = "*"
                    },
                  + {
                      + Action   = "ec2:CopyVolumes"
                      + Effect   = "Allow"
                      + Resource = "arn:aws:ec2:*:*:volume/vol-*"
                    },
                  + {
                      + Action    = "ec2:CreateTags"
                      + Condition = {
                          + StringEquals = {
                              + "ec2:CreateAction" = [
                                  + "CreateVolume",
                                  + "CreateSnapshot",
                                  + "CopyVolumes",
                                ]
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = [
                          + "arn:aws:ec2:*:*:volume/*",
                          + "arn:aws:ec2:*:*:snapshot/*",
                        ]
                    },
                  + {
                      + Action   = "ec2:DeleteTags"
                      + Effect   = "Allow"
                      + Resource = [
                          + "arn:aws:ec2:*:*:volume/*",
                          + "arn:aws:ec2:*:*:snapshot/*",
                        ]
                    },
                  + {
                      + Action    = [
                          + "ec2:CreateVolume",
                          + "ec2:CopyVolumes",
                        ]
                      + Condition = {
                          + StringLike = {
                              + "aws:RequestTag/ebs.csi.aws.com/cluster" = "true"
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = "arn:aws:ec2:*:*:volume/*"
                    },
                  + {
                      + Action    = [
                          + "ec2:CreateVolume",
                          + "ec2:CopyVolumes",
                        ]
                      + Condition = {
                          + StringLike = {
                              + "aws:RequestTag/CSIVolumeName" = "*"
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = "arn:aws:ec2:*:*:volume/*"
                    },
                  + {
                      + Action   = "ec2:CreateVolume"
                      + Effect   = "Allow"
                      + Resource = "arn:aws:ec2:*:*:snapshot/*"
                    },
                  + {
                      + Action    = "ec2:DeleteVolume"
                      + Condition = {
                          + StringLike = {
                              + "ec2:ResourceTag/ebs.csi.aws.com/cluster" = "true"
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = "*"
                    },
                  + {
                      + Action    = "ec2:DeleteVolume"
                      + Condition = {
                          + StringLike = {
                              + "ec2:ResourceTag/CSIVolumeName" = "*"
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = "*"
                    },
                  + {
                      + Action    = "ec2:DeleteVolume"
                      + Condition = {
                          + StringLike = {
                              + "ec2:ResourceTag/kubernetes.io/created-for/pvc/name" = "*"
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = "*"
                    },
                  + {
                      + Action    = [
                          + "ec2:LockSnapshot",
                          + "ec2:DeleteSnapshot",
                        ]
                      + Condition = {
                          + StringLike = {
                              + "ec2:ResourceTag/CSIVolumeSnapshotName" = "*"
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = "*"
                    },
                  + {
                      + Action    = [
                          + "ec2:LockSnapshot",
                          + "ec2:DeleteSnapshot",
                        ]
                      + Condition = {
                          + StringLike = {
                              + "ec2:ResourceTag/ebs.csi.aws.com/cluster" = "true"
                            }
                        }
                      + Effect    = "Allow"
                      + Resource  = "*"
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + policy_id        = (known after apply)
      + tags             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all         = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
    }

  # module.ebs_csi_pod_identity.aws_iam_role.this[0] will be created
  + resource "aws_iam_role" "this" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = [
                          + "sts:TagSession",
                          + "sts:AssumeRole",
                        ]
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "pods.eks.amazonaws.com"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + force_detach_policies = true
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = (known after apply)
      + name_prefix           = "devboard-ebs-csi-"
      + path                  = "/"
      + tags                  = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all              = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.ebs_csi_pod_identity.aws_iam_role_policy_attachment.ebs_csi[0] will be created
  + resource "aws_iam_role_policy_attachment" "ebs_csi" {
      + id         = (known after apply)
      + policy_arn = (known after apply)
      + role       = (known after apply)
    }

  # module.eks.data.aws_eks_addon_version.this["aws-ebs-csi-driver"] will be read during apply
  # (depends on a resource or a module with changes pending)
 <= data "aws_eks_addon_version" "this" {
      + addon_name         = "aws-ebs-csi-driver"
      + id                 = (known after apply)
      + kubernetes_version = "1.34"
      + most_recent        = true
      + region             = (known after apply)
      + version            = (known after apply)
    }

  # module.eks.data.aws_eks_addon_version.this["coredns"] will be read during apply
  # (depends on a resource or a module with changes pending)
 <= data "aws_eks_addon_version" "this" {
      + addon_name         = "coredns"
      + id                 = (known after apply)
      + kubernetes_version = "1.34"
      + most_recent        = true
      + region             = (known after apply)
      + version            = (known after apply)
    }

  # module.eks.data.aws_eks_addon_version.this["eks-pod-identity-agent"] will be read during apply
  # (depends on a resource or a module with changes pending)
 <= data "aws_eks_addon_version" "this" {
      + addon_name         = "eks-pod-identity-agent"
      + id                 = (known after apply)
      + kubernetes_version = "1.34"
      + most_recent        = true
      + region             = (known after apply)
      + version            = (known after apply)
    }

  # module.eks.data.aws_eks_addon_version.this["kube-proxy"] will be read during apply
  # (depends on a resource or a module with changes pending)
 <= data "aws_eks_addon_version" "this" {
      + addon_name         = "kube-proxy"
      + id                 = (known after apply)
      + kubernetes_version = "1.34"
      + most_recent        = true
      + region             = (known after apply)
      + version            = (known after apply)
    }

  # module.eks.data.aws_eks_addon_version.this["metrics-server"] will be read during apply
  # (depends on a resource or a module with changes pending)
 <= data "aws_eks_addon_version" "this" {
      + addon_name         = "metrics-server"
      + id                 = (known after apply)
      + kubernetes_version = "1.34"
      + most_recent        = true
      + region             = (known after apply)
      + version            = (known after apply)
    }

  # module.eks.data.aws_eks_addon_version.this["vpc-cni"] will be read during apply
  # (depends on a resource or a module with changes pending)
 <= data "aws_eks_addon_version" "this" {
      + addon_name         = "vpc-cni"
      + id                 = (known after apply)
      + kubernetes_version = "1.34"
      + most_recent        = true
      + region             = (known after apply)
      + version            = (known after apply)
    }

  # module.eks.data.tls_certificate.this[0] will be read during apply
  # (config refers to values not yet known)
 <= data "tls_certificate" "this" {
      + certificates = (known after apply)
      + id           = (known after apply)
      + url          = (known after apply)
    }

  # module.eks.aws_cloudwatch_log_group.this[0] will be created
  + resource "aws_cloudwatch_log_group" "this" {
      + arn                         = (known after apply)
      + deletion_protection_enabled = (known after apply)
      + id                          = (known after apply)
      + log_group_class             = (known after apply)
      + name                        = "/aws/eks/devboard/cluster"
      + name_prefix                 = (known after apply)
      + region                      = "us-west-2"
      + retention_in_days           = 7
      + skip_destroy                = false
      + tags                        = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "/aws/eks/devboard/cluster"
          + "Project"   = "devboard"
        }
      + tags_all                    = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "/aws/eks/devboard/cluster"
          + "Project"   = "devboard"
        }
    }

  # module.eks.aws_ec2_tag.cluster_primary_security_group["Cluster"] will be created
  + resource "aws_ec2_tag" "cluster_primary_security_group" {
      + id          = (known after apply)
      + key         = "Cluster"
      + region      = "us-west-2"
      + resource_id = (known after apply)
      + value       = "devboard"
    }

  # module.eks.aws_ec2_tag.cluster_primary_security_group["ManagedBy"] will be created
  + resource "aws_ec2_tag" "cluster_primary_security_group" {
      + id          = (known after apply)
      + key         = "ManagedBy"
      + region      = "us-west-2"
      + resource_id = (known after apply)
      + value       = "terraform"
    }

  # module.eks.aws_ec2_tag.cluster_primary_security_group["Project"] will be created
  + resource "aws_ec2_tag" "cluster_primary_security_group" {
      + id          = (known after apply)
      + key         = "Project"
      + region      = "us-west-2"
      + resource_id = (known after apply)
      + value       = "devboard"
    }

  # module.eks.aws_eks_access_entry.this["cluster_creator"] will be created
  + resource "aws_eks_access_entry" "this" {
      + access_entry_arn  = (known after apply)
      + cluster_name      = (known after apply)
      + created_at        = (known after apply)
      + id                = (known after apply)
      + kubernetes_groups = (known after apply)
      + modified_at       = (known after apply)
      + principal_arn     = "arn:aws:iam::899805259876:role/devboard-bastion-admin-role"
      + region            = "us-west-2"
      + tags              = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all          = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + type              = "STANDARD"
      + user_name         = (known after apply)
    }

  # module.eks.aws_eks_access_policy_association.this["cluster_creator_admin"] will be created
  + resource "aws_eks_access_policy_association" "this" {
      + associated_at = (known after apply)
      + cluster_name  = (known after apply)
      + id            = (known after apply)
      + modified_at   = (known after apply)
      + policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      + principal_arn = "arn:aws:iam::899805259876:role/devboard-bastion-admin-role"
      + region        = "us-west-2"

      + access_scope {
          + type = "cluster"
        }
    }

  # module.eks.aws_eks_addon.before_compute["eks-pod-identity-agent"] will be created
  + resource "aws_eks_addon" "before_compute" {
      + addon_name                  = "eks-pod-identity-agent"
      + addon_version               = (known after apply)
      + arn                         = (known after apply)
      + cluster_name                = (known after apply)
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + region                      = "us-west-2"
      + resolve_conflicts_on_create = "NONE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + tags                        = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                    = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }

      + namespace_config (known after apply)

      + timeouts {}
    }

  # module.eks.aws_eks_addon.before_compute["vpc-cni"] will be created
  + resource "aws_eks_addon" "before_compute" {
      + addon_name                  = "vpc-cni"
      + addon_version               = (known after apply)
      + arn                         = (known after apply)
      + cluster_name                = (known after apply)
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + region                      = "us-west-2"
      + resolve_conflicts_on_create = "NONE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + tags                        = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                    = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }

      + namespace_config (known after apply)

      + timeouts {}
    }

  # module.eks.aws_eks_addon.this["aws-ebs-csi-driver"] will be created
  + resource "aws_eks_addon" "this" {
      + addon_name                  = "aws-ebs-csi-driver"
      + addon_version               = (known after apply)
      + arn                         = (known after apply)
      + cluster_name                = (known after apply)
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + region                      = "us-west-2"
      + resolve_conflicts_on_create = "NONE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + tags                        = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                    = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }

      + namespace_config (known after apply)

      + timeouts {}
    }

  # module.eks.aws_eks_addon.this["coredns"] will be created
  + resource "aws_eks_addon" "this" {
      + addon_name                  = "coredns"
      + addon_version               = (known after apply)
      + arn                         = (known after apply)
      + cluster_name                = (known after apply)
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + region                      = "us-west-2"
      + resolve_conflicts_on_create = "NONE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + tags                        = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                    = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }

      + namespace_config (known after apply)

      + timeouts {}
    }

  # module.eks.aws_eks_addon.this["kube-proxy"] will be created
  + resource "aws_eks_addon" "this" {
      + addon_name                  = "kube-proxy"
      + addon_version               = (known after apply)
      + arn                         = (known after apply)
      + cluster_name                = (known after apply)
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + region                      = "us-west-2"
      + resolve_conflicts_on_create = "NONE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + tags                        = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                    = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }

      + namespace_config (known after apply)

      + timeouts {}
    }

  # module.eks.aws_eks_addon.this["metrics-server"] will be created
  + resource "aws_eks_addon" "this" {
      + addon_name                  = "metrics-server"
      + addon_version               = (known after apply)
      + arn                         = (known after apply)
      + cluster_name                = (known after apply)
      + configuration_values        = (known after apply)
      + created_at                  = (known after apply)
      + id                          = (known after apply)
      + modified_at                 = (known after apply)
      + preserve                    = true
      + region                      = "us-west-2"
      + resolve_conflicts_on_create = "NONE"
      + resolve_conflicts_on_update = "OVERWRITE"
      + tags                        = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                    = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }

      + namespace_config (known after apply)

      + timeouts {}
    }

  # module.eks.aws_eks_cluster.this[0] will be created
  + resource "aws_eks_cluster" "this" {
      + arn                           = (known after apply)
      + bootstrap_self_managed_addons = false
      + certificate_authority         = (known after apply)
      + cluster_id                    = (known after apply)
      + created_at                    = (known after apply)
      + deletion_protection           = (known after apply)
      + enabled_cluster_log_types     = [
          + "audit",
          + "authenticator",
        ]
      + endpoint                      = (known after apply)
      + id                            = (known after apply)
      + identity                      = (known after apply)
      + name                          = "devboard"
      + platform_version              = (known after apply)
      + region                        = "us-west-2"
      + role_arn                      = (known after apply)
      + status                        = (known after apply)
      + tags                          = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                      = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + version                       = "1.34"

      + access_config {
          + authentication_mode                         = "API_AND_CONFIG_MAP"
          + bootstrap_cluster_creator_admin_permissions = false
        }

      + compute_config (known after apply)

      + control_plane_scaling_config (known after apply)

      + encryption_config {
          + resources = [
              + "secrets",
            ]

          + provider {
              + key_arn = (known after apply)
            }
        }

      + kube_api_server_config (known after apply)

      + kube_controller_manager_config (known after apply)

      + kube_scheduler_config (known after apply)

      + kubernetes_network_config {
          + ip_family         = "ipv4"
          + service_ipv4_cidr = (known after apply)
          + service_ipv6_cidr = (known after apply)

          + elastic_load_balancing (known after apply)
        }

      + storage_config (known after apply)

      + upgrade_policy (known after apply)

      + vpc_config {
          + cluster_security_group_id = (known after apply)
          + control_plane_egress_mode = (known after apply)
          + endpoint_private_access   = true
          + endpoint_public_access    = true
          + public_access_cidrs       = [
              + "0.0.0.0/0",
            ]
          + security_group_ids        = (known after apply)
          + subnet_ids                = (known after apply)
          + vpc_id                    = (known after apply)
        }
    }

  # module.eks.aws_iam_openid_connect_provider.oidc_provider[0] will be created
  + resource "aws_iam_openid_connect_provider" "oidc_provider" {
      + arn             = (known after apply)
      + client_id_list  = [
          + "sts.amazonaws.com",
        ]
      + id              = (known after apply)
      + tags            = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-eks-irsa"
          + "Project"   = "devboard"
        }
      + tags_all        = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-eks-irsa"
          + "Project"   = "devboard"
        }
      + thumbprint_list = (known after apply)
      + url             = (known after apply)
    }

  # module.eks.aws_iam_policy.cluster_encryption[0] will be created
  + resource "aws_iam_policy" "cluster_encryption" {
      + arn              = (known after apply)
      + attachment_count = (known after apply)
      + description      = "Cluster encryption policy to allow cluster role to utilize CMK provided"
      + id               = (known after apply)
      + name             = (known after apply)
      + name_prefix      = "devboard-cluster-ClusterEncryption"
      + path             = "/"
      + policy           = (known after apply)
      + policy_id        = (known after apply)
      + tags             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all         = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
    }

  # module.eks.aws_iam_role.this[0] will be created
  + resource "aws_iam_role" "this" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = [
                          + "sts:TagSession",
                          + "sts:AssumeRole",
                        ]
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "eks.amazonaws.com"
                        }
                      + Sid       = "EKSClusterAssumeRole"
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + force_detach_policies = true
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = (known after apply)
      + name_prefix           = "devboard-cluster-"
      + path                  = "/"
      + tags                  = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all              = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.eks.aws_iam_role_policy_attachment.cluster_encryption[0] will be created
  + resource "aws_iam_role_policy_attachment" "cluster_encryption" {
      + id         = (known after apply)
      + policy_arn = (known after apply)
      + role       = (known after apply)
    }

  # module.eks.aws_iam_role_policy_attachment.this["AmazonEKSClusterPolicy"] will be created
  + resource "aws_iam_role_policy_attachment" "this" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
      + role       = (known after apply)
    }

  # module.eks.aws_security_group.cluster[0] will be created
  + resource "aws_security_group" "cluster" {
      + arn                    = (known after apply)
      + description            = "EKS cluster security group"
      + egress                 = (known after apply)
      + id                     = (known after apply)
      + ingress                = (known after apply)
      + name                   = (known after apply)
      + name_prefix            = "devboard-cluster-"
      + owner_id               = (known after apply)
      + region                 = "us-west-2"
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-cluster"
          + "Project"   = "devboard"
        }
      + tags_all               = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-cluster"
          + "Project"   = "devboard"
        }
      + vpc_id                 = (known after apply)
    }

  # module.eks.aws_security_group.node[0] will be created
  + resource "aws_security_group" "node" {
      + arn                    = (known after apply)
      + description            = "EKS node shared security group"
      + egress                 = (known after apply)
      + id                     = (known after apply)
      + ingress                = (known after apply)
      + name                   = (known after apply)
      + name_prefix            = "devboard-node-"
      + owner_id               = (known after apply)
      + region                 = "us-west-2"
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Cluster"                        = "devboard"
          + "ManagedBy"                      = "terraform"
          + "Name"                           = "devboard-node"
          + "Project"                        = "devboard"
          + "kubernetes.io/cluster/devboard" = "owned"
        }
      + tags_all               = {
          + "Cluster"                        = "devboard"
          + "ManagedBy"                      = "terraform"
          + "Name"                           = "devboard-node"
          + "Project"                        = "devboard"
          + "kubernetes.io/cluster/devboard" = "owned"
        }
      + vpc_id                 = (known after apply)
    }

  # module.eks.aws_security_group_rule.cluster["ingress_nodes_443"] will be created
  + resource "aws_security_group_rule" "cluster" {
      + description              = "Node groups to cluster API"
      + from_port                = 443
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 443
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["egress_all"] will be created
  + resource "aws_security_group_rule" "node" {
      + cidr_blocks              = [
          + "0.0.0.0/0",
        ]
      + description              = "Allow all egress"
      + from_port                = 0
      + id                       = (known after apply)
      + protocol                 = "-1"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 0
      + type                     = "egress"
    }

  # module.eks.aws_security_group_rule.node["ingress_cluster_10251_webhook"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Cluster API to node 10251/tcp webhook"
      + from_port                = 10251
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 10251
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_cluster_443"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Cluster API to node groups"
      + from_port                = 443
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 443
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_cluster_4443_webhook"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Cluster API to node 4443/tcp webhook"
      + from_port                = 4443
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 4443
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_cluster_6443_webhook"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Cluster API to node 6443/tcp webhook"
      + from_port                = 6443
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 6443
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_cluster_8443_webhook"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Cluster API to node 8443/tcp webhook"
      + from_port                = 8443
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 8443
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_cluster_9443_webhook"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Cluster API to node 9443/tcp webhook"
      + from_port                = 9443
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 9443
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_cluster_kubelet"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Cluster API to node kubelets"
      + from_port                = 10250
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = false
      + source_security_group_id = (known after apply)
      + to_port                  = 10250
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_nodes_ephemeral"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Node to node ingress on ephemeral ports"
      + from_port                = 1025
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = true
      + source_security_group_id = (known after apply)
      + to_port                  = 65535
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_self_coredns_tcp"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Node to node CoreDNS"
      + from_port                = 53
      + id                       = (known after apply)
      + protocol                 = "tcp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = true
      + source_security_group_id = (known after apply)
      + to_port                  = 53
      + type                     = "ingress"
    }

  # module.eks.aws_security_group_rule.node["ingress_self_coredns_udp"] will be created
  + resource "aws_security_group_rule" "node" {
      + description              = "Node to node CoreDNS UDP"
      + from_port                = 53
      + id                       = (known after apply)
      + protocol                 = "udp"
      + region                   = "us-west-2"
      + security_group_id        = (known after apply)
      + security_group_rule_id   = (known after apply)
      + self                     = true
      + source_security_group_id = (known after apply)
      + to_port                  = 53
      + type                     = "ingress"
    }

  # module.eks.time_sleep.this[0] will be created
  + resource "time_sleep" "this" {
      + create_duration = "30s"
      + id              = (known after apply)
      + triggers        = {
          + "certificate_authority_data" = (known after apply)
          + "endpoint"                   = (known after apply)
          + "kubernetes_version"         = "1.34"
          + "name"                       = (known after apply)
          + "service_cidr"               = (known after apply)
        }
    }

  # module.external_secrets_pod_identity.aws_eks_pod_identity_association.this["this"] will be created
  + resource "aws_eks_pod_identity_association" "this" {
      + association_arn      = (known after apply)
      + association_id       = (known after apply)
      + cluster_name         = "devboard"
      + disable_session_tags = false
      + external_id          = (known after apply)
      + id                   = (known after apply)
      + namespace            = "external-secrets"
      + region               = "us-west-2"
      + role_arn             = (known after apply)
      + service_account      = "external-secrets"
      + tags                 = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
    }

  # module.external_secrets_pod_identity.aws_iam_policy.external_secrets[0] will be created
  + resource "aws_iam_policy" "external_secrets" {
      + arn              = (known after apply)
      + attachment_count = (known after apply)
      + description      = "Permissions for External Secrets"
      + id               = (known after apply)
      + name             = (known after apply)
      + name_prefix      = "AmazonEKS_ExternalSecrets-"
      + path             = "/"
      + policy           = jsonencode(
            {
              + Statement = [
                  + {
                      + Action   = [
                          + "secretsmanager:ListSecrets",
                          + "secretsmanager:BatchGetSecretValue",
                        ]
                      + Effect   = "Allow"
                      + Resource = "*"
                    },
                  + {
                      + Action   = [
                          + "secretsmanager:ListSecretVersionIds",
                          + "secretsmanager:GetSecretValue",
                          + "secretsmanager:GetResourcePolicy",
                          + "secretsmanager:DescribeSecret",
                        ]
                      + Effect   = "Allow"
                      + Resource = "arn:aws:secretsmanager:us-west-2:899805259876:secret:devboard/*"
                    },
                  + {
                      + Action   = "kms:Decrypt"
                      + Effect   = "Allow"
                      + Resource = "arn:aws:kms:*:*:key/*"
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + policy_id        = (known after apply)
      + tags             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all         = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
    }

  # module.external_secrets_pod_identity.aws_iam_role.this[0] will be created
  + resource "aws_iam_role" "this" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = [
                          + "sts:TagSession",
                          + "sts:AssumeRole",
                        ]
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "pods.eks.amazonaws.com"
                        }
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + force_detach_policies = true
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = (known after apply)
      + name_prefix           = "devboard-external-secrets-"
      + path                  = "/"
      + tags                  = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all              = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.external_secrets_pod_identity.aws_iam_role_policy_attachment.external_secrets[0] will be created
  + resource "aws_iam_role_policy_attachment" "external_secrets" {
      + id         = (known after apply)
      + policy_arn = (known after apply)
      + role       = (known after apply)
    }

  # module.vpc.aws_default_network_acl.this[0] will be created
  + resource "aws_default_network_acl" "this" {
      + arn                    = (known after apply)
      + default_network_acl_id = (known after apply)
      + id                     = (known after apply)
      + owner_id               = (known after apply)
      + region                 = "us-west-2"
      + tags                   = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-default"
          + "Project"   = "devboard"
        }
      + tags_all               = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-default"
          + "Project"   = "devboard"
        }
      + vpc_id                 = (known after apply)

      + egress {
          + action          = "allow"
          + from_port       = 0
          + ipv6_cidr_block = "::/0"
          + protocol        = "-1"
          + rule_no         = 101
          + to_port         = 0
            # (1 unchanged attribute hidden)
        }
      + egress {
          + action          = "allow"
          + cidr_block      = "0.0.0.0/0"
          + from_port       = 0
          + protocol        = "-1"
          + rule_no         = 100
          + to_port         = 0
            # (1 unchanged attribute hidden)
        }

      + ingress {
          + action          = "allow"
          + from_port       = 0
          + ipv6_cidr_block = "::/0"
          + protocol        = "-1"
          + rule_no         = 101
          + to_port         = 0
            # (1 unchanged attribute hidden)
        }
      + ingress {
          + action          = "allow"
          + cidr_block      = "0.0.0.0/0"
          + from_port       = 0
          + protocol        = "-1"
          + rule_no         = 100
          + to_port         = 0
            # (1 unchanged attribute hidden)
        }
    }

  # module.vpc.aws_default_route_table.default[0] will be created
  + resource "aws_default_route_table" "default" {
      + arn                    = (known after apply)
      + default_route_table_id = (known after apply)
      + id                     = (known after apply)
      + owner_id               = (known after apply)
      + region                 = "us-west-2"
      + route                  = (known after apply)
      + tags                   = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-default"
          + "Project"   = "devboard"
        }
      + tags_all               = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-default"
          + "Project"   = "devboard"
        }
      + vpc_id                 = (known after apply)

      + timeouts {
          + create = "5m"
          + update = "5m"
        }
    }

  # module.vpc.aws_default_security_group.this[0] will be created
  + resource "aws_default_security_group" "this" {
      + arn                    = (known after apply)
      + description            = (known after apply)
      + egress                 = (known after apply)
      + id                     = (known after apply)
      + ingress                = (known after apply)
      + name                   = (known after apply)
      + name_prefix            = (known after apply)
      + owner_id               = (known after apply)
      + region                 = "us-west-2"
      + revoke_rules_on_delete = false
      + tags                   = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-default"
          + "Project"   = "devboard"
        }
      + tags_all               = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-default"
          + "Project"   = "devboard"
        }
      + vpc_id                 = (known after apply)
    }

  # module.vpc.aws_eip.nat[0] will be created
  + resource "aws_eip" "nat" {
      + allocation_id        = (known after apply)
      + arn                  = (known after apply)
      + association_id       = (known after apply)
      + carrier_ip           = (known after apply)
      + customer_owned_ip    = (known after apply)
      + domain               = "vpc"
      + id                   = (known after apply)
      + instance             = (known after apply)
      + ipam_pool_id         = (known after apply)
      + network_border_group = (known after apply)
      + network_interface    = (known after apply)
      + private_dns          = (known after apply)
      + private_ip           = (known after apply)
      + ptr_record           = (known after apply)
      + public_dns           = (known after apply)
      + public_ip            = (known after apply)
      + public_ipv4_pool     = (known after apply)
      + region               = "us-west-2"
      + tags                 = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-us-west-2a"
          + "Project"   = "devboard"
        }
      + tags_all             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-us-west-2a"
          + "Project"   = "devboard"
        }
    }

  # module.vpc.aws_internet_gateway.this[0] will be created
  + resource "aws_internet_gateway" "this" {
      + arn      = (known after apply)
      + id       = (known after apply)
      + owner_id = (known after apply)
      + region   = "us-west-2"
      + tags     = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard"
          + "Project"   = "devboard"
        }
      + tags_all = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard"
          + "Project"   = "devboard"
        }
      + vpc_id   = (known after apply)
    }

  # module.vpc.aws_nat_gateway.this[0] will be created
  + resource "aws_nat_gateway" "this" {
      + allocation_id                      = (known after apply)
      + association_id                     = (known after apply)
      + auto_provision_zones               = (known after apply)
      + auto_scaling_ips                   = (known after apply)
      + availability_mode                  = (known after apply)
      + connectivity_type                  = "public"
      + id                                 = (known after apply)
      + network_interface_id               = (known after apply)
      + private_ip                         = (known after apply)
      + public_ip                          = (known after apply)
      + region                             = "us-west-2"
      + regional_nat_gateway_address       = (known after apply)
      + regional_nat_gateway_auto_mode     = (known after apply)
      + route_table_id                     = (known after apply)
      + secondary_allocation_ids           = (known after apply)
      + secondary_private_ip_address_count = (known after apply)
      + secondary_private_ip_addresses     = (known after apply)
      + subnet_id                          = (known after apply)
      + tags                               = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-us-west-2a"
          + "Project"   = "devboard"
        }
      + tags_all                           = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-us-west-2a"
          + "Project"   = "devboard"
        }
      + vpc_id                             = (known after apply)
    }

  # module.vpc.aws_route.private_nat_gateway[0] will be created
  + resource "aws_route" "private_nat_gateway" {
      + destination_cidr_block = "0.0.0.0/0"
      + id                     = (known after apply)
      + instance_id            = (known after apply)
      + instance_owner_id      = (known after apply)
      + nat_gateway_id         = (known after apply)
      + network_interface_id   = (known after apply)
      + origin                 = (known after apply)
      + region                 = "us-west-2"
      + route_table_id         = (known after apply)
      + state                  = (known after apply)

      + timeouts {
          + create = "5m"
        }
    }

  # module.vpc.aws_route.public_internet_gateway[0] will be created
  + resource "aws_route" "public_internet_gateway" {
      + destination_cidr_block = "0.0.0.0/0"
      + gateway_id             = (known after apply)
      + id                     = (known after apply)
      + instance_id            = (known after apply)
      + instance_owner_id      = (known after apply)
      + network_interface_id   = (known after apply)
      + origin                 = (known after apply)
      + region                 = "us-west-2"
      + route_table_id         = (known after apply)
      + state                  = (known after apply)

      + timeouts {
          + create = "5m"
        }
    }

  # module.vpc.aws_route_table.intra[0] will be created
  + resource "aws_route_table" "intra" {
      + arn              = (known after apply)
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + region           = "us-west-2"
      + route            = (known after apply)
      + tags             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-intra"
          + "Project"   = "devboard"
        }
      + tags_all         = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-intra"
          + "Project"   = "devboard"
        }
      + vpc_id           = (known after apply)
    }

  # module.vpc.aws_route_table.private[0] will be created
  + resource "aws_route_table" "private" {
      + arn              = (known after apply)
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + region           = "us-west-2"
      + route            = (known after apply)
      + tags             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-private"
          + "Project"   = "devboard"
        }
      + tags_all         = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-private"
          + "Project"   = "devboard"
        }
      + vpc_id           = (known after apply)
    }

  # module.vpc.aws_route_table.public[0] will be created
  + resource "aws_route_table" "public" {
      + arn              = (known after apply)
      + id               = (known after apply)
      + owner_id         = (known after apply)
      + propagating_vgws = (known after apply)
      + region           = "us-west-2"
      + route            = (known after apply)
      + tags             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-public"
          + "Project"   = "devboard"
        }
      + tags_all         = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-public"
          + "Project"   = "devboard"
        }
      + vpc_id           = (known after apply)
    }

  # module.vpc.aws_route_table_association.intra[0] will be created
  + resource "aws_route_table_association" "intra" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.intra[1] will be created
  + resource "aws_route_table_association" "intra" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.intra[2] will be created
  + resource "aws_route_table_association" "intra" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.private[0] will be created
  + resource "aws_route_table_association" "private" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.private[1] will be created
  + resource "aws_route_table_association" "private" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.private[2] will be created
  + resource "aws_route_table_association" "private" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.public[0] will be created
  + resource "aws_route_table_association" "public" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.public[1] will be created
  + resource "aws_route_table_association" "public" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_route_table_association.public[2] will be created
  + resource "aws_route_table_association" "public" {
      + id             = (known after apply)
      + region         = "us-west-2"
      + route_table_id = (known after apply)
      + subnet_id      = (known after apply)
    }

  # module.vpc.aws_subnet.intra[0] will be created
  + resource "aws_subnet" "intra" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2a"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.7.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-intra-us-west-2a"
          + "Project"   = "devboard"
        }
      + tags_all                                       = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-intra-us-west-2a"
          + "Project"   = "devboard"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.intra[1] will be created
  + resource "aws_subnet" "intra" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2b"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.8.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-intra-us-west-2b"
          + "Project"   = "devboard"
        }
      + tags_all                                       = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-intra-us-west-2b"
          + "Project"   = "devboard"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.intra[2] will be created
  + resource "aws_subnet" "intra" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2c"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.9.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-intra-us-west-2c"
          + "Project"   = "devboard"
        }
      + tags_all                                       = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard-intra-us-west-2c"
          + "Project"   = "devboard"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.private[0] will be created
  + resource "aws_subnet" "private" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2a"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.4.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"                         = "devboard"
          + "ManagedBy"                       = "terraform"
          + "Name"                            = "devboard-private-us-west-2a"
          + "Project"                         = "devboard"
          + "kubernetes.io/role/internal-elb" = "1"
        }
      + tags_all                                       = {
          + "Cluster"                         = "devboard"
          + "ManagedBy"                       = "terraform"
          + "Name"                            = "devboard-private-us-west-2a"
          + "Project"                         = "devboard"
          + "kubernetes.io/role/internal-elb" = "1"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.private[1] will be created
  + resource "aws_subnet" "private" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2b"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.5.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"                         = "devboard"
          + "ManagedBy"                       = "terraform"
          + "Name"                            = "devboard-private-us-west-2b"
          + "Project"                         = "devboard"
          + "kubernetes.io/role/internal-elb" = "1"
        }
      + tags_all                                       = {
          + "Cluster"                         = "devboard"
          + "ManagedBy"                       = "terraform"
          + "Name"                            = "devboard-private-us-west-2b"
          + "Project"                         = "devboard"
          + "kubernetes.io/role/internal-elb" = "1"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.private[2] will be created
  + resource "aws_subnet" "private" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2c"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.6.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"                         = "devboard"
          + "ManagedBy"                       = "terraform"
          + "Name"                            = "devboard-private-us-west-2c"
          + "Project"                         = "devboard"
          + "kubernetes.io/role/internal-elb" = "1"
        }
      + tags_all                                       = {
          + "Cluster"                         = "devboard"
          + "ManagedBy"                       = "terraform"
          + "Name"                            = "devboard-private-us-west-2c"
          + "Project"                         = "devboard"
          + "kubernetes.io/role/internal-elb" = "1"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.public[0] will be created
  + resource "aws_subnet" "public" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2a"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.1.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"                = "devboard"
          + "ManagedBy"              = "terraform"
          + "Name"                   = "devboard-public-us-west-2a"
          + "Project"                = "devboard"
          + "kubernetes.io/role/elb" = "1"
        }
      + tags_all                                       = {
          + "Cluster"                = "devboard"
          + "ManagedBy"              = "terraform"
          + "Name"                   = "devboard-public-us-west-2a"
          + "Project"                = "devboard"
          + "kubernetes.io/role/elb" = "1"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.public[1] will be created
  + resource "aws_subnet" "public" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2b"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.2.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"                = "devboard"
          + "ManagedBy"              = "terraform"
          + "Name"                   = "devboard-public-us-west-2b"
          + "Project"                = "devboard"
          + "kubernetes.io/role/elb" = "1"
        }
      + tags_all                                       = {
          + "Cluster"                = "devboard"
          + "ManagedBy"              = "terraform"
          + "Name"                   = "devboard-public-us-west-2b"
          + "Project"                = "devboard"
          + "kubernetes.io/role/elb" = "1"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_subnet.public[2] will be created
  + resource "aws_subnet" "public" {
      + arn                                            = (known after apply)
      + assign_ipv6_address_on_creation                = false
      + availability_zone                              = "us-west-2c"
      + availability_zone_id                           = (known after apply)
      + cidr_block                                     = "10.0.3.0/24"
      + enable_dns64                                   = false
      + enable_resource_name_dns_a_record_on_launch    = false
      + enable_resource_name_dns_aaaa_record_on_launch = false
      + id                                             = (known after apply)
      + ipv6_cidr_block                                = (known after apply)
      + ipv6_cidr_block_association_id                 = (known after apply)
      + ipv6_native                                    = false
      + map_public_ip_on_launch                        = false
      + owner_id                                       = (known after apply)
      + private_dns_hostname_type_on_launch            = (known after apply)
      + region                                         = "us-west-2"
      + tags                                           = {
          + "Cluster"                = "devboard"
          + "ManagedBy"              = "terraform"
          + "Name"                   = "devboard-public-us-west-2c"
          + "Project"                = "devboard"
          + "kubernetes.io/role/elb" = "1"
        }
      + tags_all                                       = {
          + "Cluster"                = "devboard"
          + "ManagedBy"              = "terraform"
          + "Name"                   = "devboard-public-us-west-2c"
          + "Project"                = "devboard"
          + "kubernetes.io/role/elb" = "1"
        }
      + vpc_id                                         = (known after apply)
    }

  # module.vpc.aws_vpc.this[0] will be created
  + resource "aws_vpc" "this" {
      + arn                                  = (known after apply)
      + cidr_block                           = "10.0.0.0/16"
      + default_network_acl_id               = (known after apply)
      + default_route_table_id               = (known after apply)
      + default_security_group_id            = (known after apply)
      + dhcp_options_id                      = (known after apply)
      + enable_dns_hostnames                 = true
      + enable_dns_support                   = true
      + enable_network_address_usage_metrics = (known after apply)
      + id                                   = (known after apply)
      + instance_tenancy                     = "default"
      + ipv6_association_id                  = (known after apply)
      + ipv6_cidr_block                      = (known after apply)
      + ipv6_cidr_block_network_border_group = (known after apply)
      + main_route_table_id                  = (known after apply)
      + owner_id                             = (known after apply)
      + region                               = "us-west-2"
      + tags                                 = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard"
          + "Project"   = "devboard"
        }
      + tags_all                             = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "devboard"
          + "Project"   = "devboard"
        }
    }

  # module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0] will be created
  + resource "aws_eks_node_group" "this" {
      + ami_type               = "AL2023_x86_64_STANDARD"
      + arn                    = (known after apply)
      + capacity_type          = "ON_DEMAND"
      + cluster_name           = (known after apply)
      + disk_size              = (known after apply)
      + id                     = (known after apply)
      + instance_types         = [
          + "t3.large",
        ]
      + node_group_name        = (known after apply)
      + node_group_name_prefix = "default-"
      + node_role_arn          = (known after apply)
      + region                 = "us-west-2"
      + release_version        = "1.34.9-20260810"
      + resources              = (known after apply)
      + status                 = (known after apply)
      + subnet_ids             = (known after apply)
      + tags                   = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "default"
          + "NodeGroup" = "default"
          + "Project"   = "devboard"
        }
      + tags_all               = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Name"      = "default"
          + "NodeGroup" = "default"
          + "Project"   = "devboard"
        }
      + version                = "1.34"

      + launch_template {
          + id      = (known after apply)
          + name    = (known after apply)
          + version = (known after apply)
        }

      + node_repair_config (known after apply)

      + scaling_config {
          + desired_size = 3
          + max_size     = 4
          + min_size     = 2
        }

      + update_config {
          + max_unavailable_percentage = 33
        }
    }

  # module.eks.module.eks_managed_node_group["default"].aws_iam_role.this[0] will be created
  + resource "aws_iam_role" "this" {
      + arn                   = (known after apply)
      + assume_role_policy    = jsonencode(
            {
              + Statement = [
                  + {
                      + Action    = "sts:AssumeRole"
                      + Effect    = "Allow"
                      + Principal = {
                          + Service = "ec2.amazonaws.com"
                        }
                      + Sid       = "EKSNodeAssumeRole"
                    },
                ]
              + Version   = "2012-10-17"
            }
        )
      + create_date           = (known after apply)
      + description           = "EKS managed node group IAM role"
      + force_detach_policies = true
      + id                    = (known after apply)
      + managed_policy_arns   = (known after apply)
      + max_session_duration  = 3600
      + name                  = (known after apply)
      + name_prefix           = "default-eks-node-group-"
      + path                  = "/"
      + tags                  = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "NodeGroup" = "default"
          + "Project"   = "devboard"
        }
      + tags_all              = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "NodeGroup" = "default"
          + "Project"   = "devboard"
        }
      + unique_id             = (known after apply)

      + inline_policy (known after apply)
    }

  # module.eks.module.eks_managed_node_group["default"].aws_iam_role_policy_attachment.this["AmazonEC2ContainerRegistryReadOnly"] will be created
  + resource "aws_iam_role_policy_attachment" "this" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      + role       = (known after apply)
    }

  # module.eks.module.eks_managed_node_group["default"].aws_iam_role_policy_attachment.this["AmazonEKSWorkerNodePolicy"] will be created
  + resource "aws_iam_role_policy_attachment" "this" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
      + role       = (known after apply)
    }

  # module.eks.module.eks_managed_node_group["default"].aws_iam_role_policy_attachment.this["AmazonEKS_CNI_Policy"] will be created
  + resource "aws_iam_role_policy_attachment" "this" {
      + id         = (known after apply)
      + policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      + role       = (known after apply)
    }

  # module.eks.module.eks_managed_node_group["default"].aws_launch_template.this[0] will be created
  + resource "aws_launch_template" "this" {
      + arn                    = (known after apply)
      + default_version        = (known after apply)
      + description            = "Custom launch template for default EKS managed node group"
      + id                     = (known after apply)
      + latest_version         = (known after apply)
      + name                   = (known after apply)
      + name_prefix            = "default-"
      + region                 = "us-west-2"
      + tags                   = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "NodeGroup" = "default"
          + "Project"   = "devboard"
        }
      + tags_all               = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "NodeGroup" = "default"
          + "Project"   = "devboard"
        }
      + update_default_version = true
      + vpc_security_group_ids = (known after apply)
        # (2 unchanged attributes hidden)

      + block_device_mappings {
          + device_name = "/dev/xvda"

          + ebs {
              + delete_on_termination      = "true"
              + encrypted                  = "true"
              + iops                       = (known after apply)
              + throughput                 = (known after apply)
              + volume_initialization_rate = (known after apply)
              + volume_size                = 30
              + volume_type                = "gp3"
            }
        }

      + metadata_options {
          + http_endpoint               = "enabled"
          + http_protocol_ipv6          = (known after apply)
          + http_put_response_hop_limit = 1
          + http_tokens                 = "required"
          + instance_metadata_tags      = (known after apply)
        }

      + tag_specifications {
          + resource_type = "instance"
          + tags          = {
              + "Cluster"   = "devboard"
              + "ManagedBy" = "terraform"
              + "Name"      = "default"
              + "NodeGroup" = "default"
              + "Project"   = "devboard"
            }
        }
      + tag_specifications {
          + resource_type = "network-interface"
          + tags          = {
              + "Cluster"   = "devboard"
              + "ManagedBy" = "terraform"
              + "Name"      = "default"
              + "NodeGroup" = "default"
              + "Project"   = "devboard"
            }
        }
      + tag_specifications {
          + resource_type = "volume"
          + tags          = {
              + "Cluster"   = "devboard"
              + "ManagedBy" = "terraform"
              + "Name"      = "default"
              + "NodeGroup" = "default"
              + "Project"   = "devboard"
            }
        }
    }

  # module.eks.module.kms.data.aws_iam_policy_document.this[0] will be read during apply
  # (config refers to values not yet known)
 <= data "aws_iam_policy_document" "this" {
      + id                        = (known after apply)
      + json                      = (known after apply)
      + minified_json             = (known after apply)
      + override_policy_documents = []
      + source_policy_documents   = []

      + statement {
          + actions   = [
              + "kms:*",
            ]
          + resources = [
              + "*",
            ]
          + sid       = "Default"

          + principals {
              + identifiers = [
                  + "arn:aws:iam::899805259876:root",
                ]
              + type        = "AWS"
            }
        }
      + statement {
          + actions   = [
              + "kms:CancelKeyDeletion",
              + "kms:Create*",
              + "kms:Delete*",
              + "kms:Describe*",
              + "kms:Disable*",
              + "kms:Enable*",
              + "kms:Get*",
              + "kms:ImportKeyMaterial",
              + "kms:List*",
              + "kms:Put*",
              + "kms:ReplicateKey",
              + "kms:Revoke*",
              + "kms:ScheduleKeyDeletion",
              + "kms:TagResource",
              + "kms:UntagResource",
              + "kms:Update*",
            ]
          + resources = [
              + "*",
            ]
          + sid       = "KeyAdministration"

          + principals {
              + identifiers = [
                  + "arn:aws:iam::899805259876:role/devboard-bastion-admin-role",
                ]
              + type        = "AWS"
            }
        }
      + statement {
          + actions   = [
              + "kms:Decrypt",
              + "kms:DescribeKey",
              + "kms:Encrypt",
              + "kms:GenerateDataKey*",
              + "kms:ReEncrypt*",
            ]
          + resources = [
              + "*",
            ]
          + sid       = "KeyUsage"

          + principals {
              + identifiers = [
                  + (known after apply),
                ]
              + type        = "AWS"
            }
        }
    }

  # module.eks.module.kms.aws_kms_alias.this["cluster"] will be created
  + resource "aws_kms_alias" "this" {
      + arn            = (known after apply)
      + id             = (known after apply)
      + name           = "alias/eks/devboard"
      + name_prefix    = (known after apply)
      + region         = "us-west-2"
      + target_key_arn = (known after apply)
      + target_key_id  = (known after apply)
    }

  # module.eks.module.kms.aws_kms_key.this[0] will be created
  + resource "aws_kms_key" "this" {
      + arn                                = (known after apply)
      + bypass_policy_lockout_safety_check = false
      + customer_master_key_spec           = "SYMMETRIC_DEFAULT"
      + description                        = "devboard cluster encryption key"
      + enable_key_rotation                = true
      + id                                 = (known after apply)
      + is_enabled                         = true
      + key_id                             = (known after apply)
      + key_usage                          = "ENCRYPT_DECRYPT"
      + multi_region                       = false
      + policy                             = (known after apply)
      + region                             = "us-west-2"
      + rotation_period_in_days            = (known after apply)
      + tags                               = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
      + tags_all                           = {
          + "Cluster"   = "devboard"
          + "ManagedBy" = "terraform"
          + "Project"   = "devboard"
        }
    }

  # module.eks.module.eks_managed_node_group["default"].module.user_data.null_resource.validate_cluster_service_cidr will be created
  + resource "null_resource" "validate_cluster_service_cidr" {
      + id = (known after apply)
    }

Plan: 83 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + argocd_initial_password   = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  + cluster_endpoint          = (known after apply)
  + cluster_name              = "devboard"
  + cluster_version           = "1.34"
  + configure_kubectl         = "aws eks update-kubeconfig --name devboard --region us-west-2"
  + external_secrets_role_arn = (known after apply)
  + oidc_provider_arn         = (known after apply)
  + postgres_secret_arn       = (known after apply)
  + postgres_secret_name      = "devboard/postgres"
  + private_subnets           = [
      + (known after apply),
      + (known after apply),
      + (known after apply),
    ]
  + public_subnets            = [
      + (known after apply),
      + (known after apply),
      + (known after apply),
    ]
  + set_postgres_secret       = <<-EOT
        PGPASS=$(openssl rand -hex 32)
        aws secretsmanager put-secret-value \
          --secret-id devboard/postgres \
          --region us-west-2 \
          --secret-string "$(jq -nc --arg p "$PGPASS" \
              '{username:"devboard", password:$p, dbname:"devboard"}')"
    EOT
  + vpc_id                    = (known after apply)

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_secretsmanager_secret.postgres: Creating...
module.ebs_csi_pod_identity.aws_iam_role.this[0]: Creating...
module.external_secrets_pod_identity.aws_iam_role.this[0]: Creating...
module.vpc.aws_vpc.this[0]: Creating...
module.external_secrets_pod_identity.aws_iam_policy.external_secrets[0]: Creating...
module.eks.aws_iam_role.this[0]: Creating...
module.ebs_csi_pod_identity.aws_iam_policy.ebs_csi[0]: Creating...
module.eks.module.eks_managed_node_group["default"].aws_iam_role.this[0]: Creating...
module.eks.aws_cloudwatch_log_group.this[0]: Creating...
aws_secretsmanager_secret.postgres: Creation complete after 1s [id=arn:aws:secretsmanager:us-west-2:899805259876:secret:devboard/postgres-qhadDt]
module.eks.aws_cloudwatch_log_group.this[0]: Creation complete after 1s [id=/aws/eks/devboard/cluster]
module.ebs_csi_pod_identity.aws_iam_policy.ebs_csi[0]: Creation complete after 1s [id=arn:aws:iam::899805259876:policy/AmazonEKS_EBS_CSI-1e88a5b6f984d1cf6be459c461]
module.external_secrets_pod_identity.aws_iam_policy.external_secrets[0]: Creation complete after 1s [id=arn:aws:iam::899805259876:policy/AmazonEKS_ExternalSecrets-8e57cbdf5969e91bcffb594da5]
module.eks.module.eks_managed_node_group["default"].aws_iam_role.this[0]: Creation complete after 1s [id=default-eks-node-group-89aaf7bd78a6f1ac78434c1b75]
module.eks.module.eks_managed_node_group["default"].aws_iam_role_policy_attachment.this["AmazonEKS_CNI_Policy"]: Creating...
module.eks.module.eks_managed_node_group["default"].aws_iam_role_policy_attachment.this["AmazonEKSWorkerNodePolicy"]: Creating...
module.eks.module.eks_managed_node_group["default"].aws_iam_role_policy_attachment.this["AmazonEC2ContainerRegistryReadOnly"]: Creating...
module.external_secrets_pod_identity.aws_iam_role.this[0]: Creation complete after 1s [id=devboard-external-secrets-ab2373b1bdfda33e4275bad06e]
module.external_secrets_pod_identity.aws_iam_role_policy_attachment.external_secrets[0]: Creating...
module.ebs_csi_pod_identity.aws_iam_role.this[0]: Creation complete after 1s [id=devboard-ebs-csi-e8c410e1f5cea013249897feb3]
module.ebs_csi_pod_identity.aws_iam_role_policy_attachment.ebs_csi[0]: Creating...
module.eks.aws_iam_role.this[0]: Creation complete after 1s [id=devboard-cluster-1dd8a43da382a97bb24f98e43f]
module.eks.aws_iam_role_policy_attachment.this["AmazonEKSClusterPolicy"]: Creating...
module.eks.module.kms.data.aws_iam_policy_document.this[0]: Reading...
module.eks.module.kms.data.aws_iam_policy_document.this[0]: Read complete after 0s [id=1059609080]
module.eks.module.kms.aws_kms_key.this[0]: Creating...
module.external_secrets_pod_identity.aws_iam_role_policy_attachment.external_secrets[0]: Creation complete after 0s [id=devboard-external-secrets-ab2373b1bdfda33e4275bad06e/arn:aws:iam::899805259876:policy/AmazonEKS_ExternalSecrets-8e57cbdf5969e91bcffb594da5]
module.eks.module.eks_managed_node_group["default"].aws_iam_role_policy_attachment.this["AmazonEKSWorkerNodePolicy"]: Creation complete after 0s [id=default-eks-node-group-89aaf7bd78a6f1ac78434c1b75/arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy]
module.ebs_csi_pod_identity.aws_iam_role_policy_attachment.ebs_csi[0]: Creation complete after 0s [id=devboard-ebs-csi-e8c410e1f5cea013249897feb3/arn:aws:iam::899805259876:policy/AmazonEKS_EBS_CSI-1e88a5b6f984d1cf6be459c461]
module.eks.aws_iam_role_policy_attachment.this["AmazonEKSClusterPolicy"]: Creation complete after 0s [id=devboard-cluster-1dd8a43da382a97bb24f98e43f/arn:aws:iam::aws:policy/AmazonEKSClusterPolicy]
module.eks.module.eks_managed_node_group["default"].aws_iam_role_policy_attachment.this["AmazonEKS_CNI_Policy"]: Creation complete after 0s [id=default-eks-node-group-89aaf7bd78a6f1ac78434c1b75/arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy]
module.eks.module.eks_managed_node_group["default"].aws_iam_role_policy_attachment.this["AmazonEC2ContainerRegistryReadOnly"]: Creation complete after 0s [id=default-eks-node-group-89aaf7bd78a6f1ac78434c1b75/arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly]
module.vpc.aws_vpc.this[0]: Creation complete after 2s [id=vpc-03be02b07ff17c314]
module.eks.aws_security_group.node[0]: Creating...
module.vpc.aws_default_security_group.this[0]: Creating...
module.vpc.aws_default_route_table.default[0]: Creating...
module.eks.aws_security_group.cluster[0]: Creating...
module.vpc.aws_subnet.intra[1]: Creating...
module.vpc.aws_default_network_acl.this[0]: Creating...
module.vpc.aws_route_table.public[0]: Creating...
module.vpc.aws_route_table.intra[0]: Creating...
module.vpc.aws_subnet.private[1]: Creating...
module.vpc.aws_default_route_table.default[0]: Creation complete after 0s [id=rtb-0586b25f54ce0c198]
module.vpc.aws_internet_gateway.this[0]: Creating...
module.vpc.aws_route_table.intra[0]: Creation complete after 1s [id=rtb-0b33bb2e2b4d0cd0a]
module.vpc.aws_route_table.public[0]: Creation complete after 1s [id=rtb-02af25a360aa297ed]
module.vpc.aws_subnet.private[2]: Creating...
module.vpc.aws_subnet.private[0]: Creating...
module.vpc.aws_internet_gateway.this[0]: Creation complete after 1s [id=igw-04a6ab3e911c3a280]
module.vpc.aws_route_table.private[0]: Creating...
module.vpc.aws_subnet.private[1]: Creation complete after 1s [id=subnet-0cb6319fb99a3735b]
module.vpc.aws_subnet.public[0]: Creating...
module.vpc.aws_subnet.intra[1]: Creation complete after 1s [id=subnet-0ec531437347034f8]
module.vpc.aws_subnet.public[2]: Creating...
module.vpc.aws_default_network_acl.this[0]: Creation complete after 1s [id=acl-03c89226a9bde80a8]
module.vpc.aws_subnet.public[1]: Creating...
module.vpc.aws_route_table.private[0]: Creation complete after 0s [id=rtb-0af29533aad068ccc]
module.vpc.aws_subnet.intra[0]: Creating...
module.vpc.aws_subnet.private[2]: Creation complete after 0s [id=subnet-0cb7c43e9eceeee08]
module.vpc.aws_subnet.intra[2]: Creating...
module.vpc.aws_default_security_group.this[0]: Creation complete after 1s [id=sg-07887856136004ea5]
module.vpc.aws_subnet.public[0]: Creation complete after 0s [id=subnet-087169b2103b1b2bc]
module.vpc.aws_eip.nat[0]: Creating...
module.vpc.aws_route.public_internet_gateway[0]: Creating...
module.vpc.aws_subnet.intra[0]: Creation complete after 1s [id=subnet-0b43d9a3645d34bf6]
module.eks.aws_security_group.cluster[0]: Creation complete after 2s [id=sg-086984e097366932d]
module.vpc.aws_subnet.public[1]: Creation complete after 1s [id=subnet-0021c29d418decc4e]
module.vpc.aws_subnet.intra[2]: Creation complete after 1s [id=subnet-08bfa691244cedff7]
module.vpc.aws_route_table_association.intra[2]: Creating...
module.vpc.aws_route_table_association.intra[1]: Creating...
module.vpc.aws_route_table_association.intra[0]: Creating...
module.eks.aws_security_group.node[0]: Creation complete after 2s [id=sg-0591dfb9f326b2972]
module.eks.aws_security_group_rule.node["ingress_cluster_9443_webhook"]: Creating...
module.eks.aws_security_group_rule.node["ingress_cluster_8443_webhook"]: Creating...
module.vpc.aws_route.public_internet_gateway[0]: Creation complete after 1s [id=r-rtb-02af25a360aa297ed1080289494]
module.eks.aws_security_group_rule.node["ingress_self_coredns_udp"]: Creating...
module.vpc.aws_route_table_association.intra[0]: Creation complete after 0s [id=rtbassoc-00cff3a39f606d955]
module.eks.aws_security_group_rule.node["ingress_cluster_kubelet"]: Creating...
module.vpc.aws_route_table_association.intra[1]: Creation complete after 0s [id=rtbassoc-0fc0f7fd96399dd2f]
module.eks.aws_security_group_rule.node["ingress_cluster_4443_webhook"]: Creating...
module.vpc.aws_route_table_association.intra[2]: Creation complete after 0s [id=rtbassoc-02e0026f4d29b86a1]
module.eks.aws_security_group_rule.node["ingress_cluster_6443_webhook"]: Creating...
module.eks.aws_security_group_rule.node["ingress_cluster_9443_webhook"]: Creation complete after 0s [id=sgrule-4024525895]
module.eks.aws_security_group_rule.node["ingress_cluster_443"]: Creating...
module.vpc.aws_eip.nat[0]: Creation complete after 1s [id=eipalloc-092b3d4052238d1d7]
module.eks.aws_security_group_rule.node["egress_all"]: Creating...
module.eks.aws_security_group_rule.node["ingress_cluster_8443_webhook"]: Creation complete after 1s [id=sgrule-2336249740]
module.eks.aws_security_group_rule.node["ingress_cluster_10251_webhook"]: Creating...
module.eks.aws_security_group_rule.node["ingress_self_coredns_udp"]: Creation complete after 1s [id=sgrule-1522136521]
module.eks.aws_security_group_rule.node["ingress_self_coredns_tcp"]: Creating...
module.eks.aws_security_group_rule.node["ingress_cluster_kubelet"]: Creation complete after 2s [id=sgrule-1034268870]
module.eks.aws_security_group_rule.node["ingress_nodes_ephemeral"]: Creating...
module.vpc.aws_subnet.private[0]: Creation complete after 3s [id=subnet-0450e6bbf2da30a5b]
module.eks.aws_security_group_rule.cluster["ingress_nodes_443"]: Creating...
module.eks.aws_security_group_rule.node["ingress_cluster_4443_webhook"]: Creation complete after 2s [id=sgrule-1365118011]
module.vpc.aws_route_table_association.private[1]: Creating...
module.eks.aws_security_group_rule.cluster["ingress_nodes_443"]: Creation complete after 0s [id=sgrule-2365802662]
module.vpc.aws_route_table_association.private[0]: Creating...
module.vpc.aws_subnet.public[2]: Creation complete after 3s [id=subnet-0842aeea1a86216ff]
module.vpc.aws_route_table_association.private[2]: Creating...
module.vpc.aws_route_table_association.private[1]: Creation complete after 0s [id=rtbassoc-0650da3dc0acf6e75]
module.vpc.aws_nat_gateway.this[0]: Creating...
module.vpc.aws_route_table_association.private[0]: Creation complete after 0s [id=rtbassoc-00747079be24de884]
module.vpc.aws_route_table_association.public[0]: Creating...
module.vpc.aws_route_table_association.private[2]: Creation complete after 0s [id=rtbassoc-080b3545e148aa024]
module.vpc.aws_route_table_association.public[1]: Creating...
module.eks.aws_security_group_rule.node["ingress_cluster_6443_webhook"]: Creation complete after 3s [id=sgrule-2551999405]
module.vpc.aws_route_table_association.public[2]: Creating...
module.vpc.aws_route_table_association.public[0]: Creation complete after 1s [id=rtbassoc-03e905b07295aa362]
module.vpc.aws_route_table_association.public[1]: Creation complete after 1s [id=rtbassoc-01c1abaf0af0cf6e1]
module.vpc.aws_route_table_association.public[2]: Creation complete after 0s [id=rtbassoc-0c319c8553461abce]
module.eks.aws_security_group_rule.node["ingress_cluster_443"]: Creation complete after 3s [id=sgrule-1474198580]
module.eks.aws_security_group_rule.node["egress_all"]: Creation complete after 4s [id=sgrule-84319429]
module.eks.aws_security_group_rule.node["ingress_cluster_10251_webhook"]: Creation complete after 3s [id=sgrule-166518973]
module.eks.aws_security_group_rule.node["ingress_self_coredns_tcp"]: Creation complete after 4s [id=sgrule-4276508198]
module.eks.aws_security_group_rule.node["ingress_nodes_ephemeral"]: Creation complete after 3s [id=sgrule-3257822284]
module.eks.module.kms.aws_kms_key.this[0]: Still creating... [00m10s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [00m10s elapsed]
module.eks.module.kms.aws_kms_key.this[0]: Still creating... [00m20s elapsed]
module.eks.module.kms.aws_kms_key.this[0]: Creation complete after 21s [id=bd3dac4b-9017-49dc-9fb9-5f8ad1dc4383]
module.eks.aws_iam_policy.cluster_encryption[0]: Creating...
module.eks.module.kms.aws_kms_alias.this["cluster"]: Creating...
module.eks.aws_eks_cluster.this[0]: Creating...
module.eks.aws_iam_policy.cluster_encryption[0]: Creation complete after 1s [id=arn:aws:iam::899805259876:policy/devboard-cluster-ClusterEncryption3f57cf2285c67aa8ca23969dca]
module.eks.aws_iam_role_policy_attachment.cluster_encryption[0]: Creating...
module.eks.module.kms.aws_kms_alias.this["cluster"]: Creation complete after 1s [id=alias/eks/devboard]
module.eks.aws_iam_role_policy_attachment.cluster_encryption[0]: Creation complete after 0s [id=devboard-cluster-1dd8a43da382a97bb24f98e43f/arn:aws:iam::899805259876:policy/devboard-cluster-ClusterEncryption3f57cf2285c67aa8ca23969dca]
module.vpc.aws_nat_gateway.this[0]: Still creating... [00m20s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [00m10s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [00m30s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [00m20s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [00m40s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [00m30s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [00m50s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [00m40s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [01m00s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [00m50s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [01m10s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [01m00s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [01m20s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [01m10s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [01m30s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [01m20s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [01m40s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [01m30s elapsed]
module.vpc.aws_nat_gateway.this[0]: Still creating... [01m50s elapsed]
module.vpc.aws_nat_gateway.this[0]: Creation complete after 1m54s [id=nat-005e55125cc1b87fc]
module.vpc.aws_route.private_nat_gateway[0]: Creating...
module.vpc.aws_route.private_nat_gateway[0]: Creation complete after 1s [id=r-rtb-0af29533aad068ccc1080289494]
module.eks.aws_eks_cluster.this[0]: Still creating... [01m40s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [01m50s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [02m00s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [02m10s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [02m20s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [02m30s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [02m40s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [02m50s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [03m00s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [03m10s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [03m20s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [03m30s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [03m40s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [03m50s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [04m00s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [04m10s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [04m20s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [04m30s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [04m40s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [04m50s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [05m00s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [05m10s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [05m20s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [05m30s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [05m40s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [05m50s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [06m00s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [06m10s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [06m20s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [06m30s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [06m40s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [06m50s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [07m00s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [07m10s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [07m20s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [07m30s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [07m40s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [07m50s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [08m00s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [08m10s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [08m20s elapsed]
module.eks.aws_eks_cluster.this[0]: Still creating... [08m30s elapsed]
module.eks.aws_eks_cluster.this[0]: Creation complete after 8m33s [id=devboard]
module.eks.data.aws_eks_addon_version.this["eks-pod-identity-agent"]: Reading...
module.eks.data.aws_eks_addon_version.this["vpc-cni"]: Reading...
module.eks.aws_eks_access_entry.this["cluster_creator"]: Creating...
module.eks.data.aws_eks_addon_version.this["kube-proxy"]: Reading...
module.eks.data.aws_eks_addon_version.this["coredns"]: Reading...
module.eks.data.aws_eks_addon_version.this["metrics-server"]: Reading...
module.eks.aws_ec2_tag.cluster_primary_security_group["ManagedBy"]: Creating...
module.eks.aws_ec2_tag.cluster_primary_security_group["Project"]: Creating...
module.eks.aws_ec2_tag.cluster_primary_security_group["Cluster"]: Creating...
module.eks.data.tls_certificate.this[0]: Reading...
module.eks.data.aws_eks_addon_version.this["eks-pod-identity-agent"]: Read complete after 0s [id=eks-pod-identity-agent]
module.eks.data.aws_eks_addon_version.this["aws-ebs-csi-driver"]: Reading...
module.eks.data.aws_eks_addon_version.this["coredns"]: Read complete after 0s [id=coredns]
module.eks.data.aws_eks_addon_version.this["metrics-server"]: Read complete after 0s [id=metrics-server]
module.eks.data.aws_eks_addon_version.this["kube-proxy"]: Read complete after 0s [id=kube-proxy]
module.eks.data.aws_eks_addon_version.this["vpc-cni"]: Read complete after 0s [id=vpc-cni]
module.eks.aws_ec2_tag.cluster_primary_security_group["Project"]: Creation complete after 0s [id=sg-05631dbf97d3ea840,Project]
module.eks.aws_ec2_tag.cluster_primary_security_group["ManagedBy"]: Creation complete after 0s [id=sg-05631dbf97d3ea840,ManagedBy]
module.eks.data.tls_certificate.this[0]: Read complete after 0s [id=f97f646c2cd14cc0db0f757f0fccc96abbbe2af5]
module.eks.time_sleep.this[0]: Creating...
module.eks.aws_iam_openid_connect_provider.oidc_provider[0]: Creating...
module.eks.data.aws_eks_addon_version.this["aws-ebs-csi-driver"]: Read complete after 0s [id=aws-ebs-csi-driver]
module.eks.aws_ec2_tag.cluster_primary_security_group["Cluster"]: Creation complete after 0s [id=sg-05631dbf97d3ea840,Cluster]
module.eks.aws_eks_addon.before_compute["vpc-cni"]: Creating...
module.eks.aws_eks_addon.before_compute["eks-pod-identity-agent"]: Creating...
module.eks.aws_eks_access_entry.this["cluster_creator"]: Creation complete after 1s [id=devboard:arn:aws:iam::899805259876:role/devboard-bastion-admin-role]
module.eks.aws_eks_access_policy_association.this["cluster_creator_admin"]: Creating...
module.eks.aws_iam_openid_connect_provider.oidc_provider[0]: Creation complete after 1s [id=arn:aws:iam::899805259876:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/DEE55C0209AB28E15DA00FCFFFA01879]
module.eks.aws_eks_access_policy_association.this["cluster_creator_admin"]: Creation complete after 0s [id=devboard#arn:aws:iam::899805259876:role/devboard-bastion-admin-role#arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy]
module.external_secrets_pod_identity.aws_eks_pod_identity_association.this["this"]: Creating...
module.ebs_csi_pod_identity.aws_eks_pod_identity_association.this["this"]: Creating...
module.external_secrets_pod_identity.aws_eks_pod_identity_association.this["this"]: Creation complete after 2s [id=a-jpdyiem67vamj2wpu]
module.ebs_csi_pod_identity.aws_eks_pod_identity_association.this["this"]: Creation complete after 2s [id=a-hlkxsyejyy6zxjrop]
module.eks.time_sleep.this[0]: Still creating... [00m10s elapsed]
module.eks.aws_eks_addon.before_compute["vpc-cni"]: Still creating... [00m10s elapsed]
module.eks.aws_eks_addon.before_compute["eks-pod-identity-agent"]: Still creating... [00m10s elapsed]
module.eks.time_sleep.this[0]: Still creating... [00m20s elapsed]
module.eks.aws_eks_addon.before_compute["eks-pod-identity-agent"]: Still creating... [00m20s elapsed]
module.eks.aws_eks_addon.before_compute["vpc-cni"]: Still creating... [00m20s elapsed]
module.eks.time_sleep.this[0]: Still creating... [00m30s elapsed]
module.eks.aws_eks_addon.before_compute["vpc-cni"]: Still creating... [00m30s elapsed]
module.eks.aws_eks_addon.before_compute["eks-pod-identity-agent"]: Still creating... [00m30s elapsed]
module.eks.time_sleep.this[0]: Creation complete after 30s [id=2026-08-15T08:00:06Z]
module.eks.module.eks_managed_node_group["default"].module.user_data.null_resource.validate_cluster_service_cidr: Creating...
module.eks.module.eks_managed_node_group["default"].module.user_data.null_resource.validate_cluster_service_cidr: Creation complete after 0s [id=6286064860649670447]
module.eks.module.eks_managed_node_group["default"].aws_launch_template.this[0]: Creating...
module.eks.aws_eks_addon.before_compute["eks-pod-identity-agent"]: Creation complete after 35s [id=devboard:eks-pod-identity-agent]
module.eks.aws_eks_addon.before_compute["vpc-cni"]: Creation complete after 35s [id=devboard:vpc-cni]
module.eks.module.eks_managed_node_group["default"].aws_launch_template.this[0]: Creation complete after 5s [id=lt-04de3cf043a03ae1f]
module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0]: Creating...
module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0]: Still creating... [00m10s elapsed]
module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0]: Still creating... [00m20s elapsed]
module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0]: Still creating... [00m30s elapsed]
module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0]: Still creating... [00m40s elapsed]
module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0]: Still creating... [00m50s elapsed]
module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0]: Still creating... [01m00s elapsed]
module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0]: Still creating... [01m10s elapsed]
module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0]: Still creating... [01m20s elapsed]
module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0]: Still creating... [01m30s elapsed]
module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0]: Still creating... [01m40s elapsed]
module.eks.module.eks_managed_node_group["default"].aws_eks_node_group.this[0]: Creation complete after 1m47s [id=devboard:default-79bae2f5fbef4580a3774820a6]
module.eks.aws_eks_addon.this["metrics-server"]: Creating...
module.eks.aws_eks_addon.this["coredns"]: Creating...
module.eks.aws_eks_addon.this["aws-ebs-csi-driver"]: Creating...
module.eks.aws_eks_addon.this["kube-proxy"]: Creating...
module.eks.aws_eks_addon.this["metrics-server"]: Still creating... [00m10s elapsed]
module.eks.aws_eks_addon.this["coredns"]: Still creating... [00m10s elapsed]
module.eks.aws_eks_addon.this["aws-ebs-csi-driver"]: Still creating... [00m10s elapsed]
module.eks.aws_eks_addon.this["kube-proxy"]: Still creating... [00m10s elapsed]
module.eks.aws_eks_addon.this["metrics-server"]: Still creating... [00m20s elapsed]
module.eks.aws_eks_addon.this["coredns"]: Still creating... [00m20s elapsed]
module.eks.aws_eks_addon.this["aws-ebs-csi-driver"]: Still creating... [00m20s elapsed]
module.eks.aws_eks_addon.this["kube-proxy"]: Still creating... [00m20s elapsed]
module.eks.aws_eks_addon.this["coredns"]: Creation complete after 25s [id=devboard:coredns]
module.eks.aws_eks_addon.this["kube-proxy"]: Creation complete after 25s [id=devboard:kube-proxy]
module.eks.aws_eks_addon.this["metrics-server"]: Still creating... [00m30s elapsed]
module.eks.aws_eks_addon.this["aws-ebs-csi-driver"]: Still creating... [00m30s elapsed]
module.eks.aws_eks_addon.this["aws-ebs-csi-driver"]: Creation complete after 35s [id=devboard:aws-ebs-csi-driver]
module.eks.aws_eks_addon.this["metrics-server"]: Still creating... [00m40s elapsed]
module.eks.aws_eks_addon.this["metrics-server"]: Still creating... [00m50s elapsed]
module.eks.aws_eks_addon.this["metrics-server"]: Creation complete after 55s [id=devboard:metrics-server]
kubernetes_storage_class_v1.gp3: Creating...
helm_release.argocd[0]: Creating...
kubernetes_storage_class_v1.gp3: Creation complete after 2s [id=gp3]
helm_release.argocd[0]: Still creating... [00m10s elapsed]
helm_release.argocd[0]: Still creating... [00m20s elapsed]
helm_release.argocd[0]: Still creating... [00m30s elapsed]
helm_release.argocd[0]: Still creating... [00m40s elapsed]
helm_release.argocd[0]: Still creating... [00m50s elapsed]
helm_release.argocd[0]: Still creating... [01m00s elapsed]
helm_release.argocd[0]: Creation complete after 1m4s [id=argocd]

Apply complete! Resources: 83 added, 0 changed, 0 destroyed.

Outputs:

argocd_initial_password = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
cluster_endpoint = "https://DEE55C0209AB28E15DA00FCFFFA01879.sk1.us-west-2.eks.amazonaws.com"
cluster_name = "devboard"
cluster_version = "1.34"
configure_kubectl = "aws eks update-kubeconfig --name devboard --region us-west-2"
external_secrets_role_arn = "arn:aws:iam::899805259876:role/devboard-external-secrets-ab2373b1bdfda33e4275bad06e"
oidc_provider_arn = "arn:aws:iam::899805259876:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/DEE55C0209AB28E15DA00FCFFFA01879"
postgres_secret_arn = "arn:aws:secretsmanager:us-west-2:899805259876:secret:devboard/postgres-qhadDt"
postgres_secret_name = "devboard/postgres"
private_subnets = [
  "subnet-0450e6bbf2da30a5b",
  "subnet-0cb6319fb99a3735b",
  "subnet-0cb7c43e9eceeee08",
]
public_subnets = [
  "subnet-087169b2103b1b2bc",
  "subnet-0021c29d418decc4e",
  "subnet-0842aeea1a86216ff",
]
set_postgres_secret = <<EOT
PGPASS=$(openssl rand -hex 32)
aws secretsmanager put-secret-value \
  --secret-id devboard/postgres \
  --region us-west-2 \
  --secret-string "$(jq -nc --arg p "$PGPASS" \
      '{username:"devboard", password:$p, dbname:"devboard"}')"

EOT
vpc_id = "vpc-03be02b07ff17c314"
```
While it runs, read the four files that matter:

- **[`vpc.tf`](../terraform/vpc.tf)** — three subnet tiers with three different
  jobs. Public holds the NLB. Private holds your nodes, which reach the
  internet outward through NAT but cannot be reached inward. Intra has no
  internet route at all and holds the EKS control plane ENIs.
- **[`eks.tf`](../terraform/eks.tf)** — the cluster and its node group.
- **[`pod-identity.tf`](../terraform/pod-identity.tf)** — how a pod gets AWS
  permissions without a single access key.
- **[`storage.tf`](../terraform/storage.tf)** — the StorageClass, and why this
  chapter no longer contains a `kubectl patch` step.

## Three things worth stopping on

### 1. One NAT Gateway, not three

```hcl
single_nat_gateway = true
```

Without that line the VPC module creates one NAT Gateway per availability zone:
3 × $0.045/hr ≈ **$98/month**, before data charges. One is ≈ $33/month.

The trade-off is real, and do not copy this to production: all egress from all
three AZs now flows through a single AZ. Lose that AZ and every node loses
outbound internet — image pulls included — even though the nodes themselves are
perfectly healthy.

### 2. `disk_size` is silently ignored

```hcl
block_device_mappings = {
  xvda = { device_name = "/dev/xvda", ebs = { volume_size = 30, ... } }
}
```

In EKS module v21 the module builds a custom launch template by default, and
`disk_size` only applies when it doesn't. Set `disk_size` and it looks like it
worked — you just quietly get the AMI default instead. This is a top-three
"worked in v20, broke in v21" report.

### 3. There is no `kubectl patch storageclass` step any more

The old chapter ended with this:

```bash
# NO LONGER NEEDED
kubectl patch storageclass gp2 -p '{"metadata":{"annotations":{...}}}'
```

An imperative, easy-to-skip command whose only symptom when forgotten is a
PersistentVolumeClaim stuck `Pending` forever. **This project got bitten by
exactly that** — Postgres named its class explicitly and survived; the Ollama
PVC did not and silently never started, taking the AI assistant down while
every health check stayed green.

So the StorageClass is now infrastructure, declared in
[`storage.tf`](../terraform/storage.tf), and it uses `gp3`:

- cheaper — $0.08/GiB-month vs gp2's $0.10
- 3000 IOPS and 125 MB/s baseline at **any** size. gp2 ties IOPS to volume
  size, so a 1 GiB Postgres volume gets 3 IOPS and a burst balance.

Note `volume_binding_mode: WaitForFirstConsumer`. This is not optional on a
multi-AZ cluster: with immediate binding the CSI driver picks the volume's AZ
*before* the scheduler picks a node, and an EBS volume cannot cross AZs — so
roughly two times in three the pod is unschedulable forever, with an error that
blames affinity rather than binding order.

## Verify

```bash
aws eks update-kubeconfig --name devboard --region us-west-2
root@ip-20-0-1-248:/opt/devboard/terraform# aws eks update-kubeconfig --name devboard --region us-west-2
Added new context arn:aws:eks:us-west-2:899805259876:cluster/devboard to /root/.kube/config
```
```bash
kubectl get nodes                     # 3 Ready, and note the private IPs
root@ip-20-0-1-248:/opt/devboard/terraform# kubectl get nodes 
NAME                                       STATUS   ROLES    AGE     VERSION
ip-10-0-4-64.us-west-2.compute.internal    Ready    <none>   8m35s   v1.34.9-eks-254016e
ip-10-0-5-195.us-west-2.compute.internal   Ready    <none>   8m35s   v1.34.9-eks-254016e
ip-10-0-6-86.us-west-2.compute.internal    Ready    <none>   8m27s   v1.34.9-eks-254016e
```
```bash
kubectl get storageclass              # gp3 (default) — with no patching
root@ip-20-0-1-248:/opt/devboard/terraform# kubectl get storageclass 
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
gp2             kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false                  14m
gp3 (default)   ebs.csi.aws.com         Delete          WaitForFirstConsumer   true                   7m13s
```
```bash
kubectl -n kube-system get pods | grep -E 'ebs-csi|metrics-server|pod-identity'
[root@ip-20-0-1-248:/opt/devboard/terraform# kubectl -n kube-system get pods | grep -E 'ebs-csi|metrics-server|pod-identity'
ebs-csi-controller-7c45d9d4d8-xtvn9   6/6     Running   0          8m18s
ebs-csi-controller-7c45d9d4d8-zhgxp   6/6     Running   0          8m18s
ebs-csi-node-c4dpk                    3/3     Running   0          8m18s
ebs-csi-node-kw55g                    3/3     Running   0          8m18s
ebs-csi-node-szjh5                    3/3     Running   0          8m18s
eks-pod-identity-agent-8jwl2          1/1     Running   0          9m8s
eks-pod-identity-agent-nmgh4          1/1     Running   0          9m16s
eks-pod-identity-agent-tn88w          1/1     Running   0          9m16s
metrics-server-84d74c6fff-8t622       1/1     Running   0          8m22s
metrics-server-84d74c6fff-rhp45       1/1     Running   0          8m22s
```

```hcl
terraform output
root@ip-20-0-1-248:/opt/devboard/terraform# terraform output
argocd_initial_password = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
cluster_endpoint = "https://DEE55C0209AB28E15DA00FCFFFA01879.sk1.us-west-2.eks.amazonaws.com"
cluster_name = "devboard"
cluster_version = "1.34"
configure_kubectl = "aws eks update-kubeconfig --name devboard --region us-west-2"
external_secrets_role_arn = "arn:aws:iam::899805259876:role/devboard-external-secrets-ab2373b1bdfda33e4275bad06e"
oidc_provider_arn = "arn:aws:iam::899805259876:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/DEE55C0209AB28E15DA00FCFFFA01879"
postgres_secret_arn = "arn:aws:secretsmanager:us-west-2:899805259876:secret:devboard/postgres-qhadDt"
postgres_secret_name = "devboard/postgres"
private_subnets = [
  "subnet-0450e6bbf2da30a5b",
  "subnet-0cb6319fb99a3735b",
  "subnet-0cb7c43e9eceeee08",
]
public_subnets = [
  "subnet-087169b2103b1b2bc",
  "subnet-0021c29d418decc4e",
  "subnet-0842aeea1a86216ff",
]
set_postgres_secret = <<EOT
PGPASS=$(openssl rand -hex 32)
aws secretsmanager put-secret-value \
  --secret-id devboard/postgres \
  --region us-west-2 \
  --secret-string "$(jq -nc --arg p "$PGPASS" \
      '{username:"devboard", password:$p, dbname:"devboard"}')"

EOT
vpc_id = "vpc-03be02b07ff17c314"
```

Keep `configure_kubectl` and `set_postgres_secret` handy — chapter 06 uses the
second one.

## If Terraform ever gets stuck on the cluster

`storage.tf` uses the Kubernetes provider, so Terraform now depends on the
cluster API being reachable. If your credentials break and that blocks a plan
or destroy, the escape hatch is:

```bash
terraform state rm kubernetes_storage_class_v1.gp3
```

---

Next: [04-gateway-api.md](04-gateway-api.md) — get a public URL.
