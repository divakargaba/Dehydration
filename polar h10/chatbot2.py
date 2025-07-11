from flask import Flask, render_template, request, session, jsonify
import openai
import tensorflow as tf
import joblib
import os
import random
import requests  # Add this import at the top
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv('FLASK_SECRET_KEY', 'default-secret-key')

# Load GPT client
client = openai.OpenAI(api_key=os.getenv('OPENAI_API_KEY'))


# Load ANN model and scaler
ann_model = tf.keras.models.load_model("ann_model.h5")
scaler = joblib.load("ann_scaler.pkl")

# Dummy live heart rate value (simulate for now)
latest_heart_rate = 75

@app.route("/hr")
def get_hr():
    global latest_heart_rate
    # Simulate HR changing
    latest_heart_rate = random.randint(60, 100)
    return jsonify({"heart_rate": latest_heart_rate})

@app.route("/", methods=["GET", "POST"])
def index():
    if "history" not in session:
        session["history"] = []

    user_message = ""
    bot_reply = ""

    if request.method == "POST":
        user_message = request.form["message"]
        session["history"].append({"role": "user", "content": user_message})

        # Fetch latest vitals and ANN status
        try:
            vitals = requests.get("http://localhost:5000/latest_metrics").json()
        except Exception:
            vitals = {}
        try:
            ann = requests.get("http://localhost:5000/predict_ann").json()
        except Exception:
            ann = {"status": "Unknown", "prediction": None}
        # Build vitals string
        vitals_str = (
            f"Body Temp: {vitals.get('Body Temp', 'N/A')}°C\n"
            f"Heart Rate: {vitals.get('Heart Rate', 'N/A')} bpm\n"
            f"Steps: {vitals.get('Steps', 'N/A')}\n"
            f"Active Energy: {vitals.get('Active Energy', 'N/A')}\n"
            f"Water Intake: {vitals.get('Water Intake', 'N/A')}\n"
        )
        status_str = ann.get("status", "Unknown")
        # Compose system prompt
        system_prompt = (
            "You are a hydration assistant. Always answer in this format: "
            "1. List the user's current vitals. 2. Clearly state if the user is dehydrated or well hydrated based on the status below. 3. Give hydration advice.\n"
            f"Current Vitals:\n{vitals_str}Hydration Status: {status_str}.\n"
        )
        gpt_reply = gpt_response([
            {"role": "system", "content": system_prompt},
            *session["history"]
        ])
        bot_reply = gpt_reply
        session["history"].append({"role": "assistant", "content": bot_reply})

    return render_template("dashboard.html", history=session["history"])

@app.route("/clear")
def clear():
    session.clear()
    return "<script>window.location='/'</script>"

def gpt_response(conversation):
    try:
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=conversation
        )
        return response.choices[0].message.content
    except Exception as e:
        return f"Error contacting GPT: {e}"

if __name__ == "__main__":
    app.run(debug=True)
