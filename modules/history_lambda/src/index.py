import json
import logging
import boto3
import os

from db_serice import get_chat_history

# Logging for CloudWatch
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    try:
        # Unpack API Gateway event
        query_params = event.get('queryStringParameters') or {}
        user_id = query_params.get('user_id')

        if not user_id:
            logger.warning("Received request without user_id")
            return _build_response(400, {'error': 'Missing user_id parameter.'})

        logger.info(f"Fetching chat history for user {user_id}")

        # GET Context
        history = get_chat_history(user_id)

        return _build_response(200, {'chat_history': history})
    
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