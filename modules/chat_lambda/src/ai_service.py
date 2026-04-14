import boto3
import json
import os
import logging
from botocore.exceptions import ClientError

# Initialization resurces
bedrock = boto3.client('bedrock-runtime', region_name=os.environ['AWS_REGION'])
model_id = os.environ['BEDROCK_MODEL_ID']

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
        response = bedrock.converse(
            modelId=model_id,
            messages=formatted_messages,
            system=[{"text": "You are a highly intelligent, concise, and helpful AI cloud architect. Respond politely but get straight to the point."}],
            inferenceConfig={
                "maxTokens": 1000,
                "temperature": 0.7
            }
        )
        ai_response = response['output']['message']['content'][0]['text']
        logger.info(f"Received response from Bedrock for model {model_id}")
        return ai_response
    
    except ClientError as e:
        error_code = e.response['Error']['Code']
        logger.error(f"Bedrock API Error: {error_code} - {str(e)}")
        
        # Graceful degradation: Tell the user something went wrong
        if error_code == 'ThrottlingException':
            return "I'm receiving too many messages right now. Please try again in a moment."
        else:
            return "I'm having trouble connecting to my AI brain right now. Please try again later."
    except Exception as e:
        logger.error(f"Unexpected error in ask_bedrock: {str(e)}")
        return "An unexpected error occurred."
