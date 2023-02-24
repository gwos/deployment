# GW8 Installer

### Usage:

The instruction for use implies that the repository is not present on the machine on which the installation / update is
being performed.

```shell
$ git clone https://github.com/gwos/installer.git
$ cd installer
$ vi config.yml
# provide configuration parameters
$ ./install.sh
```

#### Parameters from the config.yml file:

```
    • version - GW8 version you want to install/update
    • docker.user - DockerHub username to pull necessary images 
    • docker.password - DockerHub password to pull necessary images 
```

#### config.yml example:

```yaml
docker:
  user: admin
  password: admin

gw8:
  tag: master
  image: groundworkdevelopment/gw8
  instance_name: localhost
  parent_instance_name:
  child_instance_name:
```
