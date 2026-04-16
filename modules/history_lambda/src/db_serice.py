import boto3
from boto3.dynamodb.conditions import Key
import os
import logging
from datetime import datetime, timezone

# Logging for CloudWatch
logger = logging.getLogger()
logger.setLevel(logging.INFO)

#Resource Initialization
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['TABLE_NAME']
table = dynamodb.Table(table_name)

def get_chat_history(user_id, limit=10):
    """
    Fetch the chat history for a given user.
    """
    try:
        response = table.query(
            KeyConditionExpression=Key('user_id').eq(user_id),
            ScanIndexForward=False,  # Get latest messages first
            Limit=limit
        )
        items = response.get('Items', [])
        logger.info(f"Fetched {len(items)} chat history items for user {user_id}")

        return items
    except Exception as e:
        logger.error(f"Error fetching chat history for user {user_id}: {str(e)}")
        return []