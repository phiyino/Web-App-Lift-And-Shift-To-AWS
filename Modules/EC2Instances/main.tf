# Create database server 
resource "aws_instance" "db-server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_pair

  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.backend_sg_id]
  associate_public_ip_address = true
  availability_zone = "us-east-1a"

  user_data = <<-EOF
  #!/bin/bash
  DATABASE_PASS='admin123'
  sudo yum update -y
  sudo yum install epel-release -y
  sudo yum install git zip unzip -y
  sudo yum install mariadb-server -y

  # starting & enabling mariadb-server
  sudo systemctl start mariadb
  sudo systemctl enable mariadb
  cd /tmp/
  git clone -b vp-rem https://github.com/devopshydclub/vprofile-repo.git
  #restore the dump file for the application
  sudo mysqladmin -u root password "$DATABASE_PASS"
  sudo mysql -u root -p"$DATABASE_PASS" -e "UPDATE mysql.user SET Password=PASSWORD('$DATABASE_PASS') WHERE User='root'"
  sudo mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
  sudo mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.user WHERE User=''"
  sudo mysql -u root -p"$DATABASE_PASS" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
  sudo mysql -u root -p"$DATABASE_PASS" -e "FLUSH PRIVILEGES"
  sudo mysql -u root -p"$DATABASE_PASS" -e "create database accounts"
  sudo mysql -u root -p"$DATABASE_PASS" -e "grant all privileges on accounts.* TO 'admin'@'localhost' identified by 'admin123'"
  sudo mysql -u root -p"$DATABASE_PASS" -e "grant all privileges on accounts.* TO 'admin'@'%' identified by 'admin123'"
  sudo mysql -u root -p"$DATABASE_PASS" accounts < /tmp/vprofile-repo/src/main/resources/db_backup.sql
  sudo mysql -u root -p"$DATABASE_PASS" -e "FLUSH PRIVILEGES"

  # Restart mariadb-server
  sudo systemctl restart mariadb

  #starting the firewall and allowing the mariadb to access from port no. 3306
  sudo systemctl start firewalld
  sudo systemctl enable firewalld
  sudo firewall-cmd --get-active-zones
  sudo firewall-cmd --zone=public --add-port=3306/tcp --permanent
  sudo firewall-cmd --reload
  sudo systemctl restart mariadb

 EOF

 tags = {
   Name = "${var.project_name}-db01"
 }

}

# Create Memcache instance 
resource "aws_instance" "memcache" {
  ami           = "${var.ami_id}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_pair}"

  subnet_id                   = "${var.private_subnet_id}"
  vpc_security_group_ids      = [var.backend_sg_id]
  associate_public_ip_address = true
  availability_zone = "us-east-1a"

  user_data = <<-EOF
  #!/bin/bash
  sudo yum install epel-release -y
  sudo yum install memcached -y
  sudo systemctl start memcached
  sudo systemctl enable memcached
  sudo systemctl status memcached
  sudo memcached -p 11211 -U 11111 -u memcached -d

 EOF

 tags = {
   Name = "${var.project_name}-mc01"
 }

}

# Create RabbitMQ instance 
resource "aws_instance" "rabbitmq" {
  ami           = "${var.ami_id}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_pair}"

  subnet_id                   = "${var.private_subnet_id}"
  vpc_security_group_ids      = [var.backend_sg_id]
  associate_public_ip_address = true
  availability_zone = "us-east-1a"

  user_data = <<-EOF
  #!/bin/bash
  sudo yum install epel-release -y
  sudo yum update -y
  sudo yum install wget -y
  cd /tmp/
  wget http://packages.erlang-solutions.com/erlang-solutions-2.0-1.noarch.rpm
  sudo rpm -Uvh erlang-solutions-2.0-1.noarch.rpm
  sudo yum -y install erlang socat
  curl -s https://packagecloud.io/install/repositories/rabbitmq/rabbitmq-server/script.rpm.sh | sudo bash
  sudo yum install rabbitmq-server -y
  sudo systemctl start rabbitmq-server
  sudo systemctl enable rabbitmq-server
  sudo systemctl status rabbitmq-server
  sudo sh -c 'echo "[{rabbit, [{loopback_users, []}]}]." > /etc/rabbitmq/rabbitmq.config'
  sudo rabbitmqctl add_user test test
  sudo rabbitmqctl set_user_tags test administrator
  sudo systemctl restart rabbitmq-server
 EOF

 tags = {
   Name = "${var.project_name}-rmq01"
 }

}

# Create web server 
resource "aws_instance" "tomcat" {
  ami           = "${var.ami_ubuntu}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.key_pair}"
  iam_instance_profile = aws_iam_instance_profile.ec2_s3_instance_profile.name

  subnet_id                   = "${var.public_subnet_id}"
  vpc_security_group_ids      = [var.tomcat_sg_id]
  associate_public_ip_address = true
  availability_zone = "us-east-1a"

  user_data = <<-EOF
  #!/bin/bash
  sudo apt update
  sudo apt upgrade -y
  sudo apt install openjdk-8-jdk -y
  sudo apt install tomcat9 tomcat9-admin tomcat9-docs tomcat9-common git -y

 EOF

 tags = {
   Name = "${var.project_name}-app01"
 }

}

# create iam role
resource "aws_iam_role" "ec2_s3_role" {
  name = "EC2S3AccessRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# create iam policy
resource "aws_iam_policy" "s3_access_policy" {
  name        = "S3FullAccess"
  description = "Provides full access to all buckets via the AWS Management Console."
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:*",
          "s3-object-lambda:*"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# attach permission to role
resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  policy_arn = aws_iam_policy.s3_access_policy.arn
  role       = aws_iam_role.ec2_s3_role.name
}

# for attaching role to ec2 instance
resource "aws_iam_instance_profile" "ec2_s3_instance_profile" {
  name = "EC2S3AccessProfile"
  role = aws_iam_role.ec2_s3_role.name
}