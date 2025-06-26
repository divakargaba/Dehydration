from flask import Flask, request, session, jsonify, Response
from flask_cors import CORS
import openai
import tensorflow as tf
import joblib
import random
import time

app = Flask(__name__)
CORS(app)
app.secret_key = "" # Enter your API key

# Load OpenAI GPT client
client = openai.OpenAI(api_key="") # Enter your API key

# Load ANN model + scaler
ann_model = tf.keras.models.load_model("ann_model.h5")
scaler = joblib.load("ann_scaler.pkl")

# Simulated heart rate (replace with Polar H10 live data later)
latest_hr = random.randint(60, 90)

# Hydration prediction via ANN
def predict_hydration(hr_value):
    try:
        features = [[0.1, 31.5, hr_value, -10, 28, 56]]  # Example 6-feature input
        scaled = scaler.transform(features)
        prob = ann_model.predict(scaled)[0][0]
        return "Dehydrated" if prob > 0.5 else "Well Hydrated"
    except Exception as e:
        return f"Prediction Error: {e}"

@app.route("/hr")
def get_hr():
    global latest_hr
    latest_hr = random.randint(60, 100)  # Simulated
    return jsonify({
        "heart_rate": latest_hr,
        "status": predict_hydration(latest_hr)
    })

@app.route("/api/chat", methods=["POST"])
def api_chat():
    data = request.get_json()
    user_message = data.get("message", "")
    if not user_message:
        return jsonify({"error": "Empty message"}), 400

    def stream_response():
        try:
            conversation = [
                {"role": "system", "content": "You are a hydration assistant. Use vitals like heart rate to give health advice."},
                {"role": "user", "content": user_message}
            ]
            response = client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=conversation,
                stream=True
            )

            for chunk in response:
                content = chunk.choices[0].delta.content
                if content:
                    time.sleep(0.08)  # Natural pause
                    yield content
        except Exception as e:
            yield f"[Error] {e}"

    return Response(stream_response(), mimetype="text/plain")

@app.route("/clear")
def clear():
    session.clear()
    return "<script>window.location='/'</script>"

if __name__ == "__main__":
    app.run(debug=True)


