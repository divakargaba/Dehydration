# chatbotapp.py (Debug-Friendly with placeholder ANN and GPT)

from flask import Flask, render_template, request, session
import openai
import tensorflow as tf
import joblib
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv('FLASK_SECRET_KEY', 'default-secret-key')

# Load GPT client
client = openai.OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

# Load ANN model and scaler
ann_model = tf.keras.models.load_model("ann_model.h5")
scaler = joblib.load("../polar h10/ann_scaler.pkl")

# GPT wrapper
def gpt_response(conversation):
    try:
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=conversation
        )
        return response.choices[0].message.content
    except Exception as e:
        return f"Error contacting GPT: {e}"

# Dummy ANN parser (debug safe)
def ann_prediction(message):
    try:
        # Simulate ANN inference for safety
        return "Predicted: Hydrated (debug)"
    except Exception as e:
        return f"Model error: {e}"

@app.route("/", methods=["GET", "POST"])
def index():
    if "history" not in session:
        session["history"] = []

    user_message = ""
    bot_reply = ""

    if request.method == "POST":
        user_message = request.form["message"]
        session["history"].append({"role": "user", "content": user_message})

        # ANN logic (disabled real prediction temporarily)
        ann_result = ann_prediction(user_message)
        session["history"].append({"role": "assistant", "content": ann_result})

        # GPT logic
        gpt_reply = gpt_response([{"role": "system", "content": "You are a hydration health assistant."}] + session["history"])
        bot_reply = gpt_reply
        session["history"].append({"role": "assistant", "content": bot_reply})

    print("=== SESSION HISTORY ===")
    for item in session["history"]:
        print(f"{item['role']}: {item['content']}")

    return render_template("index.html", history=session["history"])

@app.route("/clear")
def clear():
    session.clear()
    return "<script>window.location='/'</script>"

if __name__ == "__main__":
    app.run(debug=True)




