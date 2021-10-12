# sre-bootcamp-deliverable2

The purpose of this repo is to describe the work done for the SRE-BOOTCAMP - deliverable2 

### Evaluation aspects 

* The initial infrastructure diagram.
* The diagram of the infrastructure that you developed.
* The improvements that you implemented, as well as a logical and reasonable justification for your improvements.
* The ownership of creating the infrastructure.
* The functionality of the application.
* The correct functioning of the application.

## Initial Infrastructure 
The initial application is a web application which returns the following message when the port 80 is reached 
> Welcome to the 2nd part of your Capstone Project!

To serve the application there is a load balancer in front of two static instances of EC2 with the application. 

The user can reach directly both instances which have public access to the following ports:
* 80 -- for web application 
* 22 -- for ssh 

### Initial infrastructure diagram

![Alt text](images/initial_infrastructure.png?raw=true "Original Infrastructure")


## Proposed infrastructure
Possible improvements to the initial infrastructure:
* Improve scalability of the web application
* Reduce/remove the public facing traffic to the applications that is not needed 
* Implementation of security best practices to access cloud services

For my implementation I have prefered the use of serverless [[1]](#1) resources because of the following reasons:
* Easier scalability capabilities   
* The actual cost depends on the demand of the application
* The underlaying infrastructure and configuration is administered by AWS 
* The access to different resorces can be managed only using IAM roles [[2]](#2)

### List of resources used 
* S3 bucket
* Lambda 
* Secret manager
* Elastic Container Registry
* App Runner 
* DynamoDB 
* cloudcraft (for diagrams)


### What is App Runner and why I am using it? 
App Runner[[3]](#3) is a rather new service from AWS, it enables the deployment of source code from github or docker images from ECR to a self managed ECS cluster. 
It is actually using Fargate in the background.
Main advantages:
* Easier to configure/use in comparison to fargate or ECS.
* TLS connection by default for the deployed application.
* Reduced vendor locking if you are using docker containers.
* Automatic autoscale from the app runner service configuration.
* Automaticly load balanced.
* The only way to provide access to aws service is using IAM roles.

Disadvantages:
* A bit more expensive in comparison to ECS.
* It can't be scaled to a 0 instance like Google Cloud Run. [[4]](#4)
* It can't access all the AWS services as off now.
* Can't be configured using VPC.

For me the main advantage is the default TLS connection to ensure security by default, the same applies to the use of the IAM roles. 

### How did I implement it?
I am using the application from the deliverable 1, the difference is that I have created a branch to consume DynamoDB, and retrieve the JWT encryption key from AWS parameter store.
* The docker image used for this implementation is - latoz/academy-sre-bootcamp-luis-torres:dynamo.
* All the infrastructure was described using a terraform template.
* The application was deployed using app runner, the initial autoscaling configuration only creates 2 instances.
* Any access to the services is described uing IAM policies and Roles.
* The S3 bucket is only used to initialize the database:
    * It has a lambda trigger when a new file is uploaded, that file has the data from the wizeline database used by the deliverable 1.
    * When the lambda is triggered it takes the json file from the s3 bucket and then puts the items to dynamodb.

All the created resources have the following tags: 
* project = "deliverable2"
* mentee  = "LuisAngelTorres"


### Pendings:
* After the data is initialized and actually stored in the dynamodb I am not removing the no longer resources 

## New infrastructure deployment 
* Clone this repository 
* change if needed the terraform aws provider block from main.tf 
```
terraform init
terraform apply 
```
The entire deployment takes around 5-8 minutes to complete 
The last output line from terraform is the link to the application 



### Proposed infrastructure diagram
![Alt text](images/proposed_infrastructure.png?raw=true "Proposed Infrastructure")


## REFERENCES:

<a id="1">[1]</a>
https://www.cloudflare.com/learning/serverless/why-use-serverless/

https://aws.amazon.com/es/serverless/

<a id="2">[2]</a>
https://docs.aws.amazon.com/es_es/IAM/latest/UserGuide/id_roles.html

<a id="3">[3]</a>
https://aws.amazon.com/apprunner

<a id="4">[4]</a>
https://cloud.google.com/run/docs/about-instance-autoscaling