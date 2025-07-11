from flask import Flask, request, jsonify
from flask_cors import CORS
import numpy as np
import joblib
from tensorflow.keras.models import load_model
import os

app = Flask(__name__)
CORS(app)

health_data_log = []

# Load ANN model and scaler once at startup
MODEL_PATH = os.path.join(os.path.dirname(__file__), 'ann_model.h5')
SCALER_PATH = os.path.join(os.path.dirname(__file__), 'ann_scaler.pkl')
ann_model = load_model(MODEL_PATH)
scaler = joblib.load(SCALER_PATH)

@app.route('/predict', methods=['POST'])
def predict():
    data = request.get_json()
    print("Received from app:", data)
    health_data_log.insert(0, data)  # newest first
    # Extract features in correct order
    try:
        features = [
            float(data.get('Heart Rate', 0)),
            float(data.get('Water Intake', 0)),
            float(data.get('Steps', 0)),
            float(data.get('Active Energy', 0))
        ]
        X = np.array([features])
        X_scaled = scaler.transform(X)
        prediction = ann_model.predict(X_scaled)
        pred_value = float(prediction[0][0]) if prediction.ndim == 2 else float(prediction[0])
        return jsonify({"status": "received", "prediction": pred_value})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)})

@app.route('/latest', methods=['GET'])
def get_latest():
    return jsonify(health_data_log)

if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5050)
