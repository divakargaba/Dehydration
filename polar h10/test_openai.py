import openai
from dotenv import load_dotenv
import os

load_dotenv()
print('Loaded key:', os.getenv('OPENAI_API_KEY'))
client = openai.OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
try:
    resp = client.chat.completions.create(
        model="gpt-3.5-turbo",
        messages=[{"role": "user", "content": "Hello"}]
    )
    print("Success:", resp)
except Exception as e:
    print("Error:", e)