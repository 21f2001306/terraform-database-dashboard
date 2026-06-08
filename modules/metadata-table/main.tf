resource "aws_dynamodb_table" "metadata" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "instanceName"

  attribute {
    name = "instanceName"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = var.table_name
  })
}
