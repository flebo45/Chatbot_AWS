output "bedrock_agent_knowledge_base_arn" {
  description = "The ARN of the Bedrock Agent knowledge base created for RAG ingestion"
  value       = aws_bedrockagent_knowledge_base.chatbot_kb.arn
}

output "bedrock_agent_knowledge_base_id" {
  description = "The ID of the Bedrock Agent knowledge base created for RAG ingestion"
  value       = aws_bedrockagent_knowledge_base.chatbot_kb.id
}

output "bedrock_agent_data_source_id" {
  description = "The ID of the Bedrock Agent data source created for RAG ingestion"
  value       = aws_bedrockagent_data_source.s3_data_source.data_source_id
}
