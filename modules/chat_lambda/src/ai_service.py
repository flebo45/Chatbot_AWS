import boto3
import json
import os
import sys
import logging
from botocore.exceptions import ClientError

# Initialization resources
bedrock = boto3.client('bedrock-runtime', region_name=os.environ['AWS_REGION'])
bedrock_agent = boto3.client('bedrock-agent-runtime', region_name=os.environ['AWS_REGION'])

model_id = os.environ['BEDROCK_MODEL_ID']
guardrails_id = os.environ['GUARDRAILS_ID']
knowledge_base_id = os.environ['KNOWLEDGE_BASE_ID']

# Logging for CloudWatch
logging.basicConfig(
    stream=sys.stdout, 
    level=logging.INFO,
    format='%(levelname)s: %(message)s'
)
logger = logging.getLogger(__name__)

def ask_bedrock(history, new_message, user_id):
    """
    Retrieves context from the Knowledge Base, formats the chat history, 
    and sends everything to Bedrock for a streamed response.
    """
    retrived_content = ""
    if knowledge_base_id and user_id:
        try:
            logger.info(f"Querying knowledge base {knowledge_base_id} for user {user_id}")
            retrival_response = bedrock_agent.retrieve(
                knowledgeBaseId = knowledge_base_id,
                retrievalQuery = {'text': new_message},
                retrievalConfiguration = {
                    'vectorSearchConfiguration': {
                        'numberOfResults': 5, # Fetch the top 5 most relevant chunks
                        'filter': {
                            'equals': {
                                'key': 'userId', # must match the metadata.json
                                'value': user_id
                            }
                        }
                    }
                }
            )

            results = retrival_response.get('retrievalResults', [])

            if results:
                context_chunks = [f"<document>\n{res['content']['text']}\n</document>" for res in results]
                retrieved_context = "\n\n".join(context_chunks)
                logger.info(f"Successfully retrieved {len(results)} chunks of context.")
            
        except Exception as e:
            logger.error(f"Error retrieving from knowledge base: {str(e)}")

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

    # System prompt with RAG instructions
    #system_prompt = "You are the digital patient coordinator and triage assistant for a professional healthcare clinic. Your tone must always be highly empathetic, reassuring, professional, and concise. You can also anwser general purpose questions abaout everything."
    system_prompt = "You are a helpful and precise assistant for answering user questions."
    # Inject RAG
    if retrieved_context:
        system_prompt += f"\n\nHere is relevant context extracted from the user's uploaded documents. Use this information to answer their question. If the answer is not in the documents, just use your general knowledge.\n\n<context>\n{retrieved_context}\n</context>"

    try:
        converse_kwags = {
            "modelId": model_id,
            "messages": formatted_messages,
            "system": [{"text": system_prompt}],
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
