resource "aws_instance" "vault_instances" {
    count = var.instance_count

    ami                    = data.aws_ami.ubuntu.id
    instance_type          = var.instance_type
    security_groups        = [aws_security_group.allow_all.name]
    associate_public_ip_address = true
    key_name               = aws_key_pair.deployer_key.key_name # Name of the SSH key pair
    iam_instance_profile   = aws_iam_instance_profile.vault-kms-unseal.id

    tags = {
        Name = "Instance Vault ${count.index + 1}"
    }

    # Install Vault CE
    connection {
        host = "${self.public_ip}"
        type = "ssh"
        user = "ubuntu"
        private_key = file("./my-aws-key")
    }

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
}



resource "null_resource" "vault_setup_1" {
   triggers = {
    always_run = "${timestamp()}"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("./my-aws-key")
    host        = aws_instance.vault_instances[0].public_ip 
  }
    
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
}


resource "null_resource" "vault_setup_2" {
   triggers = {
    always_run = "${timestamp()}"
  }

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
}

resource "null_resource" "vault_setup_3" {
   triggers = {
    always_run = "${timestamp()}"
  }

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
}