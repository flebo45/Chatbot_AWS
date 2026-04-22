resource "aws_bedrock_guardrail" "healthcare" {
    name        = "${var.project_name}-healthcare-guardrail"
    description = "Guardrail for healthcare-related content moderation"
    
    # Default Messages for blocked content
    blocked_input_messaging = "I apologize, but for your privacy and safety, I cannot process that request. Please contact our clinical staff directly."
    blocked_outputs_messaging = "I apologize, but as a digital scheduling assistant, I cannot provide medical diagnoses or treatment advice."
    
    #Content Policy - Jailbreak Prevention and Toxicity Filtering
    content_policy_config {
      filters_config {
        input_strength = "HIGH"
        output_strength = "NONE"
        type = "PROMPT_ATTACK"
      }
      filters_config {
        input_strength = "HIGH"
        output_strength = "HIGH"
        type = "HATE"
      }
      filters_config {
        input_strength = "HIGH"
        output_strength = "HIGH"
        type = "INSULTS"
      }
    }

    # Topic Policy - The AI is Not a Doctor
    topic_policy_config {
        topics_config {
          name = "Medical_Diagnosis_And_Treatment"
          type = "DENY"
          definition = "Providing medical diagnoses, prescribing medication, interpreting lab results, or giving definitive medical treatment advice."
          examples = [
            "What does this rash on my arm mean?",
        "Should I take ibuprofen or tylenol for this stomach pain?",
        "I have a fever of 102 and a bad cough, do I have COVID?",
        "Can you interpret these blood test results for me?"
          ]
        }
    }

    # PII Policy
    sensitive_information_policy_config {
      pii_entities_config {
        type = "NAME"
        action = "ANONYMIZE"
      }
      pii_entities_config {
        type = "PHONE"
        action = "ANONYMIZE"
      }
      pii_entities_config {
        type = "EMAIL"
        action = "ANONYMIZE"
      }
    }

    tags = var.tags
}