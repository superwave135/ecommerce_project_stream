# CodeBuild Configuration
# CI/CD for Lambda and Glue deployments

# ============================================
# CodeBuild Project - Data Generator Lambda
# ============================================

resource "aws_codebuild_project" "data_generator" {
  name          = "${local.resource_prefix}-data-generator-build"
  description   = "Build and deploy data generator Lambda"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 10
  
  artifacts {
    type = "NO_ARTIFACTS"
  }
  
  environment {
    compute_type                = var.codebuild_compute_type
    image                       = var.codebuild_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    
    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
  }
  
  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec       = "lambda/data_generator/buildspec.yml"
    
    git_submodules_config {
      fetch_submodules = false
    }
  }
  
  source_version = var.github_branch
  
  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild_data_generator.name
    }
  }
  
  tags = local.common_tags
}

# ============================================
# CodeBuild Project - Orchestrator Lambda
# ============================================

resource "aws_codebuild_project" "orchestrator" {
  name          = "${local.resource_prefix}-orchestrator-build"
  description   = "Build and deploy orchestrator Lambda"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 10
  
  artifacts {
    type = "NO_ARTIFACTS"
  }
  
  environment {
    compute_type                = var.codebuild_compute_type
    image                       = var.codebuild_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    
    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
  }
  
  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec       = "lambda/orchestrator/buildspec.yml"
    
    git_submodules_config {
      fetch_submodules = false
    }
  }
  
  source_version = var.github_branch
  
  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild_orchestrator.name
    }
  }
  
  tags = local.common_tags
}

# ============================================
# CodeBuild Project - Glue Job
# ============================================

resource "aws_codebuild_project" "glue_job" {
  name          = "${local.resource_prefix}-glue-job-build"
  description   = "Build and deploy Glue streaming job"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 10
  
  artifacts {
    type = "NO_ARTIFACTS"
  }
  
  environment {
    compute_type                = var.codebuild_compute_type
    image                       = var.codebuild_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    
    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }
  }
  
  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec       = "glue/jobs/buildspec.yml"
    
    git_submodules_config {
      fetch_submodules = false
    }
  }
  
  source_version = var.github_branch
  
  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild_glue.name
    }
  }
  
  tags = local.common_tags
}

# ============================================
# CloudWatch Log Groups for CodeBuild
# ============================================

resource "aws_cloudwatch_log_group" "codebuild_data_generator" {
  name              = "/aws/codebuild/${local.resource_prefix}-data-generator-build"
  retention_in_days = var.log_retention_days
  
  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "codebuild_orchestrator" {
  name              = "/aws/codebuild/${local.resource_prefix}-orchestrator-build"
  retention_in_days = var.log_retention_days
  
  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "codebuild_glue" {
  name              = "/aws/codebuild/${local.resource_prefix}-glue-job-build"
  retention_in_days = var.log_retention_days
  
  tags = local.common_tags
}

# ============================================
# GitHub Webhooks for CodeBuild (Optional)
# Note: GitHub webhooks need to be configured in GitHub UI or via GitHub API
# ============================================

resource "aws_codebuild_webhook" "data_generator" {
  project_name = aws_codebuild_project.data_generator.name
  
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
    
    filter {
      type    = "FILE_PATH"
      pattern = "lambda/data_generator/.*"
    }
    
    filter {
      type    = "HEAD_REF"
      pattern = "refs/heads/${var.github_branch}"
    }
  }
}

resource "aws_codebuild_webhook" "orchestrator" {
  project_name = aws_codebuild_project.orchestrator.name
  
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
    
    filter {
      type    = "FILE_PATH"
      pattern = "lambda/orchestrator/.*"
    }
    
    filter {
      type    = "HEAD_REF"
      pattern = "refs/heads/${var.github_branch}"
    }
  }
}

resource "aws_codebuild_webhook" "glue_job" {
  project_name = aws_codebuild_project.glue_job.name
  
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
    
    filter {
      type    = "FILE_PATH"
      pattern = "glue/jobs/.*"
    }
    
    filter {
      type    = "HEAD_REF"
      pattern = "refs/heads/${var.github_branch}"
    }
  }
}
