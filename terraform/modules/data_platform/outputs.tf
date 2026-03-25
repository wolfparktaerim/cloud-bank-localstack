output "elasticache_cluster_id" {
  value       = try(aws_elasticache_cluster.redis[0].cluster_id, null)
  description = "Redis cluster id"
}

output "elasticache_endpoint" {
  value       = try(aws_elasticache_cluster.redis[0].cache_nodes[0].address, null)
  description = "Redis endpoint address"
}

output "elasticache_port" {
  value       = try(aws_elasticache_cluster.redis[0].port, null)
  description = "Redis endpoint port"
}

output "glue_database_name" {
  value       = try(aws_glue_catalog_database.main[0].name, null)
  description = "Glue database name"
}

output "glue_table_name" {
  value       = try(aws_glue_catalog_table.transactions[0].name, null)
  description = "Glue table name"
}

output "glue_job_name" {
  value       = try(aws_glue_job.etl[0].name, null)
  description = "Glue ETL job name"
}

output "glue_crawler_name" {
  value       = try(aws_glue_crawler.transactions[0].name, null)
  description = "Glue crawler name"
}
