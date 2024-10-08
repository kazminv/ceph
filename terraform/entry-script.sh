#!/bin/bash
yum update -y
yum install -y docker
service docker start
usermod -aG docker ec2-user
docker run -p 8080:80 -d --restart unless-stopped nginx