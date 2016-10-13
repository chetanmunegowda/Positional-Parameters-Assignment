#!/bin/bash

if [ $# -ne 5 ]; then
 echo "Your command line contains $# arguments. But the script need 5 arguments in the folowing order --AMI ID --KEY-NAME --SECURITY-GROUP --LAUNCH-CONFIGURATION --COUNT"
else
 echo "Below are the arguments given"
 echo "--AMI ID = " $1
 echo "--key-name = " $2
 echo "--security-group = " $3
 echo "--launch-configuration = " $4
 echo "--count = " $5
 read -p "Are you sure to continue with these values? " -n 1 -r
 echo    # (optional) move to a new line
 if [[ $REPLY =~ ^[Yy]$ ]]
  then
   ami_id=$1
   key_name=$2
   security_group_id=$3
   launch_configuration=$4
   count=$5

   echo "creating $count ec2 instances"
   
   aws ec2 run-instances --image-id $ami_id --key-name $key_name --security-group-ids $security_group_id --instance-type t2.micro --count $count --user-data file://hello.sh

  instances=`aws ec2 describe-instances --query 'Reservations[*].Instances[].InstanceId'`

  echo "instances in pending state: " $instances
 
  aws ec2 wait instance-running --instance-id $instances 

  echo "instances now in running state: " $instances

  echo "creating load balancer"

  aws elb create-load-balancer --load-balancer-name load-balancer-1 --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" --subnets subnet-c33376b5 --security-groups $security_group_id

 loadBalancer=`aws elb describe-load-balancers --query LoadBalancerDescriptions[*].LoadBalancerName`

  echo "load balancer $loadBalancer is created" 

  echo "registering instances with load balancer"

  aws elb register-instances-with-load-balancer --load-balancer-name $loadBalancer --instances $instances

  echo "creating launch configuration"

  aws autoscaling create-launch-configuration --launch-configuration-name $launch_configuration --image-id $ami_id --key-name $key_name --instance-type t2.micro --user-data file://hello.sh

  launchConfiguration=`aws autoscaling describe-launch-configurations --query LaunchConfigurations[*].LaunchConfigurationName`

  echo "launch configuration $launchConfiguration is created"

  echo "creating autoscaling group"

  aws autoscaling create-auto-scaling-group --auto-scaling-group-name auto-scaling-group-1 --launch-configuration-name $launch_configuration --availability-zone us-west-2b --load-balancer-names $loadBalancer --min-size 1 --max-size 3 --desired-capacity 2 
  
  autoScalingGroupName=`aws autoscaling describe-auto-scaling-groups --query AutoScalingGroups[*].AutoScalingGroupName`

  echo "autoscaling group $autoScalingGroupName is created"
  
 fi 
fi
