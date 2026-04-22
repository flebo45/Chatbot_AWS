import json
import logging
import boto3
import os

from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse

from starlette.background import BackgroundTask

from db_serice import get_chat_history, save_chat_message
from ai_service import ask_bedrock

# Logging for CloudWatch
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize FastAPI app
app = FastAPI()

@app.post("/{full_path:path}")
async def chat_endpoint(request: Request):
    try:
        body = await request.json()
        user_message = body.get("message", "")
        user_id = body.get("user_id", "anonymous")

        if not user_message:
            return {"error": "Message is required"}

        history = get_chat_history(user_id)
        collected_tokens = []

        def stream_generator():
            yield (" " * 2048).encode('utf-8')
            for token in ask_bedrock(history, user_message):
                collected_tokens.append(token)
                yield token.encode('utf-8')
                # Ensure each token is sent immediately
                yield b""  
        
        async def save_after_stream():
            full_response = "".join(collected_tokens)
            save_chat_message(user_id, user_message, full_response)


        return StreamingResponse(
            stream_generator(),
            media_type="text/plain",
            headers={
                # "Access-Control-Allow-Origin": "*",
                # "Access-Control-Allow-Methods": "POST, OPTIONS, GET",
                "X-Accel-Buffering": "no",
                "Cache-Control": "no-cache, no-transform",
                "Transfer-Encoding": "chunked",
            },
            background=BackgroundTask(
                lambda: save_chat_message(user_id, user_message, "".join(collected_tokens))
            ),
        )
    
    except Exception as e:
        logger.error(f"Error in chat endpoint: {str(e)}")
        return {"error": "An error occurred while processing your request."}