# beanstalk-docker-example

This is an example of a Docker application deployed via Elastic Beanstalk where the Docker containers mount a shared Elastic File System. It is an example of a containerized application that has access to content persisted beyond container lifetimes on EFS.

## Scenario

* A Docker application and configuration that runs it in Elastic Beanstalk. While the Docker container is a simple web server, it can stand in for a more complex containerized application that is managed in a Git repo.
* An Elastic File System (EFS) and necessary supporting infrastructure (e.g., mount targets, security groups) to persistently store content, outside of the Docker container (i.e. Git repo) context. This single EFS can be shared by any number of Docker containers.
* Configuration for Docker and Elastic Beanstalk to mount the EFS onto the EB EC2 instances and expose it to the Docker containers running therein.

## Prerequisites

* [Git client](https://git-scm.com/downloads) installed on your local system
* [AWS CLI installed](http://docs.aws.amazon.com/cli/latest/userguide/installing.html) and [AWS credentials](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-config-files) stored on your local system
* [AWS Elastic Beanstalk CLI](http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb-cli3.html) installed on your local system
* Privileges in an AWS account allowing creation of Elastic Beanstalk applications, Elastic File Systems, Security Groups, running Cloud Formation templates, etc.

## Instructions

1. Grab the repo and change to the repo directory.

 ```
 $ git clone git@github.com:CU-CommunityApps/beanstalk-docker-example.git
 Cloning into 'beanstalk-docker-example'...
 remote: Counting objects: 219, done.
 remote: Compressing objects: 100% (157/157), done.
 remote: Total 219 (delta 95), reused 0 (delta 0), pack-reused 33
 Receiving objects: 100% (219/219), 24.79 KiB | 0 bytes/s, done.
 Resolving deltas: 100% (109/109), done.
 Checking connectivity... done.
 $ cd beanstalk-docker-example
 ```
1. Setup Elastic Beanstalk for this application. Here, we indicate the following during initialization:
  * Use the AWS credentials in the "my-aws-profile" profile configured in ~/.aws/credentials.
  * Use us-east-1 region.
  * Use the default application name, beanstalk-docker-example.
  * Confirming this is a Docker application, version 1.11.1.
  * Setting up a new key-pair for access to any EC2 instances.

  ```
  $ eb init --profile my-aws-profile

  Select a default region
  1) us-east-1 : US East (N. Virginia)
  2) us-west-1 : US West (N. California)
  3) us-west-2 : US West (Oregon)
  4) eu-west-1 : EU (Ireland)
  5) eu-central-1 : EU (Frankfurt)
  6) ap-southeast-1 : Asia Pacific (Singapore)
  7) ap-southeast-2 : Asia Pacific (Sydney)
  8) ap-northeast-1 : Asia Pacific (Tokyo)
  9) ap-northeast-2 : Asia Pacific (Seoul)
  10) sa-east-1 : South America (Sao Paulo)
  11) cn-north-1 : China (Beijing)
  (default is 3): 1

  Enter Application Name
  (default is "beanstalk-docker-example"):
  Application beanstalk-docker-example has been created.

  It appears you are using Docker. Is this correct?
  (y/n): y

  Select a platform version.
  1) Docker 1.11.1
  2) Docker 1.9.1
  3) Docker 1.7.1
  4) Docker 1.6.2
  (default is 1): 1
  Do you want to set up SSH for your instances?
  (y/n): y

  Select a keypair.
  1) [ Create new KeyPair ]
  (default is 1): 11

  Type a keypair name.
  (Default is aws-eb): aws-eb
  Generating public/private rsa key pair.
  Enter passphrase (empty for no passphrase):
  Enter same passphrase again:
  Your identification has been saved in /Users/pea1/.ssh/aws-eb.
  Your public key has been saved in /Users/pea1/.ssh/aws-eb.pub.
  The key fingerprint is:
  SHA256:qYvEqanQbhUq7JmG2DQKqIGVuMsJKHwGJu8tkFqIBHE aws-eb
  The key's randomart image is:
  +---[RSA 2048]----+
  |..E              |
  |..               |
  |.. .             |
  |o+o .    .       |
  |@*.. .  S        |
  |/+*+.. .         |
  |%@B++ .          |
  |OO=+.. .         |
  |oo+.. .          |
  +----[SHA256]-----+
  WARNING: Uploaded SSH public key for "aws-eb" into EC2 for region us-east-1.
  ```
1. Collect the information we will need in order to run the CloudFormation template that creates the Elastic File System.
  * The ID of the VPC where the EFS will reside:
  * The IDs of two private subnets within that VPC:
    * private subnet 1:
    * private subnet 2:

  If you don't have these IDs on hand, open up the [VPC section of the AWS console](https://console.aws.amazon.com/vpc/home?region=us-east-1#) where it is straightforward to get this info.

  In the example these IDs are:
  * VPC: vpc-71070114
  * private subnet 1: subnet-7704a001
  * private subnet 2: subnet-dd8519f6

1. Run the (elastic-file-system.json)[cloud-formation/elastic-file-system.json] CloudFormation template to create the Elastic File System. Use whatever mechanism you wish (e.g., the [AWS console]([https://console.aws.amazon.com/cloudformation/home?region=us-east-1)). Beyond the parameters mention above, no other specific configuration or inputs are required.

  Wait until the stack is created. At that point take note of the OutputSecurityGroup Id and the OutputFileSystem Id produced in the stack output.

1. Edit the [example.config](.ebextensions/example.config) file on your local system, and replace the following placeholders with values for your system. For "Subnets" and "ELBSubnets" use the ids of the private subnets you collected above.

  ```yaml
  aws:autoscaling:launchconfiguration:
    # This should be replaced by the security group created by the EFS CloudFormation template.
    SecurityGroups: sg-e57b6f9e # REPLACE
  # ...
  aws:ec2:vpc:
    # This should be replaced by your Cornell VPC id.
    VPCId: vpc-71070114 # REPLACE
    # For example purposes, deploy both the EC2 instances and the ELB in your private subnets.
    Subnets: "subnet-7704a001,subnet-dd8519f6" # REPLACE
    ELBSubnets: "subnet-7704a001,subnet-dd8519f6" # REPLACE
  # ...
  aws:elasticbeanstalk:application:environment:
      # This should be replaced by the EFS created by the EFS CloudFormation template.
      TARGET_EFS_ID: fs-4a1adc03 # REPLACE
  ```
1. Create the first environment, example-test, for our EB application. This single CLI command will take several minutes to create the entire infrastructure.

  ```
  $ eb create example-test
  Creating application version archive "app-f0f6-160725_161133".
  Uploading beanstalk-docker-example/app-f0f6-160725_161133.zip to S3. This may take a while.
  Upload Complete.
  Environment details for: example-test
    Application name: beanstalk-docker-example
    Region: us-east-1
    Deployed Version: app-f0f6-160725_161133
    Environment ID: e-rshsspfm7f
    Platform: 64bit Amazon Linux 2016.03 v2.1.3 running Docker 1.11.1
    Tier: WebServer-Standard
    CNAME: UNKNOWN
    Updated: 2016-07-25 20:11:37.925000+00:00
  Printing Status:
  INFO: createEnvironment is starting.
  INFO: Using elasticbeanstalk-us-east-1-225162606092 as Amazon S3 storage bucket for environment data.
  INFO: Environment health has transitioned to Pending. Initialization in progress (running for 30 seconds). There are no instances.
  INFO: Created security group named: sg-b3485fc8
  INFO: Created Auto Scaling launch configuration named: awseb-e-rshsspfm7f-stack-AWSEBAutoScalingLaunchConfiguration-1JQBCB5U50XZW
  INFO: Created Auto Scaling group named: awseb-e-rshsspfm7f-stack-AWSEBAutoScalingGroup-D9E91V7EINCO
  INFO: Waiting for EC2 instances to launch. This may take a few minutes.
  INFO: Created Auto Scaling group policy named: arn:aws:autoscaling:us-east-1:225162606092:scalingPolicy:a62e4296-d40b-4c6b-a9bc-b2b054354445:autoScalingGroupName/awseb-e-rshsspfm7f-stack-AWSEBAutoScalingGroup-D9E91V7EINCO:policyName/awseb-e-rshsspfm7f-stack-AWSEBAutoScalingScaleUpPolicy-ESBWUU3JHDTO
  INFO: Created Auto Scaling group policy named: arn:aws:autoscaling:us-east-1:225162606092:scalingPolicy:b4bbcc81-39e2-458d-8b96-3a95a65f8079:autoScalingGroupName/awseb-e-rshsspfm7f-stack-AWSEBAutoScalingGroup-D9E91V7EINCO:policyName/awseb-e-rshsspfm7f-stack-AWSEBAutoScalingScaleDownPolicy-5T89VQGWEQ26
  INFO: Created CloudWatch alarm named: awseb-e-rshsspfm7f-stack-AWSEBCloudwatchAlarmHigh-2MH4K55CMCML
  INFO: Created CloudWatch alarm named: awseb-e-rshsspfm7f-stack-AWSEBCloudwatchAlarmLow-1NMKLP4CWVS2K
  INFO: Added instance [i-0e7dd23fbc68f0b65] to your environment.
  INFO: Successfully pulled ubuntu:12.04
  INFO: Successfully built aws_beanstalk/staging-app
  INFO: Docker container f0715bdd5c0f is running aws_beanstalk/current-app.
  INFO: Environment health has transitioned from Pending to Ok. Initialization completed 11 seconds ago and took 4 minutes.
  INFO: Successfully launched environment: example-test
  ```
1. Once the environment is launched, you can find out the hostname for the environment in the [Elastic Beanstalk AWS console](https://console.aws.amazon.com/elasticbeanstalk/home?region=us-east-1#/applications) or from the CNAME value reported by "eb status" CLI command.

  ```
  $ eb status
  Environment details for: example-test
    Application name: beanstalk-docker-example
    Region: us-east-1
    Deployed Version: app-f0f6-160725_161133
    Environment ID: e-rshsspfm7f
    Platform: 64bit Amazon Linux 2016.03 v2.1.3 running Docker 1.11.1
    Tier: WebServer-Standard
    CNAME: example-test.42svxyn6dv.us-east-1.elasticbeanstalk.com
    Updated: 2016-07-25 20:17:03.359000+00:00
    Status: Ready
    Health: Green
  ```
1. Now, let's check out the Docker-based content using command line or browser.

  ```html
  $ curl http://example-test.42svxyn6dv.us-east-1.elasticbeanstalk.com/index.html
  <html>
    <body>
    <h1>Docker Local Files</h1>
    <p>This is a file that is part of the Docker project. It is updated by updating the GitHub project in which it resides. After an update, the Elastic Beanstalk envionment which uses the Docker project must be updated (redeployed).</p>

    <p>The <a href="efs/">efs</a> directory is an Elastic File System mounted at runtime and shared by all Docker containers in the Elastic Beanstalk environment. It will persist beyond Docker container lifetimes.</p>

    <p>Update: 009</p>
    </body>
  </html>
  ```
1. Next, the EFS-based content.

  ```html
  $ curl http://example-test.42svxyn6dv.us-east-1.elasticbeanstalk.com/efs/index.html
  <html><body>
  <h1>EFS-Based File</h1>
  <p>This is just a sample file for demonstration purposes.
  In this scenario, there would be another mechanism for creating and
  updating files on the persistent EFS.<p>
  </body></html>
  ```

## How does this all work?

### Serving Docker-based Content

Let's first look at just the plain vanilla Docker application and content.

The project [Dockerfile](Dockerfile) is very basic. The container it defines is based off the Docker Ubuntu image, adds Nginx to it, and configures Nginx to run in the container foreground. The most interesting thing it does for this project is expose our Docker-based content, which is located in the [www directory of this project](www). This is accomplished by copying [www/index.html](www/index.html) into the Nginx root document directory (/usr/share/nginx/www/) in the Docker container.

```
FROM ubuntu:12.04

RUN \
  apt-get update && \
  apt-get install -y nginx && \
  echo "daemon off;" >> /etc/nginx/nginx.conf

COPY www /usr/share/nginx/www/

EXPOSE 80

CMD ["/usr/sbin/nginx", "-c", "/etc/nginx/nginx.conf"]
```

Now let's look at the option_settings section of [example.config](.ebextensions/example.config) inside the [.ebextensions](.ebextensions) directory. This is how we tell Elastic Beanstalk how we want our application environment configured. This sets up a EB environment that load-balances to a Docker container running on a single EC2 t2.nano instance in the VPC and private subnets indicated. The ELB is given a private IP address not a public one to ensure no one but you can see the environment. Likewise any EC2 instances are launched in one your private subnets and not given public IPs. We'll see how the TARGET_EFS_ID is used later. It is not strictly necessary for just getting our plain Docker container serving the Docker-based content.

```yaml
option_settings:
  aws:autoscaling:asg:
    # How many EC2 intances do we want running out application?
    MinSize: 1
    MaxSize: 1
  aws:autoscaling:launchconfiguration:
    # What instance size should be used.
    InstanceType: t2.nano
    # This should be replaced by the security group created by the EFS CloudFormation template.
    SecurityGroups: sg-e57b6f9e # REPLACE
  aws:ec2:vpc:
    # This should be replaced by your Cornell VPC id.
    VPCId: vpc-71070114 # REPLACE
    # For example purposes, deploy both the EC2 instances and the ELB in your private subnets.
    Subnets: "subnet-7704a001,subnet-dd8519f6" # REPLACE
    ELBSubnets: "subnet-7704a001,subnet-dd8519f6" # REPLACE
    # This tells EB to create the ELB with only a private address.
    ELBScheme: internal
    # Don't associate a public addresses with EC2 insances launched
    AssociatePublicIpAddress: false
  aws:elasticbeanstalk:application:environment:
    # These values get set in the EC2 shell environment at launch
    key1: example-value1
    # This should be replaced by the EFS created by the EFS CloudFormation template.
    TARGET_EFS_ID: fs-4a1adc03 # REPLACE
  aws:elasticbeanstalk:environment:
    # LoadBalanced the application so we can play with multiple instances later.
    EnvironmentType: LoadBalanced
```

The above configuration is all that is required for running our Docker container in the EB environment. It will serve content out of the [www](www/) directory of the Git project. That's great, but what configuration is related to serving the EFS-based content?

### Incorporating EFS-based content

You will have noticed that we skipped several bits of project configuration having to do with our EFS. Here's the rest of the story.

First, we have the [elastic-file-system.json](cloud-formation/elastic-file-system.json) CloudFormation template that creates the EFS itself, mount points in each two private subnets, and a security group which allows access to those mount points. This is separate from the EB environment and Docker container because it is meant to persist beyond the lifetime of any given Docker container or even an EB environment. The scenario is that this particular content is difficult or impossible to persist or manage in a Git repo, or that it needs to be shared amongst multiple Docker containers simultaneously. If all we wanted to persist was some HTML files, then we'd be more likely to use S3 (and maybe CloudFront) instead of EFS. A more realistic scenario for needing EFS is a vendor application that stores state in a file system, and that we need to migrate to Docker. In that case, we could provide scalability and redundancy by using EFS to store that state without the Dockerized application even knowing it.

```yaml
packages:
  yum:
    # We need nfs-utils in order to mount EFS targets.
    nfs-utils: []
    # Nice to have nano on instances if you are not a VIM user.
    nano: []
files:
  # This file is a stand-in for real content stored on the EFS. It would
  # normally be created and maintained entirely separately from the EB enviroment.
  "/tmp/index.html":
    mode: "000755"
    owner: root
    group: root
    content: |
      <html><body>
      <h1>EFS-Based File</h1>
      <p>This is just a sample file for demonstration purposes.
      In this scenario, there would be another mechanism for creating and
      updating files on the persistent EFS.<p>
      </body></html>
  # This script mounts the EFS files system on an EC2 instance. It is invoked
  # in the "commands" section below.
  "/tmp/mount-efs.sh":
    mode: "000755"
    owner: root
    root: root
    content: |
      #!/bin/bash

      # EFS endpoints are created one per availbility zone (i.e. subnet in our case)
      EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`

      # A hack to compute the AWS region, since it is not available directly
      # via instance metadata.
      EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"

      # Construct the EFS endpoint string
      ENDPOINT=$EC2_AVAIL_ZONE.$TARGET_EFS_ID.efs.$EC2_REGION.amazonaws.com:/

      # Mount the endpoint
      mount -t nfs4 -o nfsvers=4.1 $ENDPOINT /mnt/efs

      # Docker needs to be restarted to become aware of the new file system.
      service docker restart
commands:
  # Create a directory to which the EFS will be mouned,
  # only if it does not already exist.
  010-make-mount-point:
    command: "mkdir /mnt/efs"
    test: "[ ! -d /mnt/efs ]"
  # Execute the script to mount the EFS, if it isn't already mounted (i.e.,
  # listed in /proc/mounts).
  020-mount-efs:
    command: "/tmp/mount-efs.sh"
    test: "! grep -qs '/mnt/efs ' /proc/mounts"
  # Copy our example content to EFS sto ensure something is there (only if
  # nothing is there yet.)
  030-populate-efs:
    command: "cp -p /tmp/index.html /mnt/efs"
    test: "[ ! -f /mnt/efs/index.html ]"
  ```

The final piece of the puzzle is the [Dockerrun.aws.json](Dockerrun.aws.json) file, which gives EB some details about how we want our Docker container configured. Ours is very simple.

```json
{
  "AWSEBDockerrunVersion": "1",
  "Ports": [
    {
      "ContainerPort": "80"
    }
  ],
  "Volumes": [
    {
      "HostDirectory": "/mnt/efs",
      "ContainerDirectory": "/usr/share/nginx/www/efs"
    }
  ]
}
```
The real magic of this file tells Docker to mount our EFS (mounted at /mnt/efs on the EC2 host) to /usr/share/nginx/www/efs in our Docker container. Effectively, this is creating a subdirectory in the NGINX web content root and exposing all our EFS content from it. Again showing static HTML content this isn't an ideal example of leveraging EFS, but you can imagine mounting the EFS someplace else in the Docker container that would be useful for a real application requiring file-based persistent state.

### Activity Timeline

With configuration in many different places, it is easy to lose track of the sequence of events. Here's an outline:

**Done once and maintained independently of any EB timelines:**

1. EFS and supporting infrastructure created.
1. EFS populated with content
1. EFS content updated independently of EB application.

**Elastic Beanstalk creation timeline:**

1. New EB application environment created.
  * Supporting infrastructure created (e.g., security groups, load-balancer).
1. For each EC2 instance launched.
  * Mount script (mount-efs.sh) created in /tmp.
  * Mount point directory /mnt/efs created.
  * Mount script executed.
  * Docker restarted to ensure it recognizes the mounted EFS.
  * Docker container started.

### Next Steps

The power of EB is that it will automatically update our environment to satisfy our configuration.  Try this simple exercise:

1. Open [example.config](.ebextensions/example.config) and change MinSize and MaxSize from 1 to 2. Save the update.
1. Tell EB to update your environment accordingly:

  ```
  $ eb deploy --staged
  ```
  This tells EB to deploy the change you made to the configuration. The "--staged" option tells it to pay attention to changes that aren't yet committed to the Git repo. See [EB documentation](http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb3-cli-git.html) for more info about using Git and the EB CLI interface together.
1. Watch as EB adds another instance and changes load balancer configuration to use it.





