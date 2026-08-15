output "instance_ids" {
  description = "IDs of Bastion EC2 instances."
  value       = aws_instance.ssh.id
}

output "public_ips" {
  description = "Public IPs of the bastion server."
  value       = aws_instance.ssh.public_ip
}

output "ami_id" {
  description = "The UbuntuAMI resolved via the data source."
  value       = data.aws_ami.ubuntu.id
}