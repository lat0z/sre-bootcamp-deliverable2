# https://docs.aws.amazon.com/es_es/lambda/latest/dg/with-s3-example.html 
# https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies.html
# https://www.apprunnerworkshop.com/intermediate/container-image/create-service/

terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 3.61"
        }
        archive = {
            source  = "hashicorp/archive"
            version = "~> 2.2.0"
        }
        null = {
            source = "hashicorp/null"
            version = "~>3.1.0"
        }
        time = {
            source = "hashicorp/time"
            version = "~>0.7.2"
        }
    }
}

provider "aws" {
    profile = "default" 
    region = "us-west-2"
}

provider "archive" {}

data "aws_region" "current" {}

variable "general_tags"{
  type = map(string)
  default = {
    project = "deliverable2"
    mentee  = "LuisAngelTorres"
  }
}

resource "aws_s3_bucket" "integration-bucket" {
    bucket  = "dynamo-init-bucket"
    acl     = "private"
    tags    = var.general_tags
    force_destroy = true
}

resource "aws_dynamodb_table" "users" {
    name            = "users"
    hash_key        = "username"
    billing_mode    = "PAY_PER_REQUEST"
    stream_enabled  = false
    tags            = var.general_tags
    attribute {
        name = "username"
        type = "S"
    }
}   

data "archive_file" "init" {
    type        = "zip"
    source_file = "${path.module}/dynamo_function.py"
    output_path = "${path.module}/dynamo_function_payload.zip"
}

resource "aws_iam_policy" "iam_policy_for_lambda" {
    name    = "lambda-access-policy"
    tags    = var.general_tags
    policy  = jsonencode({
        Version     = "2012-10-17"
        Statement   = [
            {
                Effect= "Allow"
                Action= ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"]
                Resource= ["*"]
            },
            {
                Effect= "Allow"
                Action= ["s3:GetObject"]
                Resource= ["${aws_s3_bucket.integration-bucket.arn}/*"]
            },
            {
                Effect= "Allow"
                Action= ["dynamodb:PutItem"]
                Resource= [aws_dynamodb_table.users.arn]
            }
        ]
    })
}

resource "aws_iam_policy" "iam_policy_for_app_runner"{
    name    = "app-runner-access-policy2"
    tags    = var.general_tags
    policy  = jsonencode({
        Version     = "2012-10-17"
        Statement   = [
            {
                Effect= "Allow"
                Action= [
                    "dynamodb:GetItem",
                    "dynamodb:Query",
                    "secretsmanager:GetSecretValue"
                ]
                
                Resource= [
                    aws_dynamodb_table.users.arn,
                    #"arn:aws:secretsmanager:${data.aws_region.current.name}:"
                    "${aws_secretsmanager_secret.key.arn}"
                    
                ] 
            }
        ]
    })
}

resource "aws_iam_policy" "iam_access_policy_private_ecr"{
    name    = "app-runner-private-ecr-access-policy"
    tags    = var.general_tags
    policy  = jsonencode({
        Version     = "2012-10-17"
        Statement   = [
            {
                Effect= "Allow"
                Action= [
                    "ecr:*"
                ]
                
                Resource= ["*"] 
            }
        ]
    })
}

variable "secret" {
    default = {
        encryption_key = "my2w7wjd7yXF64FIADfJxNs1oupTGAuW"
    }
    type = map(string)
}

resource "aws_secretsmanager_secret" "key" {
  name = "encryption_key"
  tags = var.general_tags
}

resource "aws_secretsmanager_secret_version" "secret_encryption" {
  secret_id     = aws_secretsmanager_secret.key.id
  secret_string = jsonencode(var.secret)
}

resource "aws_iam_role" "iam_role_for_lambda" {
    name                = "my-s3-lambda-function-role"
    tags                = var.general_tags
    assume_role_policy  = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action= "sts:AssumeRole"
                Effect= "Allow"
                Sid=""
                Principal= {
                    Service= "lambda.amazonaws.com"
                }

            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "lambda-policy-attach" {
  role = "${aws_iam_role.iam_role_for_lambda.name}"
  policy_arn = "${aws_iam_policy.iam_policy_for_lambda.arn}"
}

resource "aws_iam_role" "iam_role_for_apprunner" {
    name                = "my-app-runner-container-role"
    tags                = var.general_tags
    assume_role_policy  = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action= "sts:AssumeRole"
                Effect= "Allow"
                Sid=""
                Principal= {
                    Service= "tasks.apprunner.amazonaws.com"
                }

            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "app-runner-policy-attach" {
  role = "${aws_iam_role.iam_role_for_apprunner.name}"
  policy_arn = "${aws_iam_policy.iam_policy_for_app_runner.arn}"
}

resource "aws_iam_role" "iam_role_for_private_ecr_apprunner" {
    name                = "my-private-ecr-access-role"
    tags                = var.general_tags
    assume_role_policy  = jsonencode({
        Version = "2012-10-17"  
        Statement = [
            {
                Action= "sts:AssumeRole"
                Effect= "Allow"
                Sid=""
                Principal= {
                    Service= "build.apprunner.amazonaws.com"
                }

            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "private-ecr-policy-attach" {
  role = "${aws_iam_role.iam_role_for_private_ecr_apprunner.name}"
  policy_arn = "${aws_iam_policy.iam_access_policy_private_ecr.arn}"
}


resource "aws_lambda_function" "test_lambda" {
    filename            = "dynamo_function_payload.zip"
    source_code_hash    = "${data.archive_file.init.output_base64sha256}"
    function_name       = "test_lambda"
    role                = aws_iam_role.iam_role_for_lambda.arn
    tags                = var.general_tags
    runtime             = "python3.9"
    handler             = "dynamo_function.lambda_handler"
}

resource "aws_lambda_permission" "lambda_permission" {
    action= "lambda:InvokeFunction"
    function_name = aws_lambda_function.test_lambda.arn
    principal = "s3.amazonaws.com"
    source_arn = aws_s3_bucket.integration-bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification"{
    bucket = aws_s3_bucket.integration-bucket.id
    lambda_function {
        lambda_function_arn = aws_lambda_function.test_lambda.arn
        events = ["s3:ObjectCreated:*"]
    }
    depends_on = [aws_lambda_permission.lambda_permission]
}

resource "aws_ecr_repository" "registry" {
    name         = "luis_angel_deliverable2"
    image_tag_mutability = "MUTABLE"
    tags = var.general_tags
    image_scanning_configuration {
    scan_on_push = false
  }
}

resource "null_resource" "docker_image" {
    provisioner "local-exec" {
        interpreter = ["/bin/bash" ,"-c"]
        command = <<-EOT
            docker pull latoz/academy-sre-bootcamp-luis-torres:dynamo
            export ECR_PRIVATE="${aws_ecr_repository.registry.repository_url}"
            export AWS_ECR_PASSWORD=$(aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin "$ECR_PRIVATE")
            docker tag latoz/academy-sre-bootcamp-luis-torres:dynamo "$ECR_PRIVATE"
            docker push "$ECR_PRIVATE"

            
        EOT
    }
#    depends_on = [aws_ecr_repository.registry]
}

resource "time_sleep" "delay" {
  create_duration = "200s"
  depends_on=[
    aws_s3_bucket_notification.bucket_notification,
    aws_lambda_permission.lambda_permission,
    aws_iam_role_policy_attachment.lambda-policy-attach
  ]
}

resource "aws_s3_bucket_object" "object" {
    bucket  = aws_s3_bucket.integration-bucket.id
    key     = "dynamodata.json"
    acl     = "private"
    source  = "${path.module}/usersdata.json"
    depends_on = [time_sleep.delay]
}


resource "aws_apprunner_auto_scaling_configuration_version" "deliverable2demo" {
    auto_scaling_configuration_name = "sre-bootcamp-demo"
    max_concurrency                 = 10
    max_size                        = 2
    min_size                        = 1
    
    tags = {
        Name = "sre-bootcamp-demo"
    }
}


resource "aws_apprunner_service" "deliverable2demo" {
    auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.deliverable2demo.arn
    service_name = "deliverable2demo"

    source_configuration {
        authentication_configuration {
            access_role_arn = aws_iam_role.iam_role_for_private_ecr_apprunner.arn
        }
        auto_deployments_enabled = false
        image_repository {
            image_configuration {
                port = "8000"
            }
            image_identifier        = "${aws_ecr_repository.registry.repository_url}:latest" 
            image_repository_type   = "ECR"
        }
    }

    instance_configuration {
        instance_role_arn = aws_iam_role.iam_role_for_apprunner.arn 
    }

    tags = var.general_tags
    depends_on = [null_resource.docker_image, aws_iam_role.iam_role_for_apprunner, aws_iam_role.iam_role_for_private_ecr_apprunner]
}

output "service-url" {
  value = aws_apprunner_service.deliverable2demo.service_url
}
