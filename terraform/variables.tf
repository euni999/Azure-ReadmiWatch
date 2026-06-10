variable "subscription_id" {}
variable "location" { default = "koreacentral" }
variable "sql_admin"    { default = "rmwadmin" }
variable "sql_password" { sensitive = true }
