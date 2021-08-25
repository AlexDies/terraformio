## Домашнее задание к занятию "7.3. Основы и принцип работы Терраформ"
___
**Задача 1. Создадим бэкэнд в S3 (необязательно, но крайне желательно).**

Если в рамках предыдущего задания у вас уже есть аккаунт AWS, то давайте продолжим знакомство со взаимодействием терраформа и aws.

1. Создайте s3 бакет, iam роль и пользователя от которого будет работать терраформ. 
   Можно создать отдельного пользователя, а можно использовать созданного в рамках предыдущего задания, 
   просто добавьте ему необходимы права, как описано здесь.
2. Зарегистрируйте бэкэнд в терраформ проекте как описано по ссылке выше.

___
**Выполнение ДЗ:**

1. Создание S3 бакета `terraform-test-netology` :

![img.png](img.png)

2. Создание `DynamoDB` с таблицей `terraform-locks` и `primary key` `LockID` для работы с Terraform:

![img_1.png](img_1.png)

3. Перенос (копия файлов) проекта из предыдущего ДЗ в новую папку и его инициализация:

**Файл main.tf:**

    provider "aws" {
      region = "eu-west-2"
    }
    
    data "aws_ami" "ubuntu" {
      most_recent = true
    
      filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
      }
    
      filter {
        name   = "virtualization-type"
        values = ["hvm"]
      }
    
      owners = ["099720109477"] # Canonical
    }
    
    
    resource "aws_instance" "test" {
      ami           = data.aws_ami.ubuntu.id
      instance_type = "t3.micro"
    
      tags = {
        Name = "testubuntu"
      }
    
       credit_specification {
         cpu_credits = "unlimited"
      }
    }
    
    data "aws_caller_identity" "current" {}
    
    data "aws_region" "current" {}

Инициализация проекта:

        vagrant@vagrant:~/terraform/iac7_3$ terraform init
        
        Initializing the backend...
        
        Initializing provider plugins...
        - Reusing previous version of hashicorp/aws from the dependency lock file
        - Using previously-installed hashicorp/aws v3.55.0
        
        Terraform has been successfully initialized!




        vagrant@vagrant:~/terraform/iac7_3$ terraform apply
        
        aws_instance.test: Creating...
        aws_instance.test: Still creating... [10s elapsed]
        aws_instance.test: Creation complete after 15s [id=i-0425fa3f9de751745]
        
        Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
        
        Outputs:
        
        account_id = "692810338857"
        caller_arn = "arn:aws:iam::692810338857:user/awsuser"
        caller_user = "AIDA2CTVW2IU67CF67QBP"
        private_ip = "172.31.13.41"
        region_name = "eu-west-2"
        subnet_id = "subnet-e8182181"


Автоматически создается файл `terraform.tfstate `

4. Добавление в файл конфигурации `main.tf` блока для переноса стейта в S3:

        terraform {
         backend "s3" {
           bucket         = "terraform-test-netology"
           encrypt        = true
           key            = "netology/terraform.tfstate"
           region         = "eu-west-2"
           dynamodb_table = "terraform-locks"
         }
        }

5. Переинициализация terraform:

        vagrant@vagrant:~/terraform/iac7_3$ terraform init
        
        Initializing the backend...
        Do you want to copy existing state to the new backend?
          Pre-existing state was found while migrating the previous "local" backend to the
          newly configured "s3" backend. No existing state was found in the newly
          configured "s3" backend. Do you want to copy this state to the new "s3"
          backend? Enter "yes" to copy and "no" to start with an empty state.
        
          Enter a value: yes
        
        Releasing state lock. This may take a few moments...
        
        Successfully configured the backend "s3"! Terraform will automatically
        use this backend unless the backend configuration changes.

6. Появление стейта в бакете S3 `terraform-test-netology`:

![img_2.png](img_2.png)

7. Добавление записи в таблицу `terraform-locks` DynamoDB:

![img_3.png](img_3.png)
![img_4.png](img_4.png)


**P/S. Возникли вопросы в процессе переноса стейта в S3:**

1. Первично удалил файл terraform.tfstate в локальной папке (решил сделать с чистого листа скопировав только конфигурацию из предыдущего ДЗ) и данный файл не появлялся пока не сделал `terraform apply`.
Так и должно быть? Не помогал ни `init`, ни `plan`.
   
2. В процессе первоначального выполнения ДЗ, после добавления блока с backend S3 в `main.tf` - процесс `init` прошел успешно, а вот на `plan` была ошибка формата:

        -----------------------------------------------------
        2021-08-25T11:41:45.391Z [DEBUG] [aws-sdk-go] {"__type":"com.amazonaws.dynamodb.v20120810#ResourceNotFoundException","message":"Requested resource not found"}
        2021-08-25T11:41:45.391Z [DEBUG] [aws-sdk-go] DEBUG: Validate Response dynamodb/GetItem failed, attempt 0/5, error ResourceNotFoundException: Requested resource not found
        ╷
        │ Error: Error acquiring the state lock
        │
        │ Error message: 2 errors occurred:
        │       * ResourceNotFoundException: Requested resource not found
        │       * ResourceNotFoundException: Requested resource not found
        │
        │
        │
        │ Terraform acquires a state lock to protect the state from being written
        │ by multiple users at the same time. Please resolve the issue above and try
        │ again. For most commands, you can disable locking with the "-lock=false"

Судя по ней - ресурс для DynamoDB не был найден (я его изначально не создавал). Получается, что помимо S3 бакета, вручную ещё нужно создать и таблицу DynamoDB? 
Так как автоматически она не создается. После того, как создал вручную - всё прошло отлично, результат выше.

___
**Задача 2. Инициализируем проект и создаем воркспейсы.**

1. Выполните `terraform init`:
- если был создан бэкэнд в S3, то терраформ создат файл стейтов в S3 и запись в таблице dynamodb.
- иначе будет создан локальный файл со стейтами.
2. Создайте два воркспейса `stage` и `prod`.
3. В уже созданный `aws_instance` добавьте зависимость типа инстанса от вокспейса, 
   что бы в разных ворскспейсах использовались разные `instance_type`.
4. Добавим `count`. Для` stage` должен создаться один экземпляр ec2, а для `prod `два.
5. Создайте рядом еще один `aws_instance`, но теперь определите их количество при помощи `for_each`, а не `count`.
6. Что бы при изменении типа инстанса не возникло ситуации, когда не будет ни одного инстанса 
   добавьте параметр жизненного цикла `create_before_destroy = true` в один из рессурсов `aws_instance`.
7. При желании поэкспериментируйте с другими параметрами и рессурсами.

В виде результата работы пришлите:

- Вывод команды `terraform workspace list`.
- Вывод команды `terraform plan` для воркспейса `prod`.

___
**Выполнение ДЗ:**

1. Выполнение `terraform init` было сделано в задании выше №1. Запись стейта появилась в S3, а также появилась запись в таблице DynamoDB

2. Создание ворквпейсов `stage` и `prod`:

Воркспейс `stage`:

        vagrant@vagrant:~/terraform/iac7_3$ terraform workspace new stage
        Created and switched to workspace "stage"!
        
        You're now on a new, empty workspace. Workspaces isolate their state,
        so if you run "terraform plan" Terraform will not see any existing state
        for this configuration.

Воркспейс `prod`:

        vagrant@vagrant:~/terraform/iac7_3$ terraform workspace new prod
        Created and switched to workspace "prod"!
        
        You're now on a new, empty workspace. Workspaces isolate their state,
        so if you run "terraform plan" Terraform will not see any existing state
        for this configuration.

3. Добавление зависимости инстанса от воркспейса в `main.tf`:

Для воркспейса `stage` - `t2.micro`

Для воркспейса `prod `- `t3.micro`

        locals {
         web_instance_type_map = {
           stage = "t2.micro"
           prod = "t3.micro"
         }
        }
        
        resource "aws_instance" "test" {
          ami           = data.aws_ami.ubuntu.id
          instance_type = local.web_instance_type_map[terraform.workspace]
        
          tags = {
            Name = "testubuntu"
          }
        }

4. Добавляем значение `count` в `main.tf`:

Для значения `stage` - 1 инстанс

Для значения `prod` - 2 инстанса

        locals {
         web_instance_type_map = {
           stage = "t2.micro"
           prod = "t3.micro"
         }
         web_instance_count_map = {
           stage = 1
           prod = 2
         }
        }
        
        resource "aws_instance" "test" {
          ami           = data.aws_ami.ubuntu.id
          instance_type = local.web_instance_type_map[terraform.workspace]
          count = local.web_instance_count_map[terraform.workspace]
        
          tags = {
            Name = "testubuntu"
          }
        }

Также потребовалось внести изменения в файл `output.tf` из ДЗ предыдущего урока, так как значения output стали зависить от количества (count) инстансов:

    output "private_ip" {
      value = aws_instance.test[0].private_ip
    }
    
    output "subnet_id" {
      value = aws_instance.test[0].subnet_id
    }

5. Создание нового инстанса с указанием количества через `for_each`:

Добавим следующие блоки в файл `main.tf`

        locals {
         instances = {
           "t3.micro" = data.aws_ami.ubuntu.id
           "t2.micro" = data.aws_ami.ubuntu.id
         }
        }
        
        
        resource "aws_instance" "for_each" {
         for_each = local.instances
         ami = each.value
         instance_type = each.key
        }

Тем самым будут созданы 2 инстанса с наименованием for_each с `t3.micro` и` t2.micro`.

В `terraform plan` для `prod` на текущем этапе будет 4 инстанса - 2 через `count` с привязкой к переменной `prod` (t3.micro) и 2 с использованием `for_each` (`t3.micro` и` t2.micro`).

В `terraform plan` для `stage` на текущем этапе будет 3 инстанса - 1 через `count` с привязкой к переменной `stage` (t2.micro) и 2 с использованием `for_each` (`t3.micro` и` t2.micro`).

6. Добавим жизненный цикл ресурса:

Используем `create_before_destroy` в ресурсе `aws_instance for_each`:

        resource "aws_instance" "for_each" {
         for_each = local.instances
         ami = each.value
         instance_type = each.key
        
         lifecycle {
          create_before_destroy = true
         }
        }


7. Вывод команды `terraform workspace list`:

        vagrant@vagrant:~/terraform/iac7_3$ terraform workspace list
          default
        * prod
          stage

8. Вывод команды `terraform plan` для воркспейса `prod`:

        vagrant@vagrant:~/terraform/iac7_3$ terraform plan
        
        Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with
        the following symbols:
          + create
        
        Terraform will perform the following actions:
        
          # aws_instance.for_each["t2.micro"] will be created
          + resource "aws_instance" "for_each" {
              + ami                                  = "ami-0d1bf29ea93678225"
              + arn                                  = (known after apply)
              + associate_public_ip_address          = (known after apply)
              + availability_zone                    = (known after apply)
              + cpu_core_count                       = (known after apply)
              + cpu_threads_per_core                 = (known after apply)
              + disable_api_termination              = (known after apply)
              + ebs_optimized                        = (known after apply)
              + get_password_data                    = false
              + host_id                              = (known after apply)
              + id                                   = (known after apply)
              + instance_initiated_shutdown_behavior = (known after apply)
              + instance_state                       = (known after apply)
              + instance_type                        = "t2.micro"
              + ipv6_address_count                   = (known after apply)
              + ipv6_addresses                       = (known after apply)
              + key_name                             = (known after apply)
              + monitoring                           = (known after apply)
              + outpost_arn                          = (known after apply)
              + password_data                        = (known after apply)
              + placement_group                      = (known after apply)
              + primary_network_interface_id         = (known after apply)
              + private_dns                          = (known after apply)
              + private_ip                           = (known after apply)
              + public_dns                           = (known after apply)
              + public_ip                            = (known after apply)
              + secondary_private_ips                = (known after apply)
              + security_groups                      = (known after apply)
              + source_dest_check                    = true
              + subnet_id                            = (known after apply)
              + tags_all                             = (known after apply)
              + tenancy                              = (known after apply)
              + user_data                            = (known after apply)
              + user_data_base64                     = (known after apply)
              + vpc_security_group_ids               = (known after apply)
        
              + capacity_reservation_specification {
                  + capacity_reservation_preference = (known after apply)
        
                  + capacity_reservation_target {
                      + capacity_reservation_id = (known after apply)
                    }
                }
        
              + ebs_block_device {
                  + delete_on_termination = (known after apply)
                  + device_name           = (known after apply)
                  + encrypted             = (known after apply)
                  + iops                  = (known after apply)
                  + kms_key_id            = (known after apply)
                  + snapshot_id           = (known after apply)
                  + tags                  = (known after apply)
                  + throughput            = (known after apply)
                  + volume_id             = (known after apply)
                  + volume_size           = (known after apply)
                  + volume_type           = (known after apply)
                }
        
              + enclave_options {
                  + enabled = (known after apply)
                }
        
              + ephemeral_block_device {
                  + device_name  = (known after apply)
                  + no_device    = (known after apply)
                  + virtual_name = (known after apply)
                }
        
              + metadata_options {
                  + http_endpoint               = (known after apply)
                  + http_put_response_hop_limit = (known after apply)
                  + http_tokens                 = (known after apply)
                }
        
              + network_interface {
                  + delete_on_termination = (known after apply)
                  + device_index          = (known after apply)
                  + network_interface_id  = (known after apply)
                }
        
              + root_block_device {
                  + delete_on_termination = (known after apply)
                  + device_name           = (known after apply)
                  + encrypted             = (known after apply)
                  + iops                  = (known after apply)
                  + kms_key_id            = (known after apply)
                  + tags                  = (known after apply)
                  + throughput            = (known after apply)
                  + volume_id             = (known after apply)
                  + volume_size           = (known after apply)
                  + volume_type           = (known after apply)
                }
            }
        
          # aws_instance.for_each["t3.micro"] will be created
          + resource "aws_instance" "for_each" {
              + ami                                  = "ami-0d1bf29ea93678225"
              + arn                                  = (known after apply)
              + associate_public_ip_address          = (known after apply)
              + availability_zone                    = (known after apply)
              + cpu_core_count                       = (known after apply)
              + cpu_threads_per_core                 = (known after apply)
              + disable_api_termination              = (known after apply)
              + ebs_optimized                        = (known after apply)
              + get_password_data                    = false
              + host_id                              = (known after apply)
              + id                                   = (known after apply)
              + instance_initiated_shutdown_behavior = (known after apply)
              + instance_state                       = (known after apply)
              + instance_type                        = "t3.micro"
              + ipv6_address_count                   = (known after apply)
              + ipv6_addresses                       = (known after apply)
              + key_name                             = (known after apply)
              + monitoring                           = (known after apply)
              + outpost_arn                          = (known after apply)
              + password_data                        = (known after apply)
              + placement_group                      = (known after apply)
              + primary_network_interface_id         = (known after apply)
              + private_dns                          = (known after apply)
              + private_ip                           = (known after apply)
              + public_dns                           = (known after apply)
              + public_ip                            = (known after apply)
              + secondary_private_ips                = (known after apply)
              + security_groups                      = (known after apply)
              + source_dest_check                    = true
              + subnet_id                            = (known after apply)
              + tags_all                             = (known after apply)
              + tenancy                              = (known after apply)
              + user_data                            = (known after apply)
              + user_data_base64                     = (known after apply)
              + vpc_security_group_ids               = (known after apply)
        
              + capacity_reservation_specification {
                  + capacity_reservation_preference = (known after apply)
        
                  + capacity_reservation_target {
                      + capacity_reservation_id = (known after apply)
                    }
                }
        
              + ebs_block_device {
                  + delete_on_termination = (known after apply)
                  + device_name           = (known after apply)
                  + encrypted             = (known after apply)
                  + iops                  = (known after apply)
                  + kms_key_id            = (known after apply)
                  + snapshot_id           = (known after apply)
                  + tags                  = (known after apply)
                  + throughput            = (known after apply)
                  + volume_id             = (known after apply)
                  + volume_size           = (known after apply)
                  + volume_type           = (known after apply)
                }
        
              + enclave_options {
                  + enabled = (known after apply)
                }
        
              + ephemeral_block_device {
                  + device_name  = (known after apply)
                  + no_device    = (known after apply)
                  + virtual_name = (known after apply)
                }
        
              + metadata_options {
                  + http_endpoint               = (known after apply)
                  + http_put_response_hop_limit = (known after apply)
                  + http_tokens                 = (known after apply)
                }
        
              + network_interface {
                  + delete_on_termination = (known after apply)
                  + device_index          = (known after apply)
                  + network_interface_id  = (known after apply)
                }
        
              + root_block_device {
                  + delete_on_termination = (known after apply)
                  + device_name           = (known after apply)
                  + encrypted             = (known after apply)
                  + iops                  = (known after apply)
                  + kms_key_id            = (known after apply)
                  + tags                  = (known after apply)
                  + throughput            = (known after apply)
                  + volume_id             = (known after apply)
                  + volume_size           = (known after apply)
                  + volume_type           = (known after apply)
                }
            }
        
          # aws_instance.test[0] will be created
          + resource "aws_instance" "test" {
              + ami                                  = "ami-0d1bf29ea93678225"
              + arn                                  = (known after apply)
              + associate_public_ip_address          = (known after apply)
              + availability_zone                    = (known after apply)
              + cpu_core_count                       = (known after apply)
              + cpu_threads_per_core                 = (known after apply)
              + disable_api_termination              = (known after apply)
              + ebs_optimized                        = (known after apply)
              + get_password_data                    = false
              + host_id                              = (known after apply)
              + id                                   = (known after apply)
              + instance_initiated_shutdown_behavior = (known after apply)
              + instance_state                       = (known after apply)
              + instance_type                        = "t3.micro"
              + ipv6_address_count                   = (known after apply)
              + ipv6_addresses                       = (known after apply)
              + key_name                             = (known after apply)
              + monitoring                           = (known after apply)
              + outpost_arn                          = (known after apply)
              + password_data                        = (known after apply)
              + placement_group                      = (known after apply)
              + primary_network_interface_id         = (known after apply)
              + private_dns                          = (known after apply)
              + private_ip                           = (known after apply)
              + public_dns                           = (known after apply)
              + public_ip                            = (known after apply)
              + secondary_private_ips                = (known after apply)
              + security_groups                      = (known after apply)
              + source_dest_check                    = true
              + subnet_id                            = (known after apply)
              + tags                                 = {
                  + "Name" = "testubuntu"
                }
              + tags_all                             = {
                  + "Name" = "testubuntu"
                }
              + tenancy                              = (known after apply)
              + user_data                            = (known after apply)
              + user_data_base64                     = (known after apply)
              + vpc_security_group_ids               = (known after apply)
        
              + capacity_reservation_specification {
                  + capacity_reservation_preference = (known after apply)
        
                  + capacity_reservation_target {
                      + capacity_reservation_id = (known after apply)
                    }
                }
        
              + ebs_block_device {
                  + delete_on_termination = (known after apply)
                  + device_name           = (known after apply)
                  + encrypted             = (known after apply)
                  + iops                  = (known after apply)
                  + kms_key_id            = (known after apply)
                  + snapshot_id           = (known after apply)
                  + tags                  = (known after apply)
                  + throughput            = (known after apply)
                  + volume_id             = (known after apply)
                  + volume_size           = (known after apply)
                  + volume_type           = (known after apply)
                }
        
              + enclave_options {
                  + enabled = (known after apply)
                }
        
              + ephemeral_block_device {
                  + device_name  = (known after apply)
                  + no_device    = (known after apply)
                  + virtual_name = (known after apply)
                }
        
              + metadata_options {
                  + http_endpoint               = (known after apply)
                  + http_put_response_hop_limit = (known after apply)
                  + http_tokens                 = (known after apply)
                }
        
              + network_interface {
                  + delete_on_termination = (known after apply)
                  + device_index          = (known after apply)
                  + network_interface_id  = (known after apply)
                }
        
              + root_block_device {
                  + delete_on_termination = (known after apply)
                  + device_name           = (known after apply)
                  + encrypted             = (known after apply)
                  + iops                  = (known after apply)
                  + kms_key_id            = (known after apply)
                  + tags                  = (known after apply)
                  + throughput            = (known after apply)
                  + volume_id             = (known after apply)
                  + volume_size           = (known after apply)
                  + volume_type           = (known after apply)
                }
            }
        
          # aws_instance.test[1] will be created
          + resource "aws_instance" "test" {
              + ami                                  = "ami-0d1bf29ea93678225"
              + arn                                  = (known after apply)
              + associate_public_ip_address          = (known after apply)
              + availability_zone                    = (known after apply)
              + cpu_core_count                       = (known after apply)
              + cpu_threads_per_core                 = (known after apply)
              + disable_api_termination              = (known after apply)
              + ebs_optimized                        = (known after apply)
              + get_password_data                    = false
              + host_id                              = (known after apply)
              + id                                   = (known after apply)
              + instance_initiated_shutdown_behavior = (known after apply)
              + instance_state                       = (known after apply)
              + instance_type                        = "t3.micro"
              + ipv6_address_count                   = (known after apply)
              + ipv6_addresses                       = (known after apply)
              + key_name                             = (known after apply)
              + monitoring                           = (known after apply)
              + outpost_arn                          = (known after apply)
              + password_data                        = (known after apply)
              + placement_group                      = (known after apply)
              + primary_network_interface_id         = (known after apply)
              + private_dns                          = (known after apply)
              + private_ip                           = (known after apply)
              + public_dns                           = (known after apply)
              + public_ip                            = (known after apply)
              + secondary_private_ips                = (known after apply)
              + security_groups                      = (known after apply)
              + source_dest_check                    = true
              + subnet_id                            = (known after apply)
              + tags                                 = {
                  + "Name" = "testubuntu"
                }
              + tags_all                             = {
                  + "Name" = "testubuntu"
                }
              + tenancy                              = (known after apply)
              + user_data                            = (known after apply)
              + user_data_base64                     = (known after apply)
              + vpc_security_group_ids               = (known after apply)
        
              + capacity_reservation_specification {
                  + capacity_reservation_preference = (known after apply)
        
                  + capacity_reservation_target {
                      + capacity_reservation_id = (known after apply)
                    }
                }
        
              + ebs_block_device {
                  + delete_on_termination = (known after apply)
                  + device_name           = (known after apply)
                  + encrypted             = (known after apply)
                  + iops                  = (known after apply)
                  + kms_key_id            = (known after apply)
                  + snapshot_id           = (known after apply)
                  + tags                  = (known after apply)
                  + throughput            = (known after apply)
                  + volume_id             = (known after apply)
                  + volume_size           = (known after apply)
                  + volume_type           = (known after apply)
                }
        
              + enclave_options {
                  + enabled = (known after apply)
                }
        
              + ephemeral_block_device {
                  + device_name  = (known after apply)
                  + no_device    = (known after apply)
                  + virtual_name = (known after apply)
                }
        
              + metadata_options {
                  + http_endpoint               = (known after apply)
                  + http_put_response_hop_limit = (known after apply)
                  + http_tokens                 = (known after apply)
                }
        
              + network_interface {
                  + delete_on_termination = (known after apply)
                  + device_index          = (known after apply)
                  + network_interface_id  = (known after apply)
                }
        
              + root_block_device {
                  + delete_on_termination = (known after apply)
                  + device_name           = (known after apply)
                  + encrypted             = (known after apply)
                  + iops                  = (known after apply)
                  + kms_key_id            = (known after apply)
                  + tags                  = (known after apply)
                  + throughput            = (known after apply)
                  + volume_id             = (known after apply)
                  + volume_size           = (known after apply)
                  + volume_type           = (known after apply)
                }
            }
        
        Plan: 4 to add, 0 to change, 0 to destroy.
        
        Changes to Outputs:
          + account_id  = "692810338857"
          + caller_arn  = "arn:aws:iam::692810338857:user/awsuser"
          + caller_user = "AIDA2CTVW2IU67CF67QBP"
          + private_ip  = (known after apply)
          + region_name = "eu-west-2"
          + subnet_id   = (known after apply)
        
        ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
        
        Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to take exactly these actions if
        you run "terraform apply" now.
        Releasing state lock. This may take a few moments...

**P/S. Возник вопрос касательно отображения жизненного цикла.** 
При подаче команды terraform plan нигде не нашел отображение параметра` create_before_destroy`. Параметры жизненного цикла не отображаются в plan?