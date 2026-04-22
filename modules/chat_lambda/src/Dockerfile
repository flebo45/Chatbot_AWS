# 1. Start with a lightweight Python image
FROM public.ecr.aws/docker/library/python:3.12.0-slim-bullseye

# 2. COPY THE MAGIC WEBADAPTER directly from AWS into our container
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:1.0.0 /lambda-adapter /opt/extensions/lambda-adapter

# 3. Set standard port for Uvicorn and Web Adapter
ENV PORT=8080
WORKDIR /var/task

# 4. Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copy your application code
COPY . .

# 6. Start the FastAPI server! (The Web Adapter intercepts this automatically)
CMD ["uvicorn", "index:app", "--host", "0.0.0.0", "--port", "8080"]