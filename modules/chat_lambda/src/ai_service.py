import boto3
import json
import os
import logging
from botocore.exceptions import ClientError

# Initialization resources
bedrock = boto3.client('bedrock-runtime', region_name=os.environ['AWS_REGION'])
model_id = os.environ['BEDROCK_MODEL_ID']
guardrails_id = os.environ['GUARDRAILS_ID']

# Logging for CloudWatch
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def ask_bedrock(history, new_message):
    """
    Takes the chat history from DynamoDB and the new user message, and sends it to Bedrock to get a response.
    """
    # Formatting messages
    formatted_messages = []

    for item in history:
        formatted_messages.append({
            "role": "user", 
            "content": [{"text": item.get('user_message', '')}]
        })
        formatted_messages.append({
            "role": "assistant", 
            "content": [{"text": item.get('ai_response', '')}]
        })
    
    formatted_messages.append({
        "role": "user",
        "content": [{"text": new_message}]
    })

    try:
        converse_kwags = {
            "modelId": model_id,
            "messages": formatted_messages,
            "system": [{"text": "You are the digital patient coordinator and triage assistant for a professional healthcare clinic. Your tone must always be highly empathetic, reassuring, professional, and concise. You can also anwser general purpose questions."}],
            "inferenceConfig": {
                "maxTokens": 1000,
                "temperature": 0.7
            }
        }

        if guardrails_id:
            logger.info(f"Using guardrails with ID: {guardrails_id}")
            converse_kwags["guardrailConfig"] = {
                "guardrailIdentifier": guardrails_id,
                "guardrailVersion": "DRAFT",
                "trace": "enabled"
            }

        response = bedrock.converse_stream(**converse_kwags)

        for chunk in response.get('stream'):
            if 'contentBlockDelta' in chunk:
                text_delta = chunk['contentBlockDelta']['delta']['text']
                yield text_delta
    
    except ClientError as e:
        logger.error(f"Bedrock API Error: {str(e)}")
        yield "I'm having trouble connecting to my AI brain right now. Please try again later."
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        yield "An unexpected error occurred."
