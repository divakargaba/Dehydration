import os
import sys
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('TkAgg')
import matplotlib.pyplot as plt
from sklearn.svm import SVC
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, confusion_matrix, classification_report
import tkinter as tk
from tkinter import messagebox

print("🧪 Starting 2-Class Hydration Classifier (SVM)...")

# ========== Step 1: Load & Clean ==========

script_dir = os.path.dirname(os.path.abspath(__file__))
csv_path = os.path.join(script_dir, "merged_dataset.csv")

print(f"📂 Loading: {csv_path}")
df = pd.read_csv(csv_path, skiprows=1)
df.columns = ['EDA', 'Temp', 'HR', 'Acc_X', 'Acc_Y', 'Acc_Z', 'stress_level']

sensor_cols = ['EDA', 'Temp', 'HR', 'Acc_X', 'Acc_Y', 'Acc_Z', 'stress_level']
df[sensor_cols] = df[sensor_cols].apply(pd.to_numeric, errors='coerce')
df.dropna(inplace=True)

print(f"✅ Cleaned shape: {df.shape}")
print(df.head())
sys.stdout.flush()

# ========== Step 2: Binarize Labels ==========

def label_status_binary(level):
    return 0 if level <= 3 else 1

df['hydration_class'] = df['stress_level'].apply(label_status_binary)

# ========== Step 3: Split & Scale ==========

X = df[['EDA', 'Temp', 'HR', 'Acc_X', 'Acc_Y', 'Acc_Z']]
y = df['hydration_class']

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=2, random_state=42)

scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# ========== Step 4: Train SVM ==========

model = SVC(kernel='rbf', probability=True, random_state=42)
model.fit(X_train_scaled, y_train)

# ========== Step 5: Predict ==========

y_pred = model.predict(X_test_scaled)

def class_label_binary(c):
    return "🟢 Well Hydrated" if c == 0 else "🔴 Dehydrated"

# ========== Step 6: Evaluation ==========

accuracy = accuracy_score(y_test, y_pred)
conf_mat = confusion_matrix(y_test, y_pred)

print("\n📊 Classification Evaluation:")
print(f"✅ Accuracy: {accuracy:.2f}")
print("\n🔀 Confusion Matrix:")
print(conf_mat)
print("\n🧾 Classification Report:")
print(classification_report(y_test, y_pred, target_names=["Hydrated", "Dehydrated"]))
sys.stdout.flush()

# ========== Step 7: Show Results ==========

print("\n✅ PREDICTIONS:")
for actual, pred in zip(y_test.values, y_pred):
    print(f"Actual: {class_label_binary(actual)} | Predicted: {class_label_binary(pred)}")

# ========== Step 8: Save to CSV ==========

results = pd.DataFrame({
    'Actual Class': y_test.values,
    'Predicted Class': y_pred,
    'Actual Label': [class_label_binary(a) for a in y_test.values],
    'Predicted Label': [class_label_binary(p) for p in y_pred]
})
csv_out = os.path.join(script_dir, "svm_classifier_predictions.csv")
results.to_csv(csv_out, index=False)
print(f"\n💾 Saved: {csv_out}")

# ========== Step 9: Verdict ==========

print("\n🧠 Verdict:")
if accuracy == 1.0:
    print("✅ The SVM model is highly effective. All predictions were correct.")
elif accuracy >= 0.7:
    print("⚠️ The SVM model is moderately effective. Good accuracy, but test size is small.")
else:
    print("❌ The SVM model performed poorly. Consider tuning or trying another algorithm.")

# ========== Step 10: Popup ==========

def show_popup():
    msg = (
        f"SVM Classifier Summary:\n\n"
        f"Accuracy: {accuracy:.2f}\n"
        f"Sample Prediction: {class_label_binary(y_pred[0])}"
    )
    messagebox.showinfo("SVM Classifier", msg)

root = tk.Tk()
root.withdraw()
show_popup()

print("\n✅ Done.")
