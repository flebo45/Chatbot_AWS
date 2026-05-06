import json
import logging
import sys
import boto3
import os
import uuid
from botocore.config import Config

from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse, JSONResponse

from starlette.background import BackgroundTask

from fastapi.middleware.cors import CORSMiddleware

from db_serice import get_chat_history, save_chat_message
from ai_service import ask_bedrock

# Logging for CloudWatch
logging.basicConfig(
    stream=sys.stdout, 
    level=logging.INFO,
    format='%(levelname)s: %(message)s'
)
logger = logging.getLogger(__name__)

# S3 initialization
s3 = boto3.client('s3',
                  region_name= 'eu-west-1',
                  config=Config(signature_version='s3v4', s3={'addressing_style': 'virtual'}))

BUCKET_NAME = os.environ['BUCKET_NAME']

# Initialize FastAPI app
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=[os.environ['CLOUDFRONT_URL']], # In production, replace with your CloudFront URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"]
)

@app.post("/upload-url")
async def get_upload_url(request: Request):
    try:
        body = await request.json()
        filename = body.get("filename")
        user_id = body.get("user_id")
        file_mime_type = body.get("file_type", "application/pdf")
        if not filename or not user_id:
            return JSONResponse(status_code=400, content={"error": "Filename is required"}, headers={"Access-Control-Allow-Origin": "*"})

        if not BUCKET_NAME:
            logger.error("S3_BUCKET_NAME environment variable is not set.")
            return JSONResponse(status_code=500, content={"error": "Internal Server Error: S3 bucket not configured"}, headers={"Access-Control-Allow-Origin": "*"})
        
        # Safe S3  key generation
        file_id = str(uuid.uuid4())
        fileExt = filename.split(".")[-1]
        safe_filename = f"uploads/{user_id}/{file_id}_{filename}"

        # Bedrock Metadata JSON
        metadata_key = f"{safe_filename}.metadata.json"
        metadata_content = json.dumps({
            "metadataAttributes": {
                "userId": user_id,
                "originalFilename": filename,
                "fileType": fileExt
            }
        })

        s3.put_object(
            Bucket=BUCKET_NAME, 
            Key=metadata_key, 
            Body=metadata_content, 
            ContentType='application/json',
            ServerSideEncryption='AES256'
        )

        # Generate presigned URL for the actual file upload
        presigned_url = s3.generate_presigned_url(
            'put_object',
            Params={
            'Bucket': BUCKET_NAME, 
            'Key': safe_filename,
            'ContentType': file_mime_type,
            #'ServerSideEncryption': 'AES256'
            },
            ExpiresIn=300
        )

        return JSONResponse(
            status_code=200, 
            content={"upload_url": presigned_url, "file_key": safe_filename},
            headers={"Access-Control-Allow-Origin": "POST, OPTIONS"}
        )
    
    except Exception as e:
        logger.error(f"Error generating presigned URL: {str(e)}")
        # 5. MUST attach CORS headers here so the browser lets the error through!
        return JSONResponse(
            status_code=500, 
            content={"error": f"Upload Error: {str(e)}"},
            headers={
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS"
            }
        )

@app.post("/{full_path:path}")
async def chat_endpoint(request: Request):
    try:
        body = await request.json()
        user_message = body.get("message", "")
        user_id = body.get("user_id", "anonymous")

        if not user_message:
            return JSONResponse(status_code=400, content={"error": "Message is required"})

        history = get_chat_history(user_id)
        collected_tokens = []

        def stream_generator():
            # yield (" " * 2048).encode('utf-8')
            for token in ask_bedrock(history, user_message, user_id):
                collected_tokens.append(token)
                yield token.encode('utf-8')
                # Ensure each token is sent immediately
                yield b""  
            
            try:
                # Finalize the response and save the chat message to DynamoDB
                full_response = "".join(collected_tokens)
                save_chat_message(user_id, user_message, full_response)
                logger.info(f"Successfully saved chat for user {user_id}")
            except Exception as db_error:
                logger.error(f"Failed to save message to DB: {str(db_error)}")


        return StreamingResponse(
            stream_generator(),
            media_type="text/event-stream",
            headers={
                # "Access-Control-Allow-Origin": "*",
                # "Access-Control-Allow-Methods": "POST, OPTIONS, GET",
                "X-Accel-Buffering": "no",
                "Cache-Control": "no-cache, no-transform",
                "Transfer-Encoding": "chunked",
            }
        )
    
    except Exception as e:
        logger.error(f"Error in chat endpoint: {str(e)}")
        # Return a proper 500 error WITH the CORS headers!
        return JSONResponse(
            status_code=500,
            content={"error": f"Internal Server Error: {str(e)}"},
            headers={
                "Access-Control-Allow-Origin": os.environ['CLOUDFRONT_URL'],
                "Access-Control-Allow-Methods": "POST, OPTIONS, GET",
                "Access-Control-Allow-Headers": "Content-Type, Authorization",
            }
        )