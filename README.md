# Hi there!
this project provisions aws infrastructures using terraform, in this project we're storing the terraform.tfstate in an s3 bucket that allows for easier collaboration btw developers and we also enabled state locking to disable simultaneous updates of the .tfstate file

<br>
<br>

# Running the application
0. export your aws_access_key and aws_secret_key
    - export AWS_ACCESS_KEY_ID=<your_access_key>
    - export AWS_SECRET_ACCESS_KEY=<your_secret_key>
1. terraform init
2. terraform plan
3. terraform apply

<br>
<br>

# Resources in this project
- 1 aws vpc

- 2 aws subnets

- 1 aws internet gateway

- 1 aws route table: it routes all the traffic to the internet gateway

- 2 aws_route_table_association resource: connects both of the subnets to the route_table so that they can be accessed from the web

- 1 aws security group for the aws EC2 instances
    - ingress rule that allows traffic from port:22 (for ssh_connection)
    - ingress rule that allows traffic from port:80 (for http connection) 
    - ingress rule that allows traffic from port:8080 (for http connection)

- 1 aws key pair: used to ssh into the EC2 instance

- 1 data aws_ami resource: used to dynamically fetch an ami image that is owned by amazon and will be used in the EC2 instances

- 2 EC2 instances: we configured the EC2 instance with user_data, using an entry_script.sh
    - the entry_script.sh installs apache and starts the apache server to listen for incoming request

- 1 S3 bucket: used to store the files from this application
    - configured to encrypt data that is stored on the bucket

- 1 load balancer: distributes the load across both subnets

- 1 aws_route53: configures a url to point to the load balancers

- 1 aws_db_instance: configures a postgres database for the application