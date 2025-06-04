import os
import sys
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('TkAgg')
import matplotlib.pyplot as plt
from sklearn.naive_bayes import GaussianNB
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, confusion_matrix, classification_report, mean_squared_error, r2_score
import tkinter as tk
from tkinter import messagebox

print("🧪 Starting 2-Class Hydration Classifier (Naive Bayes)...")

# ========== Load ==========
script_dir = os.path.dirname(os.path.abspath(__file__))
csv_path = os.path.join(script_dir, "merged_dataset.csv")
df = pd.read_csv(csv_path, skiprows=1)
df.columns = ['EDA', 'Temp', 'HR', 'Acc_X', 'Acc_Y', 'Acc_Z', 'stress_level']
df = df.apply(pd.to_numeric, errors='coerce')
df.dropna(inplace=True)

def label_status_binary(level): return 0 if level <= 3 else 1
df['hydration_class'] = df['stress_level'].apply(label_status_binary)

X = df[['EDA', 'Temp', 'HR', 'Acc_X', 'Acc_Y', 'Acc_Z']]
y = df['hydration_class']

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=2, random_state=42)
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# ========== Train ==========
model = GaussianNB()
model.fit(X_train_scaled, y_train)
y_pred = model.predict(X_test_scaled)

def class_label_binary(c): return "🟢 Well Hydrated" if c == 0 else "🔴 Dehydrated"

# ========== Evaluation ==========
accuracy = accuracy_score(y_test, y_pred)
mse = mean_squared_error(y_test, y_pred)
r2 = r2_score(y_test, y_pred)
conf_mat = confusion_matrix(y_test, y_pred)

print("\n📊 Classification Evaluation:")
print(f"✅ Accuracy: {accuracy:.2f}")
print("\n🔀 Confusion Matrix:")
print(conf_mat)
print("\n🧾 Classification Report:")
print(classification_report(y_test, y_pred, target_names=["Hydrated", "Dehydrated"]))

# ========== Output ==========
print("\n✅ FINAL OUTPUT:")
for actual, pred in zip(y_test.values, y_pred):
    print(f"Actual: {class_label_binary(actual)} | Predicted: {class_label_binary(pred)}")

# ========== Save ==========
results = pd.DataFrame({
    'Actual Class': y_test.values,
    'Predicted Class': y_pred,
    'Actual Label': [class_label_binary(a) for a in y_test.values],
    'Predicted Label': [class_label_binary(p) for p in y_pred]
})
csv_out = os.path.join(script_dir, "naive_bayes_classifier_predictions.csv")
results.to_csv(csv_out, index=False)
print(f"\n💾 Saved: {csv_out}")

# ========== Verdict ==========
print("\n🧠 Verdict:")
print(f"📉 MSE: {mse:.4f}")
print(f"📈 R² Score: {r2:.4f}")
if accuracy == 1.0:
    print("✅ Naive Bayes is highly effective. All predictions correct.")
elif accuracy >= 0.7:
    print("⚠️ Naive Bayes is moderately effective.")
else:
    print("❌ Naive Bayes underperformed.")

# ========== Popup ==========
def show_popup():
    msg = (
        f"Naive Bayes Summary:\n\n"
        f"Accuracy: {accuracy:.2f}\n"
        f"MSE: {mse:.2f}\n"
        f"R²: {r2:.2f}\n"
        f"Sample Prediction: {class_label_binary(y_pred[0])}"
    )
    messagebox.showinfo("Naive Bayes Classifier", msg)

root = tk.Tk()
root.withdraw()
show_popup()

print("\n✅ Done.")
