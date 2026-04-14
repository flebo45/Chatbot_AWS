import json
import logging
import boto3
import os

from db_serice import get_chat_history, save_chat_message
from ai_service import ask_bedrock

# Logging for CloudWatch
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    try:
        # Unpack API Gateway event
        body = json.loads(event.get('body', '{}'))
        user_message = body.get('message', '')
        user_id = body.get('user_id', 'anonymous')

        if not user_message:
            logger.warning("Received empty message from user {user_id}")
            return _build_response(400, {'error': 'Message cannot be empty.'})

        logger.info(f"Received message from user {user_id}: {user_message}")

        # GET Context
        history = get_chat_history(user_id)

        # Thinking
        ai_response = ask_bedrock(history, user_message)

        # Save the conversation turn to DynamoDB
        save_chat_message(user_id, user_message, ai_response)

        return _build_response(200, {'reply': ai_response})
    
    except json.JSONDecodeError:
        logger.error("Failed to parse JSON body from API Gateway")
        return _build_response(400, {'error': 'Invalid JSON format.'})
        
    except Exception as e:
        logger.error(f"Critical unhandled error in lambda_handler: {str(e)}")
        # Never send raw Python stack traces to the frontend for security reasons
        return _build_response(500, {'error': 'Internal Server Error. Our engineers have been notified.'})

def _build_response(status_code, body):
    """
    Helper function to build a standard API Gateway response.
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS, GET',
        },
        'body': json.dumps(body)
    }