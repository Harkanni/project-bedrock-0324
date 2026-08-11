# --- IRSA: AWS Load Balancer Controller -------------------------------
# The controller runs in kube-system, not retail-app — it's a
# cluster-wide piece of infrastructure, not part of the application.

resource "aws_iam_role" "alb_controller" {
  name = "project-bedrock-alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

# Official policy document, pulled directly from the controller's own
# GitHub repo (kubernetes-sigs/aws-load-balancer-controller) rather than
# hand-written — this policy is long and precise (251 lines), and a
# hand-reconstructed version risks subtly missing a required permission.
resource "aws_iam_policy" "alb_controller" {
  name   = "project-bedrock-alb-controller-policy"
  policy = file("${path.module}/alb_iam_policy.json")
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}
