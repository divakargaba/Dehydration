from flask import Flask, render_template, request, session, jsonify
import openai
import tensorflow as tf
import joblib
import os
import random

app = Flask(__name__)
app.secret_key = "" # Enter key


# Load GPT client
client = openai.OpenAI(api_key="") # Enter key


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

        # GPT logic
        gpt_reply = gpt_response([{"role": "system", "content": "You are a hydration assistant that considers user input and current heart rate to assess hydration."}] + session["history"])
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
