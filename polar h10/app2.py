from flask import Flask, request, session, jsonify, Response
from flask_cors import CORS
import openai
import tensorflow as tf
import joblib
import random
import time
import pandas as pd
import os
import sqlite3
from datetime import datetime, timedelta
from dotenv import load_dotenv
from collections import deque
import pickle
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
import numpy as np
import requests
import json
import threading
from sklearn.svm import SVC
from sklearn.ensemble import VotingClassifier
from sklearn.metrics import accuracy_score, precision_recall_fscore_support

load_dotenv()

client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

app = Flask(__name__)
CORS(app)
app.secret_key = os.getenv('FLASK_SECRET_KEY', 'default-secret-key')

# Database setup
DATABASE = 'health_data.db'

def init_db():
    """Initialize the database with required tables"""
    conn = sqlite3.connect(DATABASE)
    c = conn.cursor()
    
    # Create user_metrics table
    c.execute('''
        CREATE TABLE IF NOT EXISTS user_metrics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            timestamp DATETIME NOT NULL,
            heart_rate FLOAT,
            body_temp FLOAT,
            steps INTEGER,
            water_intake FLOAT,
            active_energy FLOAT,
            acc_x FLOAT,
            acc_y FLOAT,
            acc_z FLOAT,
            dehydration_risk TEXT,
            ml_prediction FLOAT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Create users table for basic user info
    c.execute('''
        CREATE TABLE IF NOT EXISTS users (
            user_id TEXT PRIMARY KEY,
            name TEXT,
            email TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            last_active DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Create alerts table
    c.execute('''
        CREATE TABLE IF NOT EXISTS alerts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            alert_type TEXT NOT NULL,
            message TEXT NOT NULL,
            risk_level FLOAT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            is_read BOOLEAN DEFAULT FALSE
        )
    ''')
    
    # Create notifications table
    c.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            notification_type TEXT NOT NULL,
            urgency TEXT NOT NULL,
            message TEXT NOT NULL,
            data TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            is_read BOOLEAN DEFAULT FALSE
        )
    ''')
    
    # Create achievements table
    c.execute('''
        CREATE TABLE IF NOT EXISTS achievements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            achievement_type TEXT NOT NULL,
            message TEXT NOT NULL,
            earned_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Create social connections table
    c.execute('''
        CREATE TABLE IF NOT EXISTS social_connections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            friend_id TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(user_id, friend_id)
        )
    ''')
    
    conn.commit()
    conn.close()

def get_db():
    """Get database connection"""
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

def store_user_metrics(user_id, metrics_data):
    """Store user metrics in database"""
    conn = get_db()
    c = conn.cursor()
    
    try:
        c.execute('''
            INSERT INTO user_metrics 
            (user_id, timestamp, heart_rate, body_temp, steps, water_intake, 
             active_energy, acc_x, acc_y, acc_z, dehydration_risk, ml_prediction)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            user_id,
            datetime.now(),
            metrics_data.get('HR', 0),
            metrics_data.get('Temp', 0),
            metrics_data.get('Steps', 0),
            metrics_data.get('Water Intake', 0),
            metrics_data.get('Active Energy', 0),
            metrics_data.get('Acc_X', 0),
            metrics_data.get('Acc_Y', 0),
            metrics_data.get('Acc_Z', 0),
            metrics_data.get('dehydration_risk', 'Unknown'),
            metrics_data.get('ml_prediction', 0)
        ))
        
        # Update user's last active time
        c.execute('''
            INSERT OR REPLACE INTO users (user_id, last_active)
            VALUES (?, ?)
        ''', (user_id, datetime.now()))
        
        conn.commit()
        return True
    except Exception as e:
        print(f"Error storing metrics: {e}")
        return False
    finally:
        conn.close()

def get_user_metrics(user_id, days=7):
    """Get user metrics for the last N days"""
    conn = get_db()
    c = conn.cursor()
    
    try:
        c.execute('''
            SELECT * FROM user_metrics 
            WHERE user_id = ? AND timestamp >= datetime('now', '-{} days')
            ORDER BY timestamp DESC
        '''.format(days), (user_id,))
        
        rows = c.fetchall()
        return [dict(row) for row in rows]
    except Exception as e:
        print(f"Error getting metrics: {e}")
        return []
    finally:
        conn.close()

def get_user_baseline(user_id, days=30):
    """Calculate user's baseline metrics"""
    metrics = get_user_metrics(user_id, days)
    if not metrics:
        return None
    
    baseline = {
        'avg_heart_rate': sum(m['heart_rate'] for m in metrics if m['heart_rate']) / len(metrics),
        'avg_body_temp': sum(m['body_temp'] for m in metrics if m['body_temp']) / len(metrics),
        'avg_steps': sum(m['steps'] for m in metrics if m['steps']) / len(metrics),
        'avg_water_intake': sum(m['water_intake'] for m in metrics if m['water_intake']) / len(metrics),
        'total_records': len(metrics)
    }
    
    return baseline

def create_alert(user_id, alert_type, message, risk_level):
    """Create an alert for a user"""
    conn = get_db()
    c = conn.cursor()
    
    try:
        c.execute('''
            INSERT INTO alerts (user_id, alert_type, message, risk_level)
            VALUES (?, ?, ?, ?)
        ''', (user_id, alert_type, message, risk_level))
        conn.commit()
        return True
    except Exception as e:
        print(f"Error creating alert: {e}")
        return False
    finally:
        conn.close()

def get_user_alerts(user_id, unread_only=True):
    """Get alerts for a user"""
    conn = get_db()
    c = conn.cursor()
    
    try:
        if unread_only:
            c.execute('''
                SELECT * FROM alerts 
                WHERE user_id = ? AND is_read = FALSE
                ORDER BY timestamp DESC
            ''', (user_id,))
        else:
            c.execute('''
                SELECT * FROM alerts 
                WHERE user_id = ?
                ORDER BY timestamp DESC
            ''', (user_id,))
        
        rows = c.fetchall()
        return [dict(row) for row in rows]
    except Exception as e:
        print(f"Error getting alerts: {e}")
        return []
    finally:
        conn.close()

# Initialize database on startup
init_db()

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

# Buffer for last 60 minutes of vitals (assuming 1 sample per minute, adjust as needed)
vitals_buffer = deque(maxlen=60)  # Each entry: {timestamp, metrics...}

# Hydration prediction via ANN
def predict_hydration(hr_value):
    try:
        features = [[0.1, 31.5, hr_value, -10, 28, 56]]  # Example 6-feature input
        scaled = scaler.transform(features)
        prob = ann_model.predict(scaled)[0][0]
        return "Dehydrated" if prob > 0.5 else "Well Hydrated"
    except Exception as e:
        return f"Prediction Error: {e}"

def train_personal_model(user_id, min_records=50):
    """Train a personalized model for a specific user"""
    # Get user's historical data
    user_data = get_user_metrics(user_id, days=30)
    
    if len(user_data) < min_records:
        print(f"Not enough data for user {user_id}. Need at least {min_records} records, got {len(user_data)}")
        return False
    
    try:
        # Prepare features and labels
        features = []
        labels = []
        
        for record in user_data:
            # Features: heart_rate, body_temp, steps, water_intake, active_energy, acc_x, acc_y, acc_z
            feature_vector = [
                record.get('heart_rate', 0),
                record.get('body_temp', 0),
                record.get('steps', 0),
                record.get('water_intake', 0),
                record.get('active_energy', 0),
                record.get('acc_x', 0),
                record.get('acc_y', 0),
                record.get('acc_z', 0)
            ]
            
            # Label: dehydration risk (1 if high risk, 0 if low)
            risk_label = 1 if record.get('ml_prediction', 0) > 0.5 else 0
            
            features.append(feature_vector)
            labels.append(risk_label)
        
        # Convert to numpy arrays
        X = np.array(features)
        y = np.array(labels)
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
        
        # Train personal model
        personal_model = RandomForestClassifier(n_estimators=100, random_state=42)
        personal_model.fit(X_train, y_train)
        
        # Evaluate model
        train_score = personal_model.score(X_train, y_train)
        test_score = personal_model.score(X_test, y_test)
        
        print(f"Personal model for user {user_id}:")
        print(f"Training accuracy: {train_score:.3f}")
        print(f"Test accuracy: {test_score:.3f}")
        
        # Save personal model
        model_path = f"personal_models/user_{user_id}_model.pkl"
        os.makedirs("personal_models", exist_ok=True)
        
        with open(model_path, 'wb') as f:
            pickle.dump(personal_model, f)
        
        # Save personal scaler
        scaler_path = f"personal_models/user_{user_id}_scaler.pkl"
        personal_scaler = StandardScaler()
        personal_scaler.fit(X_train)
        
        with open(scaler_path, 'wb') as f:
            pickle.dump(personal_scaler, f)
        
        return True
        
    except Exception as e:
        print(f"Error training personal model for user {user_id}: {e}")
        return False

def load_personal_model(user_id):
    """Load a user's personal model"""
    try:
        model_path = f"personal_models/user_{user_id}_model.pkl"
        scaler_path = f"personal_models/user_{user_id}_scaler.pkl"
        
        if not os.path.exists(model_path) or not os.path.exists(scaler_path):
            return None, None
        
        with open(model_path, 'rb') as f:
            model = pickle.load(f)
        
        with open(scaler_path, 'rb') as f:
            scaler = pickle.load(f)
        
        return model, scaler
        
    except Exception as e:
        print(f"Error loading personal model for user {user_id}: {e}")
        return None, None

def predict_personal_dehydration(user_id, current_metrics):
    """Predict dehydration using user's personal model"""
    try:
        # Try to load personal model first
        personal_model, personal_scaler = load_personal_model(user_id)
        
        if personal_model is not None and personal_scaler is not None:
            # Use personal model
            features = [
                current_metrics.get('heart_rate', 0),
                current_metrics.get('body_temp', 0),
                current_metrics.get('steps', 0),
                current_metrics.get('water_intake', 0),
                current_metrics.get('active_energy', 0),
                current_metrics.get('acc_x', 0),
                current_metrics.get('acc_y', 0),
                current_metrics.get('acc_z', 0)
            ]
            
            X = np.array([features])
            X_scaled = personal_scaler.transform(X)
            
            # Get prediction probability
            prediction = personal_model.predict_proba(X_scaled)[0][1]  # Probability of dehydration
            
            return {
                'prediction': float(prediction),
                'model_type': 'personal',
                'confidence': 'high'
            }
        else:
            # Fall back to global model
            return predict_global_dehydration(current_metrics)
            
    except Exception as e:
        print(f"Error in personal prediction for user {user_id}: {e}")
        return predict_global_dehydration(current_metrics)

def predict_global_dehydration(current_metrics):
    """Predict dehydration using the global ANN model"""
    try:
        temp = float(current_metrics.get('body_temp', 0))
        hr = float(current_metrics.get('heart_rate', 0))
        acc_x = float(current_metrics.get('acc_x', 0))
        acc_y = float(current_metrics.get('acc_y', 0))
        acc_z = float(current_metrics.get('acc_z', 0))
        
        features = [temp, hr, acc_x, acc_y, acc_z]
        columns = ['Temp', 'HR', 'Acc_X', 'Acc_Y', 'Acc_Z']
        X_df = pd.DataFrame([features], columns=columns)
        X_scaled = scaler.transform(X_df)
        prediction = ann_model.predict(X_scaled)[0][0]
        
        return {
            'prediction': float(prediction),
            'model_type': 'global',
            'confidence': 'medium'
        }
        
    except Exception as e:
        print(f"Error in global prediction: {e}")
        return {
            'prediction': 0.5,
            'model_type': 'fallback',
            'confidence': 'low'
        }

def get_personal_recommendations(user_id, current_metrics, prediction_result):
    """Generate personalized recommendations based on user's patterns"""
    try:
        # Get user's baseline
        baseline = get_user_baseline(user_id, days=30)
        
        if baseline is None:
            return get_general_recommendations(current_metrics, prediction_result)
        
        # Get recent trends
        recent_metrics = get_user_metrics(user_id, days=1)
        
        if not recent_metrics:
            return get_general_recommendations(current_metrics, prediction_result)
        
        # Calculate trends
        avg_hr = sum(m['heart_rate'] for m in recent_metrics if m['heart_rate']) / len(recent_metrics)
        avg_water = sum(m['water_intake'] for m in recent_metrics if m['water_intake']) / len(recent_metrics)
        
        recommendations = []
        
        # Personalized recommendations based on patterns
        if prediction_result['prediction'] > 0.7:
            recommendations.append("🚨 HIGH RISK: Drink water immediately!")
            recommendations.append("Consider taking a break from physical activity")
        elif prediction_result['prediction'] > 0.5:
            recommendations.append("⚠️ Moderate dehydration risk detected")
            recommendations.append("Increase your water intake")
        
        # Compare to personal baseline
        if avg_hr > baseline['avg_heart_rate'] * 1.1:
            recommendations.append("Your heart rate is higher than usual - consider resting")
        
        if avg_water < baseline['avg_water_intake'] * 0.8:
            recommendations.append("You're drinking less water than usual - increase intake")
        
        # Activity-based recommendations
        steps = current_metrics.get('steps', 0)
        if steps > 10000:
            recommendations.append("High activity detected - drink extra water")
        
        # Time-based recommendations
        current_hour = datetime.now().hour
        if current_hour < 12 and avg_water < 0.5:
            recommendations.append("Morning hydration is important - drink water")
        
        if not recommendations:
            recommendations.append("You're well hydrated! Keep it up!")
        
        return recommendations
        
    except Exception as e:
        print(f"Error generating personal recommendations: {e}")
        return get_general_recommendations(current_metrics, prediction_result)

def get_general_recommendations(current_metrics, prediction_result):
    """Generate general recommendations when personal data is insufficient"""
    recommendations = []
    
    if prediction_result['prediction'] > 0.7:
        recommendations.append("🚨 HIGH RISK: Drink water immediately!")
    elif prediction_result['prediction'] > 0.5:
        recommendations.append("⚠️ Moderate dehydration risk - increase water intake")
    else:
        recommendations.append("You're well hydrated! Keep it up!")
    
    water_intake = current_metrics.get('water_intake', 0)
    if water_intake < 1.5:
        recommendations.append("Aim for at least 1.5L of water daily")
    
    return recommendations

# Weather API configuration
WEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY", "")
WEATHER_BASE_URL = "http://api.openweathermap.org/data/2.5/weather"

def get_weather_data(lat=None, lon=None):
    """Get current weather data for location"""
    try:
        # Default to a location if coordinates not provided
        if not lat or not lon:
            lat, lon = 40.7128, -74.0060  # New York default
        
        params = {
            'lat': lat,
            'lon': lon,
            'appid': WEATHER_API_KEY,
            'units': 'metric'
        }
        
        response = requests.get(WEATHER_BASE_URL, params=params, timeout=5)
        if response.status_code == 200:
            weather_data = response.json()
            return {
                'temperature': weather_data['main']['temp'],
                'humidity': weather_data['main']['humidity'],
                'feels_like': weather_data['main']['feels_like'],
                'description': weather_data['weather'][0]['description'],
                'wind_speed': weather_data['wind']['speed']
            }
        else:
            print(f"Weather API error: {response.status_code}")
            return None
    except Exception as e:
        print(f"Error fetching weather: {e}")
        return None

def adjust_hydration_for_weather(weather_data, base_recommendation):
    """Adjust hydration recommendations based on weather"""
    if not weather_data:
        return base_recommendation
    
    adjustments = []
    
    # Temperature adjustments
    temp = weather_data.get('temperature', 20)
    if temp > 30:
        adjustments.append("High temperature detected - increase water intake by 20%")
    elif temp > 25:
        adjustments.append("Warm weather - drink extra water")
    
    # Humidity adjustments
    humidity = weather_data.get('humidity', 50)
    if humidity > 70:
        adjustments.append("High humidity - you may need more water")
    
    # Wind adjustments
    wind_speed = weather_data.get('wind_speed', 0)
    if wind_speed > 20:
        adjustments.append("Windy conditions - stay hydrated")
    
    return base_recommendation + adjustments

def get_activity_correlation(user_id, days=7):
    """Analyze correlation between activity and hydration needs"""
    try:
        metrics = get_user_metrics(user_id, days)
        if len(metrics) < 10:
            return None
        
        # Group by activity level
        activity_groups = {
            'low': {'steps': 0, 'water_intake': 0, 'count': 0},
            'medium': {'steps': 0, 'water_intake': 0, 'count': 0},
            'high': {'steps': 0, 'water_intake': 0, 'count': 0}
        }
        
        for metric in metrics:
            steps = metric.get('steps', 0)
            water = metric.get('water_intake', 0)
            
            if steps < 5000:
                group = 'low'
            elif steps < 10000:
                group = 'medium'
            else:
                group = 'high'
            
            activity_groups[group]['steps'] += steps
            activity_groups[group]['water_intake'] += water
            activity_groups[group]['count'] += 1
        
        # Calculate averages
        correlations = {}
        for group, data in activity_groups.items():
            if data['count'] > 0:
                avg_steps = data['steps'] / data['count']
                avg_water = data['water_intake'] / data['count']
                correlations[group] = {
                    'avg_steps': avg_steps,
                    'avg_water': avg_water,
                    'samples': data['count']
                }
        
        return correlations
        
    except Exception as e:
        print(f"Error calculating activity correlation: {e}")
        return None

def generate_advanced_analytics(user_id, days=30):
    """Generate comprehensive health analytics"""
    try:
        metrics = get_user_metrics(user_id, days)
        if len(metrics) < 5:
            return None
        
        # Calculate various statistics
        total_steps = sum(m.get('steps', 0) for m in metrics)
        total_water = sum(m.get('water_intake', 0) for m in metrics)
        avg_heart_rate = sum(m.get('heart_rate', 0) for m in metrics if m.get('heart_rate')) / len(metrics)
        
        # Dehydration risk analysis
        high_risk_count = sum(1 for m in metrics if m.get('ml_prediction', 0) > 0.7)
        risk_percentage = (high_risk_count / len(metrics)) * 100
        
        # Trend analysis
        recent_metrics = metrics[:7]  # Last 7 days
        older_metrics = metrics[7:14] if len(metrics) > 14 else []
        
        recent_avg_water = sum(m.get('water_intake', 0) for m in recent_metrics) / len(recent_metrics)
        older_avg_water = sum(m.get('water_intake', 0) for m in older_metrics) / len(older_metrics) if older_metrics else recent_avg_water
        
        water_trend = "improving" if recent_avg_water > older_avg_water else "declining" if recent_avg_water < older_avg_water else "stable"
        
        # Best and worst days
        best_day = max(metrics, key=lambda x: x.get('water_intake', 0))
        worst_day = min(metrics, key=lambda x: x.get('water_intake', 0))
        
        analytics = {
            'summary': {
                'total_days': len(metrics),
                'total_steps': total_steps,
                'total_water_liters': total_water,
                'avg_heart_rate': round(avg_heart_rate, 1),
                'dehydration_risk_percentage': round(risk_percentage, 1)
            },
            'trends': {
                'water_intake_trend': water_trend,
                'recent_avg_water': round(recent_avg_water, 2),
                'overall_avg_water': round(total_water / len(metrics), 2)
            },
            'activity_correlation': get_activity_correlation(user_id),
            'best_day': {
                'date': best_day.get('timestamp', ''),
                'water_intake': best_day.get('water_intake', 0),
                'steps': best_day.get('steps', 0)
            },
            'worst_day': {
                'date': worst_day.get('timestamp', ''),
                'water_intake': worst_day.get('water_intake', 0),
                'steps': worst_day.get('steps', 0)
            }
        }
        
        return analytics
        
    except Exception as e:
        print(f"Error generating analytics: {e}")
        return None

def create_social_achievement(user_id, achievement_type):
    """Create social achievements for users"""
    achievements = {
        'hydration_streak': '7 days of good hydration',
        'activity_boost': '10,000+ steps with proper hydration',
        'weather_warrior': 'Maintained hydration in extreme weather',
        'consistency_king': '30 days of consistent monitoring'
    }
    
    achievement_message = achievements.get(achievement_type, 'Unknown achievement')
    
    # Store achievement in database
    conn = get_db()
    c = conn.cursor()
    
    try:
        c.execute('''
            INSERT INTO achievements (user_id, achievement_type, message, earned_at)
            VALUES (?, ?, ?, ?)
        ''', (user_id, achievement_type, achievement_message, datetime.now()))
        conn.commit()
        return True
    except Exception as e:
        print(f"Error creating achievement: {e}")
        return False
    finally:
        conn.close()

def get_user_achievements(user_id):
    """Get user's achievements"""
    conn = get_db()
    c = conn.cursor()
    
    try:
        c.execute('''
            SELECT * FROM achievements 
            WHERE user_id = ?
            ORDER BY earned_at DESC
        ''', (user_id,))
        
        rows = c.fetchall()
        return [dict(row) for row in rows]
    except Exception as e:
        print(f"Error getting achievements: {e}")
        return []
    finally:
        conn.close()

# Notification system
def create_smart_notification(user_id, notification_type, urgency, message, data=None):
    """Create smart notifications with different urgency levels"""
    notification = {
        'id': f"{user_id}_{int(time.time())}",
        'user_id': user_id,
        'type': notification_type,
        'urgency': urgency,  # 'low', 'medium', 'high', 'emergency'
        'message': message,
        'timestamp': datetime.now().isoformat(),
        'data': data or {},
        'is_read': False
    }
    
    # Store notification in database
    conn = get_db()
    c = conn.cursor()
    
    try:
        c.execute('''
            INSERT INTO notifications 
            (user_id, notification_type, urgency, message, data, timestamp, is_read)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (
            user_id, 
            notification_type, 
            urgency, 
            message, 
            json.dumps(data or {}), 
            datetime.now(),
            False
        ))
        conn.commit()
        return True
    except Exception as e:
        print(f"Error creating notification: {e}")
        return False
    finally:
        conn.close()

def get_user_notifications(user_id, unread_only=True):
    """Get user's notifications"""
    conn = get_db()
    c = conn.cursor()
    
    try:
        if unread_only:
            c.execute('''
                SELECT * FROM notifications 
                WHERE user_id = ? AND is_read = FALSE
                ORDER BY timestamp DESC
            ''', (user_id,))
        else:
            c.execute('''
                SELECT * FROM notifications 
                WHERE user_id = ?
                ORDER BY timestamp DESC
            ''', (user_id,))
        
        rows = c.fetchall()
        return [dict(row) for row in rows]
    except Exception as e:
        print(f"Error getting notifications: {e}")
        return []
    finally:
        conn.close()

def mark_notification_read(notification_id):
    """Mark a notification as read"""
    conn = get_db()
    c = conn.cursor()
    
    try:
        c.execute('''
            UPDATE notifications SET is_read = TRUE 
            WHERE id = ?
        ''', (notification_id,))
        conn.commit()
        return True
    except Exception as e:
        print(f"Error marking notification read: {e}")
        return False
    finally:
        conn.close()

def check_and_create_smart_notifications(user_id, current_metrics, prediction_result, weather_data=None):
    """Check conditions and create smart notifications"""
    try:
        # Get user's recent activity and patterns
        recent_metrics = get_user_metrics(user_id, days=1)
        baseline = get_user_baseline(user_id, days=30)
        
        notifications_created = []
        
        # 1. Risk-based notifications
        risk_level = prediction_result['prediction']
        if risk_level > 0.8:
            create_smart_notification(
                user_id, 
                'dehydration_emergency', 
                'emergency',
                "🚨 EMERGENCY: Severe dehydration risk! Drink water immediately and seek medical attention if symptoms persist.",
                {'risk_level': risk_level}
            )
            notifications_created.append('emergency')
        elif risk_level > 0.6:
            create_smart_notification(
                user_id, 
                'dehydration_high', 
                'high',
                "⚠️ High dehydration risk detected! Drink water immediately.",
                {'risk_level': risk_level}
            )
            notifications_created.append('high')
        elif risk_level > 0.4:
            create_smart_notification(
                user_id, 
                'dehydration_moderate', 
                'medium',
                "💧 Moderate dehydration risk. Consider drinking more water.",
                {'risk_level': risk_level}
            )
            notifications_created.append('moderate')
        
        # 2. Time-sensitive notifications
        current_hour = datetime.now().hour
        if current_hour < 12 and not any('morning' in n.get('type', '') for n in get_user_notifications(user_id, False)[:5]):
            create_smart_notification(
                user_id,
                'morning_hydration',
                'low',
                "🌅 Good morning! Start your day with a glass of water.",
                {'time': current_hour}
            )
            notifications_created.append('morning')
        
        # 3. Activity-triggered notifications
        steps = current_metrics.get('steps', 0)
        if steps > 8000 and not any('activity' in n.get('type', '') for n in get_user_notifications(user_id, False)[:3]):
            create_smart_notification(
                user_id,
                'activity_hydration',
                'medium',
                f"🏃‍♂️ Great activity! You've taken {steps} steps. Remember to stay hydrated!",
                {'steps': steps}
            )
            notifications_created.append('activity')
        
        # 4. Weather-adjusted notifications
        if weather_data:
            temp = weather_data.get('temperature', 20)
            humidity = weather_data.get('humidity', 50)
            
            if temp > 30 and not any('weather' in n.get('type', '') for n in get_user_notifications(user_id, False)[:3]):
                create_smart_notification(
                    user_id,
                    'weather_hot',
                    'medium',
                    f"🌡️ Hot weather alert! Temperature is {temp:.1f}°C. Increase your water intake.",
                    {'temperature': temp, 'humidity': humidity}
                )
                notifications_created.append('weather')
            elif humidity > 70 and not any('humidity' in n.get('type', '') for n in get_user_notifications(user_id, False)[:3]):
                create_smart_notification(
                    user_id,
                    'weather_humid',
                    'low',
                    f"💧 High humidity ({humidity}%). You may need more water than usual.",
                    {'temperature': temp, 'humidity': humidity}
                )
                notifications_created.append('humidity')
        
        # 5. Pattern-based notifications
        if baseline and recent_metrics:
            avg_water = sum(m.get('water_intake', 0) for m in recent_metrics) / len(recent_metrics)
            if avg_water < baseline['avg_water_intake'] * 0.7:
                create_smart_notification(
                    user_id,
                    'pattern_low_water',
                    'medium',
                    "📉 You're drinking less water than usual. Try to increase your intake.",
                    {'current_avg': avg_water, 'baseline_avg': baseline['avg_water_intake']}
                )
                notifications_created.append('pattern')
        
        return notifications_created
        
    except Exception as e:
        print(f"Error creating smart notifications: {e}")
        return []

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

def train_ensemble_model(user_id, min_records=50):
    """Train an ensemble model combining multiple algorithms"""
    # Get user's historical data
    user_data = get_user_metrics(user_id, days=30)
    
    if len(user_data) < min_records:
        print(f"Not enough data for ensemble model for user {user_id}. Need at least {min_records} records, got {len(user_data)}")
        return False
    
    try:
        # Prepare features and labels
        features = []
        labels = []
        
        for record in user_data:
            # Features: heart_rate, body_temp, steps, water_intake, active_energy, acc_x, acc_y, acc_z
            feature_vector = [
                record.get('heart_rate', 0),
                record.get('body_temp', 0),
                record.get('steps', 0),
                record.get('water_intake', 0),
                record.get('active_energy', 0),
                record.get('acc_x', 0),
                record.get('acc_y', 0),
                record.get('acc_z', 0)
            ]
            
            # Label: dehydration risk (1 if high risk, 0 if low)
            risk_label = 1 if record.get('ml_prediction', 0) > 0.5 else 0
            
            features.append(feature_vector)
            labels.append(risk_label)
        
        # Convert to numpy arrays
        X = np.array(features)
        y = np.array(labels)
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
        
        # Create individual models
        rf_model = RandomForestClassifier(n_estimators=100, random_state=42)
        svm_model = SVC(probability=True, random_state=42)
        
        # Create ensemble model
        ensemble_model = VotingClassifier(
            estimators=[
                ('rf', rf_model),
                ('svm', svm_model)
            ],
            voting='soft'  # Use probability voting
        )
        
        # Train ensemble model
        ensemble_model.fit(X_train, y_train)
        
        # Evaluate model
        train_score = ensemble_model.score(X_train, y_train)
        test_score = ensemble_model.score(X_test, y_test)
        
        # Get detailed metrics
        y_pred = ensemble_model.predict(X_test)
        precision, recall, f1, _ = precision_recall_fscore_support(y_test, y_pred, average='binary')
        
        print(f"Ensemble model for user {user_id}:")
        print(f"Training accuracy: {train_score:.3f}")
        print(f"Test accuracy: {test_score:.3f}")
        print(f"Precision: {precision:.3f}")
        print(f"Recall: {recall:.3f}")
        print(f"F1-Score: {f1:.3f}")
        
        # Save ensemble model
        model_path = f"personal_models/user_{user_id}_ensemble.pkl"
        os.makedirs("personal_models", exist_ok=True)
        
        with open(model_path, 'wb') as f:
            pickle.dump(ensemble_model, f)
        
        # Save ensemble scaler
        scaler_path = f"personal_models/user_{user_id}_ensemble_scaler.pkl"
        ensemble_scaler = StandardScaler()
        ensemble_scaler.fit(X_train)
        
        with open(scaler_path, 'wb') as f:
            pickle.dump(ensemble_scaler, f)
        
        return True
        
    except Exception as e:
        print(f"Error training ensemble model for user {user_id}: {e}")
        return False

def load_ensemble_model(user_id):
    """Load a user's ensemble model"""
    try:
        model_path = f"personal_models/user_{user_id}_ensemble.pkl"
        scaler_path = f"personal_models/user_{user_id}_ensemble_scaler.pkl"
        
        if not os.path.exists(model_path) or not os.path.exists(scaler_path):
            return None, None
        
        with open(model_path, 'rb') as f:
            model = pickle.load(f)
        
        with open(scaler_path, 'rb') as f:
            scaler = pickle.load(f)
        
        return model, scaler
        
    except Exception as e:
        print(f"Error loading ensemble model for user {user_id}: {e}")
        return None, None

def predict_with_ensemble(user_id, current_metrics):
    """Predict dehydration using ensemble model"""
    try:
        # Try to load ensemble model first
        ensemble_model, ensemble_scaler = load_ensemble_model(user_id)
        
        if ensemble_model is not None and ensemble_scaler is not None:
            # Use ensemble model
            features = [
                current_metrics.get('heart_rate', 0),
                current_metrics.get('body_temp', 0),
                current_metrics.get('steps', 0),
                current_metrics.get('water_intake', 0),
                current_metrics.get('active_energy', 0),
                current_metrics.get('acc_x', 0),
                current_metrics.get('acc_y', 0),
                current_metrics.get('acc_z', 0)
            ]
            
            X = np.array([features])
            X_scaled = ensemble_scaler.transform(X)
            
            # Get prediction probability
            prediction = ensemble_model.predict_proba(X_scaled)[0][1]  # Probability of dehydration
            
            return {
                'prediction': float(prediction),
                'model_type': 'ensemble',
                'confidence': 'very_high'
            }
        else:
            # Fall back to personal model
            return predict_personal_dehydration(user_id, current_metrics)
            
    except Exception as e:
        print(f"Error in ensemble prediction for user {user_id}: {e}")
        return predict_personal_dehydration(user_id, current_metrics)

def predict_future_dehydration(user_id, current_metrics, time_horizon_minutes=30):
    """Predict dehydration risk in the future based on current trends"""
    try:
        # Get recent metrics for trend analysis
        recent_metrics = get_user_metrics(user_id, days=1)
        
        if len(recent_metrics) < 5:
            return None
        
        # Calculate trends
        hr_trend = 0
        temp_trend = 0
        water_trend = 0
        
        if len(recent_metrics) >= 2:
            # Calculate rate of change
            recent = recent_metrics[:3]  # Last 3 readings
            older = recent_metrics[-3:] if len(recent_metrics) >= 6 else recent_metrics[-2:]
            
            if len(recent) > 0 and len(older) > 0:
                recent_avg_hr = sum(m.get('heart_rate', 0) for m in recent) / len(recent)
                older_avg_hr = sum(m.get('heart_rate', 0) for m in older) / len(older)
                hr_trend = recent_avg_hr - older_avg_hr
                
                recent_avg_temp = sum(m.get('body_temp', 0) for m in recent) / len(recent)
                older_avg_temp = sum(m.get('body_temp', 0) for m in older) / len(older)
                temp_trend = recent_avg_temp - older_avg_temp
                
                recent_avg_water = sum(m.get('water_intake', 0) for m in recent) / len(recent)
                older_avg_water = sum(m.get('water_intake', 0) for m in older) / len(older)
                water_trend = recent_avg_water - older_avg_water
        
        # Get current prediction
        current_prediction = predict_with_ensemble(user_id, current_metrics)
        current_risk = current_prediction['prediction']
        
        # Predict future risk based on trends
        future_risk = current_risk
        
        # Adjust based on trends
        if hr_trend > 5:  # Heart rate increasing
            future_risk += 0.1
        if temp_trend > 0.5:  # Temperature increasing
            future_risk += 0.15
        if water_trend < -0.5:  # Water intake decreasing
            future_risk += 0.2
        
        # Weather adjustment
        weather_data = get_weather_data()
        if weather_data:
            temp = weather_data.get('temperature', 20)
            if temp > 30:
                future_risk += 0.1
            elif temp > 25:
                future_risk += 0.05
        
        # Activity adjustment
        steps = current_metrics.get('steps', 0)
        if steps > 10000:
            future_risk += 0.1
        elif steps > 5000:
            future_risk += 0.05
        
        # Cap the risk at 1.0
        future_risk = min(future_risk, 1.0)
        
        # Determine urgency
        if future_risk > 0.8:
            urgency = "emergency"
            time_to_dehydration = "10-15 minutes"
        elif future_risk > 0.6:
            urgency = "high"
            time_to_dehydration = "20-30 minutes"
        elif future_risk > 0.4:
            urgency = "medium"
            time_to_dehydration = "30-60 minutes"
        else:
            urgency = "low"
            time_to_dehydration = "No immediate risk"
        
        return {
            'current_risk': current_risk,
            'predicted_risk': future_risk,
            'urgency': urgency,
            'time_to_dehydration': time_to_dehydration,
            'trends': {
                'heart_rate_trend': hr_trend,
                'temperature_trend': temp_trend,
                'water_intake_trend': water_trend
            }
        }
        
    except Exception as e:
        print(f"Error predicting future dehydration: {e}")
        return None

def analyze_activity_intensity(acc_x, acc_y, acc_z, steps, active_energy):
    """Analyze activity intensity based on accelerometer and activity data"""
    try:
        # Calculate movement magnitude
        movement_magnitude = np.sqrt(acc_x**2 + acc_y**2 + acc_z**2)
        
        # Determine activity level
        if steps > 10000 or active_energy > 500:
            activity_level = "high"
            intensity_score = 0.8
        elif steps > 5000 or active_energy > 200:
            activity_level = "moderate"
            intensity_score = 0.5
        elif movement_magnitude > 0.5:
            activity_level = "light"
            intensity_score = 0.3
        else:
            activity_level = "sedentary"
            intensity_score = 0.1
        
        return {
            'activity_level': activity_level,
            'intensity_score': intensity_score,
            'movement_magnitude': movement_magnitude,
            'steps': steps,
            'active_energy': active_energy
        }
    except Exception as e:
        print(f"Error analyzing activity intensity: {e}")
        return {
            'activity_level': 'unknown',
            'intensity_score': 0.0,
            'movement_magnitude': 0.0,
            'steps': steps,
            'active_energy': active_energy
        }

def get_time_based_factors():
    """Get time-based environmental factors"""
    now = datetime.now()
    hour = now.hour
    day_of_week = now.weekday()
    
    # Time-based hydration needs
    if 6 <= hour < 12:
        time_factor = "morning"
        hydration_multiplier = 1.2  # Need more water in morning
    elif 12 <= hour < 18:
        time_factor = "afternoon"
        hydration_multiplier = 1.5  # Peak activity time
    elif 18 <= hour < 22:
        time_factor = "evening"
        hydration_multiplier = 1.1  # Moderate activity
    else:
        time_factor = "night"
        hydration_multiplier = 0.8  # Lower activity
    
    # Day of week factors
    if day_of_week < 5:  # Weekday
        day_factor = "weekday"
        activity_expectation = "higher"
    else:  # Weekend
        day_factor = "weekend"
        activity_expectation = "variable"
    
    return {
        'time_of_day': time_factor,
        'hour': hour,
        'day_of_week': day_factor,
        'hydration_multiplier': hydration_multiplier,
        'activity_expectation': activity_expectation
    }

def get_location_context(lat=None, lon=None):
    """Get location-based environmental context"""
    try:
        # Get weather data for location
        weather_data = get_weather_data(lat, lon)
        
        if not weather_data:
            return None
        
        # Determine environmental context
        temp = weather_data.get('temperature', 20)
        humidity = weather_data.get('humidity', 50)
        wind_speed = weather_data.get('wind_speed', 0)
        
        # Environmental risk factors
        risk_factors = []
        risk_score = 0.0
        
        if temp > 35:
            risk_factors.append("extreme_heat")
            risk_score += 0.4
        elif temp > 30:
            risk_factors.append("high_temperature")
            risk_score += 0.2
        elif temp < 0:
            risk_factors.append("cold_weather")
            risk_score += 0.1
        
        if humidity > 80:
            risk_factors.append("high_humidity")
            risk_score += 0.2
        elif humidity < 30:
            risk_factors.append("low_humidity")
            risk_score += 0.1
        
        if wind_speed > 25:
            risk_factors.append("high_wind")
            risk_score += 0.1
        
        # Determine environmental context
        if risk_score > 0.5:
            context = "harsh_environment"
        elif risk_score > 0.2:
            context = "moderate_risk"
        else:
            context = "normal_conditions"
        
        return {
            'weather': weather_data,
            'risk_factors': risk_factors,
            'risk_score': risk_score,
            'environmental_context': context,
            'location': {'lat': lat, 'lon': lon} if lat and lon else None
        }
        
    except Exception as e:
        print(f"Error getting location context: {e}")
        return None

def calculate_environmental_hydration_needs(activity_data, time_data, location_data):
    """Calculate hydration needs based on environmental factors"""
    try:
        base_hydration = 2.0  # Base daily water intake in liters
        
        # Activity adjustments
        activity_multiplier = 1.0
        if activity_data['activity_level'] == 'high':
            activity_multiplier = 1.5
        elif activity_data['activity_level'] == 'moderate':
            activity_multiplier = 1.3
        elif activity_data['activity_level'] == 'light':
            activity_multiplier = 1.1
        
        # Time adjustments
        time_multiplier = time_data['hydration_multiplier']
        
        # Environmental adjustments
        env_multiplier = 1.0
        if location_data and location_data['risk_score'] > 0.3:
            env_multiplier = 1.2
        elif location_data and location_data['risk_score'] > 0.1:
            env_multiplier = 1.1
        
        # Calculate recommended hydration
        recommended_hydration = base_hydration * activity_multiplier * time_multiplier * env_multiplier
        
        # Calculate hourly needs
        hourly_hydration = recommended_hydration / 16  # Assume 16 waking hours
        
        return {
            'daily_recommendation': round(recommended_hydration, 2),
            'hourly_recommendation': round(hourly_hydration, 2),
            'factors': {
                'activity_multiplier': activity_multiplier,
                'time_multiplier': time_multiplier,
                'environmental_multiplier': env_multiplier
            }
        }
        
    except Exception as e:
        print(f"Error calculating environmental hydration needs: {e}")
        return {
            'daily_recommendation': 2.0,
            'hourly_recommendation': 0.125,
            'factors': {
                'activity_multiplier': 1.0,
                'time_multiplier': 1.0,
                'environmental_multiplier': 1.0
            }
        }

def get_comprehensive_environmental_analysis(user_id, current_metrics):
    """Get comprehensive environmental analysis for a user"""
    try:
        # Analyze activity intensity
        activity_data = analyze_activity_intensity(
            current_metrics.get('acc_x', 0),
            current_metrics.get('acc_y', 0),
            current_metrics.get('acc_z', 0),
            current_metrics.get('steps', 0),
            current_metrics.get('active_energy', 0)
        )
        
        # Get time-based factors
        time_data = get_time_based_factors()
        
        # Get location context (default to None for now)
        location_data = get_location_context()
        
        # Calculate environmental hydration needs
        hydration_needs = calculate_environmental_hydration_needs(
            activity_data, time_data, location_data
        )
        
        # Get user's current water intake
        current_water = current_metrics.get('water_intake', 0)
        
        # Calculate hydration status
        hydration_percentage = (current_water / hydration_needs['daily_recommendation']) * 100 if hydration_needs['daily_recommendation'] > 0 else 0
        
        if hydration_percentage < 50:
            hydration_status = "critical"
        elif hydration_percentage < 75:
            hydration_status = "low"
        elif hydration_percentage < 100:
            hydration_status = "moderate"
        else:
            hydration_status = "good"
        
        return {
            'activity_analysis': activity_data,
            'time_analysis': time_data,
            'location_analysis': location_data,
            'hydration_needs': hydration_needs,
            'current_hydration': {
                'intake': current_water,
                'percentage': round(hydration_percentage, 1),
                'status': hydration_status
            },
            'recommendations': generate_environmental_recommendations(
                activity_data, time_data, location_data, hydration_needs, current_water
            )
        }
        
    except Exception as e:
        print(f"Error in comprehensive environmental analysis: {e}")
        return None

def generate_environmental_recommendations(activity_data, time_data, location_data, hydration_needs, current_water):
    """Generate recommendations based on environmental factors"""
    recommendations = []
    
    # Activity-based recommendations
    if activity_data['activity_level'] == 'high':
        recommendations.append("🏃‍♂️ High activity detected - drink extra water during and after exercise")
    elif activity_data['activity_level'] == 'moderate':
        recommendations.append("🚶‍♂️ Moderate activity - maintain regular hydration")
    
    # Time-based recommendations
    if time_data['time_of_day'] == 'morning':
        recommendations.append("🌅 Morning hydration is crucial - start your day with water")
    elif time_data['time_of_day'] == 'afternoon':
        recommendations.append("☀️ Peak activity time - stay well hydrated")
    
    # Environmental recommendations
    if location_data and location_data['risk_factors']:
        for factor in location_data['risk_factors']:
            if factor == 'extreme_heat':
                recommendations.append("🔥 Extreme heat - increase water intake significantly")
            elif factor == 'high_temperature':
                recommendations.append("🌡️ Hot weather - drink more water than usual")
            elif factor == 'high_humidity':
                recommendations.append("💧 High humidity - you may need more water")
    
    # Hydration status recommendations
    if current_water < hydration_needs['daily_recommendation'] * 0.5:
        recommendations.append("🚨 Critical: You're significantly behind on hydration")
    elif current_water < hydration_needs['daily_recommendation'] * 0.75:
        recommendations.append("⚠️ Low hydration - try to catch up on water intake")
    
    if not recommendations:
        recommendations.append("✅ Good hydration status - keep it up!")
    
    return recommendations

@app.route('/update_metrics', methods=['POST'])
def update_metrics():
    global latest_metrics, vitals_buffer
    data = request.get_json()
    print(f"[Flask] Received data from Swift: {data}")
    
    # Get user_id from request (default to 'default_user' if not provided)
    user_id = data.get('user_id', 'default_user')
    
    # Get weather data for enhanced recommendations
    weather_data = get_weather_data()
    
    # Update only the keys present in the incoming data
    for k, v in data.items():
        if k != 'user_id':  # Don't store user_id in metrics
            try:
                latest_metrics[k] = float(v)
            except (ValueError, TypeError):
                latest_metrics[k] = v
    
    print(f"[Flask] After update, before display keys: {latest_metrics}")
    # Always set display keys to match ANN keys
    latest_metrics['Body Temp'] = float(latest_metrics.get('Temp', 0.0))
    latest_metrics['Heart Rate'] = float(latest_metrics.get('HR', 0.0))
    print(f"[Flask] After setting display keys: {latest_metrics}")
    
    # Add to vitals buffer
    vitals_entry = {
        'timestamp': time.time(),
        'Temp': latest_metrics.get('Body Temp', 0.0),
        'HR': latest_metrics.get('Heart Rate', 0.0),
        'Water Intake': latest_metrics.get('Water Intake', 0.0),
        'Acc_X': latest_metrics.get('Acc_X', 0.0),
        'Acc_Y': latest_metrics.get('Acc_Y', 0.0),
        'Acc_Z': latest_metrics.get('Acc_Z', 0.0),
        'Steps': latest_metrics.get('Steps', 0),
        'Active Energy': latest_metrics.get('Active Energy', 0.0)
    }
    vitals_buffer.append(vitals_entry)
    
    # Prepare metrics for database
    metrics_for_db = {
        'HR': latest_metrics.get('Heart Rate', 0.0),
        'Temp': latest_metrics.get('Body Temp', 0.0),
        'Steps': latest_metrics.get('Steps', 0),
        'Water Intake': latest_metrics.get('Water Intake', 0.0),
        'Active Energy': latest_metrics.get('Active Energy', 0.0),
        'Acc_X': latest_metrics.get('Acc_X', 0.0),
        'Acc_Y': latest_metrics.get('Acc_Y', 0.0),
        'Acc_Z': latest_metrics.get('Acc_Z', 0.0)
    }
    
    # Get ensemble prediction
    prediction_result = predict_with_ensemble(user_id, metrics_for_db)
    
    # Get future prediction
    future_prediction = predict_future_dehydration(user_id, metrics_for_db)
    
    # Get comprehensive environmental analysis
    environmental_analysis = get_comprehensive_environmental_analysis(user_id, metrics_for_db)
    
    metrics_for_db['ml_prediction'] = prediction_result['prediction']
    metrics_for_db['dehydration_risk'] = "Dehydrated" if prediction_result['prediction'] > 0.5 else "Well Hydrated"
    
    # Store in database
    store_user_metrics(user_id, metrics_for_db)
    
    # Check for high risk and create alert
    if prediction_result['prediction'] > 0.7:
        create_alert(user_id, "dehydration", 
                   "High dehydration risk detected! Drink water immediately.", 
                   prediction_result['prediction'])
    
    # Create smart notifications
    notifications_created = check_and_create_smart_notifications(user_id, metrics_for_db, prediction_result, weather_data)
    
    # Train ensemble model periodically (every 100 records)
    user_metrics_count = len(get_user_metrics(user_id, days=30))
    if user_metrics_count % 100 == 0 and user_metrics_count > 0:
        # Train in background (don't block the response)
        import threading
        threading.Thread(target=train_ensemble_model, args=(user_id,)).start()
    
    # Generate base recommendations
    base_recommendations = get_personal_recommendations(user_id, metrics_for_db, prediction_result)
    
    # Add environmental recommendations
    if environmental_analysis:
        base_recommendations.extend(environmental_analysis['recommendations'])
    
    # Adjust for weather
    weather_adjusted_recommendations = adjust_hydration_for_weather(weather_data, base_recommendations)
    
    # Add future prediction to recommendations
    if future_prediction and future_prediction['urgency'] in ['high', 'emergency']:
        weather_adjusted_recommendations.append(f"⚠️ Future Risk: {future_prediction['time_to_dehydration']} - {future_prediction['urgency'].capitalize()} risk predicted")
    
    # Check for achievements
    check_and_create_achievements(user_id, metrics_for_db)
    
    return jsonify({
        "status": "success",
        "prediction": prediction_result,
        "future_prediction": future_prediction,
        "environmental_analysis": environmental_analysis,
        "recommendations": weather_adjusted_recommendations,
        "weather": weather_data,
        "notifications_created": notifications_created
    })

def check_and_create_achievements(user_id, current_metrics):
    """Check if user has earned any achievements"""
    try:
        # Get user's recent data
        recent_metrics = get_user_metrics(user_id, days=7)
        
        if len(recent_metrics) >= 7:
            # Check for hydration streak
            good_hydration_days = sum(1 for m in recent_metrics if m.get('ml_prediction', 0) < 0.5)
            if good_hydration_days >= 7:
                create_social_achievement(user_id, 'hydration_streak')
        
        # Check for activity boost
        steps = current_metrics.get('steps', 0)
        water_intake = current_metrics.get('water_intake', 0)
        if steps > 10000 and water_intake > 1.5:
            create_social_achievement(user_id, 'activity_boost')
        
        # Check for weather warrior (if weather data available)
        # This would need weather data from previous days
        
    except Exception as e:
        print(f"Error checking achievements: {e}")

def analyze_dehydration_trend(buffer, window_minutes=20):
    # Analyze the last window_minutes of data for risky trends
    if len(buffer) < 2:
        return "Low", "Not enough data", None
    now = time.time()
    window = [entry for entry in buffer if now - entry['timestamp'] <= window_minutes * 60]
    if len(window) < 2:
        return "Low", "Not enough recent data", None
    # Calculate trends
    hr_start, hr_end = window[0]['HR'], window[-1]['HR']
    temp_start, temp_end = window[0]['Temp'], window[-1]['Temp']
    water_start, water_end = window[0]['Water Intake'], window[-1]['Water Intake']
    hr_trend = hr_end - hr_start
    temp_trend = temp_end - temp_start
    water_change = water_end - water_start
    # Use latest ANN prediction if available
    try:
        features = [window[-1]['Temp'], window[-1]['HR'], window[-1]['Acc_X'], window[-1]['Acc_Y'], window[-1]['Acc_Z']]
        columns = ['Temp', 'HR', 'Acc_X', 'Acc_Y', 'Acc_Z']
        X_df = pd.DataFrame([features], columns=columns)
        X_scaled = scaler.transform(X_df)
        ann_pred = ann_model.predict(X_scaled)[0][0]
    except Exception:
        ann_pred = None
    # Heuristic rules
    if hr_trend > 10 and temp_trend > 0.5 and water_end < 1.0:
        return "High", "Heart rate and temperature rising, low water intake", 15
    elif hr_trend > 5 or temp_trend > 0.2:
        return "Moderate", "Vitals rising", 25
    elif ann_pred is not None and 0.4 < ann_pred < 0.5:
        return "Moderate", "ANN dehydration probability rising", 30
    else:
        return "Low", "Vitals stable", None

@app.route("/predict_dehydration_risk", methods=["GET"])
def predict_dehydration_risk():
    global latest_metrics, vitals_buffer
    # Current status from ANN
    try:
        temp = float(latest_metrics.get('Body Temp', 0.0))
        hr = float(latest_metrics.get('Heart Rate', 0.0))
        acc_x = float(latest_metrics.get('Acc_X', 0.0))
        acc_y = float(latest_metrics.get('Acc_Y', 0.0))
        acc_z = float(latest_metrics.get('Acc_Z', 0.0))
        water_intake = float(latest_metrics.get('Water Intake', 0.0))
        features = [temp, hr, acc_x, acc_y, acc_z]
        columns = ['Temp', 'HR', 'Acc_X', 'Acc_Y', 'Acc_Z']
        X_df = pd.DataFrame([features], columns=columns)
        X_scaled = scaler.transform(X_df)
        prediction = ann_model.predict(X_scaled)[0][0]
        ann_status = "Dehydrated" if prediction > 0.5 else "Well Hydrated"
    except Exception as e:
        ann_status = "Unknown"
    # Trend analysis
    risk, reason, time_est = analyze_dehydration_trend(vitals_buffer)
    return jsonify({
        "current_status": ann_status,
        "future_risk": risk,
        "reason": reason,
        "time_to_dehydration": f"Approx. {time_est} min" if time_est else None
    })

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

# New endpoints for long-term tracking
@app.route("/user/<user_id>/metrics", methods=["GET"])
def get_user_metrics_endpoint(user_id):
    """Get user's historical metrics"""
    days = request.args.get('days', 7, type=int)
    metrics = get_user_metrics(user_id, days)
    return jsonify(metrics)

@app.route("/user/<user_id>/baseline", methods=["GET"])
def get_user_baseline_endpoint(user_id):
    """Get user's baseline metrics"""
    days = request.args.get('days', 30, type=int)
    baseline = get_user_baseline(user_id, days)
    return jsonify(baseline)

@app.route("/user/<user_id>/alerts", methods=["GET"])
def get_user_alerts_endpoint(user_id):
    """Get user's alerts"""
    unread_only = request.args.get('unread_only', 'true').lower() == 'true'
    alerts = get_user_alerts(user_id, unread_only)
    return jsonify(alerts)

@app.route("/user/<user_id>/alerts/<alert_id>/read", methods=["POST"])
def mark_alert_read(user_id, alert_id):
    """Mark an alert as read"""
    conn = get_db()
    c = conn.cursor()
    
    try:
        c.execute('''
            UPDATE alerts SET is_read = TRUE 
            WHERE id = ? AND user_id = ?
        ''', (alert_id, user_id))
        conn.commit()
        return jsonify({"status": "success"})
    except Exception as e:
        return jsonify({"error": str(e)}), 400
    finally:
        conn.close()

# New endpoints for personal ML
@app.route("/user/<user_id>/train_model", methods=["POST"])
def train_user_model_endpoint(user_id):
    """Train a personal model for a user"""
    success = train_personal_model(user_id)
    return jsonify({"success": success})

@app.route("/user/<user_id>/predict", methods=["POST"])
def predict_user_dehydration_endpoint(user_id):
    """Get personalized dehydration prediction for a user"""
    data = request.get_json()
    if not data:
        return jsonify({"error": "No data provided"}), 400
    
    prediction_result = predict_personal_dehydration(user_id, data)
    recommendations = get_personal_recommendations(user_id, data, prediction_result)
    
    return jsonify({
        "prediction": prediction_result,
        "recommendations": recommendations
    })

@app.route("/user/<user_id>/model_status", methods=["GET"])
def get_user_model_status(user_id):
    """Get the status of a user's personal model"""
    model, scaler = load_personal_model(user_id)
    user_metrics = get_user_metrics(user_id, days=30)
    
    return jsonify({
        "has_personal_model": model is not None,
        "total_records": len(user_metrics),
        "model_type": "personal" if model is not None else "global"
    })

# New endpoints for advanced features
@app.route("/user/<user_id>/analytics", methods=["GET"])
def get_user_analytics_endpoint(user_id):
    """Get comprehensive analytics for a user"""
    days = request.args.get('days', 30, type=int)
    analytics = generate_advanced_analytics(user_id, days)
    return jsonify(analytics)

@app.route("/user/<user_id>/achievements", methods=["GET"])
def get_user_achievements_endpoint(user_id):
    """Get user's achievements"""
    achievements = get_user_achievements(user_id)
    return jsonify(achievements)

@app.route("/user/<user_id>/activity_correlation", methods=["GET"])
def get_activity_correlation_endpoint(user_id):
    """Get activity-hydration correlation analysis"""
    days = request.args.get('days', 7, type=int)
    correlation = get_activity_correlation(user_id, days)
    return jsonify(correlation)

@app.route("/weather", methods=["GET"])
def get_weather_endpoint():
    """Get current weather data"""
    lat = request.args.get('lat', type=float)
    lon = request.args.get('lon', type=float)
    weather = get_weather_data(lat, lon)
    return jsonify(weather)

# New endpoints for notifications
@app.route("/user/<user_id>/notifications", methods=["GET"])
def get_user_notifications_endpoint(user_id):
    """Get user's notifications"""
    unread_only = request.args.get('unread_only', 'true').lower() == 'true'
    notifications = get_user_notifications(user_id, unread_only)
    return jsonify(notifications)

@app.route("/user/<user_id>/notifications/<notification_id>/read", methods=["POST"])
def mark_notification_read_endpoint(user_id, notification_id):
    """Mark a notification as read"""
    success = mark_notification_read(notification_id)
    return jsonify({"success": success})

# New endpoints for ensemble models
@app.route("/user/<user_id>/train_ensemble", methods=["POST"])
def train_ensemble_model_endpoint(user_id):
    """Train an ensemble model for a user"""
    success = train_ensemble_model(user_id)
    return jsonify({"success": success})

@app.route("/user/<user_id>/predict_future", methods=["POST"])
def predict_future_dehydration_endpoint(user_id):
    """Get future dehydration prediction for a user"""
    data = request.get_json()
    if not data:
        return jsonify({"error": "No data provided"}), 400
    
    time_horizon = request.args.get('time_horizon', 30, type=int)
    future_prediction = predict_future_dehydration(user_id, data, time_horizon)
    
    return jsonify({
        "future_prediction": future_prediction
    })

# New endpoints for environmental analysis
@app.route("/user/<user_id>/environmental_analysis", methods=["POST"])
def get_environmental_analysis_endpoint(user_id):
    """Get comprehensive environmental analysis for a user"""
    data = request.get_json()
    if not data:
        return jsonify({"error": "No data provided"}), 400
    
    analysis = get_comprehensive_environmental_analysis(user_id, data)
    return jsonify(analysis)

if __name__ == "__main__":
    # For testing, run with debug=False to avoid auto-reload resetting globals
    app.run(host="0.0.0.0", port=5000, debug=False) 