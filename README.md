# GW8 Deployment

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
    • gw8.tag - GW8 version you want to install/update                                  ! required
    • gw8.image - name of the installation image                                        ! required
    • gw8.instance_name - name of the GW8 instance                                      ! required
    • gw8.parent_instance_name - name of the GW8 parent (for PMC installation only)
    • gw8.parent_instance_name - name of the GW8 instance (for PMC installation only)
    • gw8.timezone - timezone to use for GW8 instance
    • gw8.dir - directory to store the gw8 folder with configuration files
    
    • docker.user - DockerHub username to pull necessary images                         ! required
    • docker.password - DockerHub password to pull necessary images                     ! required
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
  timezone: America/Denver
  dir: gw8
```

#### Overrides

To override any of the ULG files (/usr/local/groundwork/config), simply place them in the config directory. For example:
ldap.properties
