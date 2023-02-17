# Jenkins Development Environment

Provides a fast and repeatable installation and configuration of Jenkins for a development environment.  

## Description

A Bash script to install Jenkins on an Ubuntu host using Docker.
* Creates custom Jenkins Docker image that...
    * Bypasses the setup wizard
    * Sets Jenkins to use a Configuration as Code file (casc.yaml)
    * Pre-installs a list of plugins (plugins.txt)
* Runs Docker in Docker container to allow the Jenkins Docker container to use Docker.  
* Runs Jenkins container and copies Jenkins casc.yaml to correct location.
* The casc.yaml file...
   * Adds the credentials needed to connect to the Docker in Docker container
   * Setups up an admin account and password
   * Set number of built in Executors to 0
   * Adds a Docker Cloud to Jenkins
   * Sets the Jenkins URL
   
The configuration of Jenkins can be altered by editing casc.yaml and plugins.txt as required.  
   
## Getting Started

### Dependencies

[Docker](https://docs.docker.com/engine/install/ubuntu/)

### Installing

Clone the GitHub repository from command line.
```
clone https://github.com/L7G9/jenkins_dev.git
```
Update casc.yaml and plugins.txt as required.  
* See [Jcasc GitHub documentation](https://github.com/jenkinsci/configuration-as-code-plugin/blob/master/README.md) for guide to Jenkins Configuration as Code.
* See [Plugins Index](https://plugins.jenkins.io/) for available Jenkins plugins.

### Executing program

To deploy Jenkins using Docker on your local host run the jenkins_docker.sh script...
```
./jenkins_docker.sh --password admin_password --url 10.0.0.13
```
* Where admin_password is the password for your Jenkins admin account
* 10.0.0.13 is the URL of your host
* Shortly after navigate to http://10.0.0.13:8080 or http://localhost:8080 in your web browser
* Login to Jenkins using admin as your username and your chosen password

To remove all Docker instances created by this script the jenkins_docker.sh script with the remove flag...
```
./jenkins_docker.sh --remove --data --cert
```
* Where --data and --cert are optional flags used to remove the volumes created by this script.

## Help

To view help run...
```
./jenkins_docker.sh --help
```

## Authors

Luke Gregory (lukewgregory@gmail.com)

## Version History
* 0.1
    * Initial Release

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/L7G9/jenkins_dev/blob/master/LICENSE) file for details

## Acknowledgments

The following tutorials were very helpful with this project...
* [Jenkins Configuration as Code Tutorial](https://www.digitalocean.com/community/tutorials/how-to-automate-jenkins-setup-with-docker-and-jenkins-configuration-as-code)
* [Run Jenkins in a Docker container](https://davelms.medium.com/run-jenkins-in-a-docker-container-part-1-docker-in-docker-7ca75262619d)

