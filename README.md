# Hydration Assistant: Dehydration Detection and Chatbot Dashboard

## Overview

This project is a full-stack application for monitoring hydration status using biosensor data and machine learning models. It features:
- A React-based frontend dashboard and chat interface.
- A Flask backend serving both a chatbot (powered by OpenAI GPT) and real-time hydration predictions using various ML models.
- Data processing and model training scripts for hydration/stress detection from physiological signals.

---

## Table of Contents

- [Features](#features)
- [Directory Structure](#directory-structure)
- [Backend (Flask API)](#backend-flask-api)
- [Frontend (React)](#frontend-react)
- [Machine Learning Models](#machine-learning-models)
- [Data Preparation](#data-preparation)
- [How to Run](#how-to-run)
- [Configuration](#configuration)
- [File Descriptions](#file-descriptions)
- [License](#license)

---

## Features

- Live Heart Rate Monitoring: Simulated or real-time heart rate data.
- Hydration Status Prediction: Uses an Artificial Neural Network (ANN) and other models to predict hydration.
- Chatbot Assistant: Interact with a hydration-focused assistant powered by OpenAI GPT.
- Model Training Scripts: Includes scripts for ANN, SVM, Naive Bayes, Random Forest, and Linear Regression.
- Data Merging and Preprocessing: Utilities for combining and cleaning biosensor datasets.

---

## Directory Structure

```
Dehydration/
  data/                # Datasets, ML scripts, and backend template
    templates/         # Flask HTML templates
  frontend/            # React frontend app
    src/               # React components and main app
  polar h10/           # Flask backend, ANN model, scaler, and templates
  merging.py           # Script to merge raw sensor data
```

---

## Backend (Flask API)

### Main API Endpoints

- `/hr`  
  Returns simulated (or real) heart rate and hydration status prediction.

- `/api/chat`  
  Accepts POST requests with a user message and streams a chatbot response using OpenAI GPT.

- `/clear`  
  Clears the chat session.

### Main Files

- `polar h10/app2.py`:  
  Main Flask API for the React frontend. Loads the ANN model and scaler, simulates heart rate, and provides hydration predictions and chat responses.

- `data/chatbotapp.py`:  
  Alternative Flask app for a web-based dashboard using server-rendered HTML.

- `polar h10/ann_model.h5`, `polar h10/ann_scaler.pkl`:  
  Trained ANN model and scaler for hydration prediction.

---

## Frontend (React)

- Located in `frontend/`
- Main entry: `frontend/src/App.jsx`
- Components:
  - `ChatBox.jsx`: Chat interface with the hydration assistant.
  - `Sidebar.jsx`: Chat navigation and theme toggle.
  - `Vitals.jsx`: Displays live heart rate and hydration status.
- Uses Tailwind CSS for styling.
- Communicates with the backend at `http://127.0.0.1:5000`.

---

## Machine Learning Models

All models use features from biosensor data: EDA, Temperature, Heart Rate, Accelerometer (X, Y, Z).

- **ANN (Artificial Neural Network)**:  
  - Trained in `data/ann.py`
  - Used for binary hydration classification.
- **Random Forest**:  
  - Trained in `data/randomforest.py`
  - Used for regression on stress/hydration level.
- **Linear Regression**:  
  - Trained in `data/linear.py`
  - Used for regression on stress/hydration level.
- **Naive Bayes**:  
  - Trained in `data/naivebayes.py`
  - Used for binary hydration classification.
- **SVM (Support Vector Machine)**:  
  - Trained in `data/svm.py`
  - Used for binary hydration classification.

Each script outputs predictions to CSV files for further analysis.

---

## Data Preparation

- Raw sensor data (EDA, TEMP, HR, ACC) and labels are stored in `data/`.
- Use `merging.py` to combine raw sensor files into `merged_dataset.csv` for model training.

---

## How to Run

### 1. Backend (Flask API)

```bash
cd "polar h10"
pip install flask flask-cors openai tensorflow joblib
python app2.py
```

- The API will be available at `http://127.0.0.1:5000`.

### 2. Frontend (React)

```bash
cd frontend
npm install
npm run dev
```

- The React app will run on `http://localhost:5173` (default Vite port).

### 3. Model Training

To retrain models or generate predictions, run the scripts in `data/`:

```bash
cd data
python ann.py
python randomforest.py
python linear.py
python naivebayes.py
python svm.py
```

### 4. Data Merging

If you have new raw sensor data, run:

```bash
python merging.py
```

---

## Configuration

- **OpenAI API Key**:  
  Set your OpenAI API key in `polar h10/app2.py` and `data/chatbotapp.py` for chatbot functionality.
- **Model Files**:  
  Ensure `ann_model.h5` and `ann_scaler.pkl` are present in `polar h10/`.

---

## File Descriptions

- `data/`:  
  - `ann.py`, `randomforest.py`, `linear.py`, `naivebayes.py`, `svm.py`: Model training and evaluation scripts.
  - `chatbotapp.py`: Flask app for web dashboard.
  - `compare.py`: Script to compare model results.
  - `merged_dataset.csv`: Combined dataset for model training.
  - `*.csv`: Raw and processed data files.

- `polar h10/`:  
  - `app2.py`: Main Flask API for the React frontend.
  - `chatbot2.py`: Alternative Flask app.
  - `ann_model.h5`, `ann_scaler.pkl`: Trained ANN model and scaler.

- `frontend/`:  
  - `src/`: React components and main app.
  - `index.html`: App entry point.
  - `package.json`: Frontend dependencies and scripts.

- `merging.py`:  
  Script to merge raw sensor data into a single dataset.

---

## License

Specify your license here. 