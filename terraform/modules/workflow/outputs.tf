# Workflow module outputs
# Requirements: 8.4

output "state_machine_arn" {
  description = "ARN of the Step Functions state machine"
  value       = aws_sfn_state_machine.data_pipeline.arn
}

output "state_machine_name" {
  description = "Name of the Step Functions state machine"
  value       = aws_sfn_state_machine.data_pipeline.name
}

output "step_functions_role_arn" {
  description = "ARN of the IAM role used by Step Functions"
  value       = aws_iam_role.step_functions.arn
}
