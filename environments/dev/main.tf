module "chatbot_backend" {
  source        = "../../modules/chat_lambda"
  
  function_name = "chatbot_backend"
  source_file   = "../../src/chat_handler.py"
  runtime       = "python3.8"
}
# dynamodb, bedrock ecc.