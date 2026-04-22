import json
import logging
import boto3
import os

from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse, JSONResponse

from starlette.background import BackgroundTask

from fastapi.middleware.cors import CORSMiddleware

from db_serice import get_chat_history, save_chat_message
from ai_service import ask_bedrock

# Logging for CloudWatch
logger = logging.getLogger()
logger.setLevel(logging.INFO)

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
            yield (" " * 2048).encode('utf-8')
            for token in ask_bedrock(history, user_message):
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