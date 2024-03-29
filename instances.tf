resource "aws_instance" "vault_instances" {
    count = var.instance_count

    ami                         = data.aws_ami.ubuntu.id
    instance_type               = var.instance_type
    security_groups             = [aws_security_group.allow_all.name]
    associate_public_ip_address = true
    key_name                    = aws_key_pair.deployer_key.key_name # Name of the SSH key pair
    iam_instance_profile        = aws_iam_instance_profile.vault-kms-unseal.id

    tags = {
        Name = "Instance Vault ${count.index + 1}"
    }

    connection {
        host = "${self.public_ip}"
        type = "ssh"
        user = "ubuntu"
        private_key = file("./my-aws-key")
    }

    # Install Vault CE
    provisioner "file" {
        source      = "install.sh"
        destination = "/tmp/install.sh"
    }

    provisioner "remote-exec" {
        inline = [
        "chmod +x /tmp/install.sh",
        "/tmp/install.sh"
        ]
    }

    # Setting up Vault service
    provisioner "file" {
      source = "vault.service"
      destination = "/tmp/vault.service"
    }

    provisioner "remote-exec" {
        inline = [
        "sudo mv /tmp/vault.service /etc/systemd/system/",
        ]
    }

    # Creating Vault enterprise license
    provisioner "file" {
        source      = "vault.hclic"
        destination = "/tmp/vault.hclic"
    }
    
    # Copy root ca to instances, in a prod environment this wouldn't happen
    provisioner "file" {
      content     = file("certs/rootCA.key")
      destination = "/tmp/rootCA.key"
    }

    provisioner "file" {
      content     = file("certs/rootCA.crt")
      destination = "/tmp/rootCA.crt"
    }
}

resource "null_resource" "vault_setup_1" {
  #triggers = {
  #  always_run = "${timestamp()}"
  #}

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("./my-aws-key")
    host        = aws_instance.vault_instances[0].public_ip 
  }
  # Render the vault config file with the correct IP adresses 
  provisioner "file" {
    content      = templatefile("vault_config.tftpl", {
        cluster_addr        = aws_instance.vault_instances[0].public_ip,
        api_addr            = aws_instance.vault_instances[0].public_ip,
        leader_api_addr_1   = aws_instance.vault_instances[1].public_ip,
        leader_api_addr_2   = aws_instance.vault_instances[2].public_ip,
        kms_id              = aws_kms_key.vault.id
        })
    destination = "/tmp/vault_config.hcl"
  }

  # Setup certs
  provisioner "file" {
    content     = templatefile("certs/san.cnf.tftpl", {
        ip_addr = aws_instance.vault_instances[0].public_ip,
        })
    destination = "/tmp/san.cnf"
  }

  provisioner "remote-exec" {
    inline = [ 
      "sleep 20",
      "cd /tmp",
      "openssl genrsa -out vault.key 2048",
      "openssl req -new -key vault.key -out vault.csr -config /tmp/san.cnf",
      "openssl x509 -req -in vault.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out vault.crt -days 500 -sha256 -extensions v3_req -extfile ./san.cnf" 
      ]    
  }

  # Launch vault
  provisioner "remote-exec" {
        inline = [ "sleep 20", "sudo systemctl start vault.service" ]
  }
}


resource "null_resource" "vault_setup_2" {
  #triggers = {
  #  always_run = "${timestamp()}"
  #}

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("./my-aws-key")
    host        = aws_instance.vault_instances[1].public_ip 
  }
    
  provisioner "file" {
    content      = templatefile("vault_config.tftpl", {
        cluster_addr        = aws_instance.vault_instances[1].public_ip,
        api_addr            = aws_instance.vault_instances[1].public_ip,
        leader_api_addr_1   = aws_instance.vault_instances[0].public_ip,
        leader_api_addr_2   = aws_instance.vault_instances[2].public_ip,
        kms_id              = aws_kms_key.vault.id
        })
    destination = "/tmp/vault_config.hcl"
  }

  #rootCA.crt -CAkey rootCA.key
  provisioner "file" {
    content     = templatefile("certs/san.cnf.tftpl", {
        ip_addr = aws_instance.vault_instances[0].public_ip,
        })
    destination = "/tmp/san.cnf"
  }

  provisioner "remote-exec" {
    inline = [ 
      "sleep 20",
      "cd /tmp",
      "openssl genrsa -out vault.key 2048",
      "openssl req -new -key vault.key -out vault.csr -config san.cnf",
      "openssl x509 -req -in vault.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out vault.crt -days 500 -sha256 -extensions v3_req -extfile ./san.cnf" 
      ]    
  }

  provisioner "remote-exec" {
        inline = [ "sleep 20", "sudo systemctl start vault.service" ]
  }
}

resource "null_resource" "vault_setup_3" {
  #triggers = {
  #  always_run = "${timestamp()}"
  #}

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("./my-aws-key")
    host        = aws_instance.vault_instances[2].public_ip 
  }
    
  provisioner "file" {
    content      = templatefile("vault_config.tftpl", {
        cluster_addr        = aws_instance.vault_instances[2].public_ip,
        api_addr            = aws_instance.vault_instances[2].public_ip,
        leader_api_addr_1   = aws_instance.vault_instances[0].public_ip,
        leader_api_addr_2   = aws_instance.vault_instances[1].public_ip,
        kms_id              = aws_kms_key.vault.id
        })
    destination = "/tmp/vault_config.hcl"
  }

  provisioner "file" {
    content     = templatefile("certs/san.cnf.tftpl", {
        ip_addr = aws_instance.vault_instances[0].public_ip,
        })
    destination = "/tmp/san.cnf"
  }

  provisioner "remote-exec" {
    inline = [ 
      "sleep 20",
      "cd /tmp",
      "openssl genrsa -out vault.key 2048",
      "openssl req -new -key vault.key -out vault.csr -config san.cnf",
      "openssl x509 -req -in vault.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out vault.crt -days 500 -sha256 -extensions v3_req -extfile ./san.cnf" 
      ]    
  }

  provisioner "remote-exec" {
        inline = [ "sleep 20", "sudo systemctl start vault.service" ]
  }
}

output "ec2_ip_addresses" {
  value = aws_instance.vault_instances.*.public_ip
}

/**
locals {
  ips = toseet([for each in aws_instance.vault_instances : each.public_ip])
}
resource "null_resource" "foo" {
  triggers = {
    always_run = "${timestamp()}"
  }
  
  for_each = local.ips

  
  provisioner "local-exec" {
    command = "echo \"Foo ${setsubtract(local.ips, ["3.70.137.25"])})\""
  }
}**/