# BG_Terraform

##  **Prerequisites**
Ensure you have the following installed:
- **Terraform** 
- **AWS CLI** 
- **Git** 

🔹 **IAM Permissions Required:**
- Permissions to create VPC, ECS, RDS, and Auto Scaling resources.

---

##  **Project Structure**
To run the solution 
- clone the repository 
- run terraform init 
- run terraform plan 
- run terraform apply --auto-approve

## **What is being created**

This setup creates an ECS cluster with three EC2 instances, each hosted in different subnets and availability zones. A PostgreSQL database is deployed in a separate subnet, accessible only by the ECS cluster's EC2 instances. An Application Load Balancer (ALB) is placed in front of the ECS instances for traffic distribution. The ECS instances use an ECS-optimized AMI and are managed by an Auto Scaling Group. As the base docker image was used kennethreitz/httpbin . 
Code also deploys EC2 bastion host on public subnet which can be used for troubleshooting purposes and access to private EC2 instances. 



