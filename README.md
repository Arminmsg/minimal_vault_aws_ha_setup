Create a new ssh key pair `ssh-keygen -t rsa -b 4096 -f ./my-aws-key` or update the key pair in the configuration in `instances.tf line 8` and `main.tf line 40`

After everything is deployed ssh to each instance and run `vault server -config=/tmp/vault_config.hcl` and afterward you can open one of the instances in the browser "http://ip:8200" and unseal it there or through the CLI