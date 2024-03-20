Requirements 

Create a root ca, 
```
openssl genrsa -out rootCA.key 4096
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.crt
```

Create a `vault.hclic` file withing this repo that contains your Vault enterprise license

Create a new ssh key pair `ssh-keygen -t rsa -b 4096 -f ./my-aws-key` or update the key pair in the configuration in `instances.tf line 8` and `main.tf line 40`

After everything is deployed you need to unseal Vault, this can be done through the browser "http://ip:8200" or ssh onto a single machine and unseal it through the API






  openssl x509 -noout -text -in vault.crt