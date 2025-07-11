from flask import Flask, request, session, jsonify, Response
from flask_cors import CORS
import openai
import tensorflow as tf
import joblib
import random
import time
import pandas as pd
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = Flask(__name__)
CORS(app)
app.secret_key = os.getenv('FLASK_SECRET_KEY', 'default-secret-key')

# Load OpenAI GPT client
client = openai.OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

# Load ANN model + scaler
ann_model = tf.keras.models.load_model("ann_model.h5")
scaler = joblib.load("ann_scaler.pkl")

# Simulated heart rate (replace with Polar H10 live data later)
latest_hr = random.randint(60, 90)
real_hr = None  # Store real heart rate if provided

# Store latest metrics globally
latest_metrics = {
    'Body Temp': 0.0,
    'Heart Rate': 0.0,
    'Acc_X': 0.0,
    'Acc_Y': 0.0,
    'Acc_Z': 0.0,
    'Steps': 0,
    'Active Energy': 0.0,
    'Water Intake': 0.0
}

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
    global latest_hr, real_hr
    if real_hr is not None:
        hr_value = real_hr
    else:
        hr_value = random.randint(60, 100)  # Simulated
    latest_hr = hr_value
    return jsonify({
        "heart_rate": latest_hr,
        "status": predict_hydration(latest_hr)
    })

@app.route("/update_hr", methods=["POST"])
def update_hr():
    global real_hr
    data = request.get_json()
    if not data or "heart_rate" not in data:
        return jsonify({"error": "Missing heart_rate in request"}), 400
    try:
        real_hr = int(data["heart_rate"])
        return jsonify({"message": "Heart rate updated", "heart_rate": real_hr})
    except Exception as e:
        return jsonify({"error": str(e)}), 400

@app.route('/update_metrics', methods=['POST'])
def update_metrics():
    global latest_metrics
    data = request.get_json()
    print(f"[Flask] Received data from Swift: {data}")
    # Update only the keys present in the incoming data
    for k, v in data.items():
        try:
            latest_metrics[k] = float(v)
        except (ValueError, TypeError):
            latest_metrics[k] = v
    print(f"[Flask] After update, before display keys: {latest_metrics}")
    # Always set display keys to match ANN keys
    latest_metrics['Body Temp'] = float(latest_metrics.get('Temp', 0.0))
    latest_metrics['Heart Rate'] = float(latest_metrics.get('HR', 0.0))
    print(f"[Flask] After setting display keys: {latest_metrics}")
    return jsonify({"status": "success"})

@app.route("/predict_ann", methods=["POST", "GET"])
def predict_ann():
    if request.method == "POST":
        data = request.get_json()
    else:
        data = latest_metrics
    try:
        # Map possible alternate names to the correct feature names
        temp = float(data.get('Temp', data.get('Body Temp', 0)))
        hr = float(data.get('HR', data.get('Heart Rate', 0)))
        acc_x = float(data.get('Acc_X', 0))
        acc_y = float(data.get('Acc_Y', 0))
        acc_z = float(data.get('Acc_Z', 0))
        water_intake = float(data.get('Water Intake', 0))
        features = [
            temp,
            hr,
            acc_x,
            acc_y,
            acc_z
        ]
        columns = ['Temp', 'HR', 'Acc_X', 'Acc_Y', 'Acc_Z']
        X_df = pd.DataFrame([features], columns=columns)
        X_scaled = scaler.transform(X_df)
        prediction = ann_model.predict(X_scaled)[0][0]
        ann_status = "Dehydrated" if prediction > 0.5 else "Well Hydrated"
        # Combine with water intake threshold (1.5L)
        if water_intake >= 1.5:
            if ann_status == "Dehydrated":
                status = "Likely Well Hydrated (good water intake, but physiological signs suggest dehydration)"
            else:
                status = "Well Hydrated"
        else:
            if ann_status == "Dehydrated":
                status = "Dehydrated"
            else:
                status = "Well Hydrated, but drink more water!"
        return jsonify({
            "prediction": float(prediction),
            "status": status,
            "ann_status": ann_status,
            "water_intake": water_intake
        })
    except Exception as e:
        print("[Flask] ANN prediction error:", e)
        return jsonify({"prediction": "error", "status": "Error", "error": str(e)})

@app.route("/api/chat", methods=["POST"])
def api_chat():
    import requests
    data = request.get_json()
    user_message = data.get("message", "")
    if not user_message:
        return jsonify({"error": "Empty message"}), 400

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

    def stream_response():
        try:
            conversation = [
                {"role": "system", "content": system_prompt},
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
                    time.sleep(0.08)
                    yield content
        except Exception as e:
            yield f"[Error] {e}"

    return Response(stream_response(), mimetype="text/plain")

@app.route("/latest_metrics", methods=["GET"])
def get_latest_metrics():
    return jsonify(latest_metrics)

@app.route("/clear")
def clear():
    session.clear()
    return "<script>window.location='/'</script>"

if __name__ == "__main__":
    # For testing, run with debug=False to avoid auto-reload resetting globals
    app.run(host="0.0.0.0", port=5000, debug=False)


