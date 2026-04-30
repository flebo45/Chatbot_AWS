import os
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

bedrock_agent = boto3.client('bedrock-agent')

KB_ID = os.environ['KNOWLEDGE_BASE_ID']
DATA_SOURCE_ID = os.environ['DATA_SOURCE_ID']

def handler(event, context):
    logger.info(f"Received {len(event['Records'])} S3 upload events from SQS.")
    
    try:
        # Trigger the Bedrock Knowledge Base Sync
        response = bedrock_agent.start_ingestion_job(
            knowledgeBaseId=KB_ID,
            dataSourceId=DATA_SOURCE_ID
        )
        job_id = response['ingestionJob']['ingestionJobId']
        logger.info(f"Successfully started Bedrock Ingestion Job: {job_id}")
        
    except bedrock_agent.exceptions.ConflictException:
        # This is expected and totally fine! 
        # It means Bedrock is already currently syncing the bucket.
        logger.info("An ingestion job is already running. Skipping this trigger.")
        
    except Exception as e:
        logger.error(f"Failed to start ingestion job: {str(e)}")
        raise e

    return {"statusCode": 200, "body": "Success"}