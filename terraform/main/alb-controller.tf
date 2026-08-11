# IMPORTANT: verify this is still current before applying —
# https://github.com/aws/eks-charts/blob/master/stable/aws-load-balancer-controller/Chart.yaml
# Confirmed 3.5.0 by directly fetching that file's contents on 2026-08-11
# (not a remembered/guessed number — the source repo's own Chart.yaml
# reported version: 3.5.0, appVersion: v3.5.0).
variable "alb_controller_chart_version" {
  description = "Version of the aws-load-balancer-controller chart to deploy"
  type        = string
  default     = "3.5.0"
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.alb_controller_chart_version
  namespace  = "kube-system"

  values = [
    yamlencode({
      clusterName = aws_eks_cluster.main.name
      region      = var.aws_region
      vpcId       = aws_vpc.main.id

      serviceAccount = {
        create = true
        # Explicitly pinned — do NOT rely on the chart's auto-generated
        # fullname here. The IRSA trust policy in irsa-alb.tf hardcodes
        # this exact name; if the two drift, the controller can't
        # authenticate to AWS (same class of bug that broke carts/
        # catalog/orders earlier in this build).
        name = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
        }
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.alb_controller,
    aws_eks_node_group.main,
  ]
}
