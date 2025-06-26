import os
import sys  # NEW
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('TkAgg')  # Safe backend
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.linear_model import LinearRegression
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_squared_error, r2_score
import tkinter as tk
from tkinter import messagebox

print("🔁 Starting Hydration Model (Linear Regression)...")

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

# ========== Step 2: Skip Correlation Plot ==========
# plt.figure(figsize=(8, 5))
# sns.heatmap(df.corr(), annot=True, cmap='coolwarm')
# plt.title("Feature Correlation Matrix")
# plt.tight_layout()
# plt.show()

# ========== Step 3: Split & Scale ==========

X = df[['EDA', 'Temp', 'HR', 'Acc_X', 'Acc_Y', 'Acc_Z']]
y = df['stress_level']

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=2, random_state=42)

print(f"\n📏 Training set size: {len(X_train)}")
print(f"📏 Test set size: {len(X_test)}")
sys.stdout.flush()

if len(X_test) == 0:
    print("❌ No test data available! Exiting early.")
    sys.exit()

scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

print("✅ Reached: After scaling")
sys.stdout.flush()

# ========== Step 4: Train & Predict ==========

model = LinearRegression()
model.fit(X_train_scaled, y_train)

print("✅ Reached: After training")
sys.stdout.flush()

print(f"\n🚨 DEBUG: X_test BEFORE prediction:\n{pd.DataFrame(X_test)}")
sys.stdout.flush()

y_pred = model.predict(X_test_scaled)

print(f"\n🚨 DEBUG: y_pred AFTER prediction: {y_pred}")
print(f"🚨 DEBUG: y_test: {y_test.values}")
sys.stdout.flush()

def interpret_status(val):
    if val <= 2.0:
        return "🟢 Well Hydrated"
    elif val <= 4.0:
        return "🟡 Moderately Dehydrated"
    else:
        return "🔴 Very Dehydrated"

# ========== Step 5: Metrics ==========
mse = mean_squared_error(y_test, y_pred)
r2 = r2_score(y_test, y_pred)

print("\n📊 Model Evaluation:")
print(f"📉 MSE: {mse:.4f}")
print(f"📈 R² Score: {r2:.4f}")
sys.stdout.flush()

# ========== Step 6: Save & Show Predictions ==========

results = pd.DataFrame({
    'Actual Stress Level': y_test.values,
    'Predicted Stress Level': y_pred
})
results['Status'] = results['Predicted Stress Level'].apply(interpret_status)

csv_out = os.path.join(script_dir, "linear_regression_predictions.csv")
results.to_csv(csv_out, index=False)
print(f"\n💾 Saved: {csv_out}")

print("\n✅ FINAL OUTPUT:")
for actual, pred in zip(y_test.values, y_pred):
    print(f"Actual: {actual:.2f} | Predicted: {pred:.2f} | Status: {interpret_status(pred)}")

print("\n🧠 Verdict:")
if r2 > 0.7:
    print("✅ Highly effective model.")
elif r2 > 0.4:
    print("⚠️ Moderately effective model.")
else:
    print("❌ Low performance. Try a different model")
sys.stdout.flush()

# ========== Step 7: Skip Plot Temporarily ==========
# plt.figure(figsize=(8, 5))
# plt.scatter(y_test, y_pred, alpha=0.7, color='blue')
# plt.plot([y.min(), y.max()], [y.min(), y.max()], '--r')
# plt.xlabel("Actual Stress Level")
# plt.ylabel("Predicted Stress Level")
# plt.title(f"Actual vs Predicted Stress\nR² = {r2:.2f}, MSE = {mse:.2f}")
# plt.grid(True)
# plt.tight_layout()
# plt.show()

# ========== Step 8: Popup ==========
def show_popup():
    msg = (
        f"R² Score: {r2:.3f}\n"
        f"MSE: {mse:.3f}\n\n"
        f"Sample Prediction: {y_pred[0]:.2f}\n"
        f"Status: {interpret_status(y_pred[0])}"
    )
    messagebox.showinfo("Prediction Summary", msg)

root = tk.Tk()
root.withdraw()
show_popup()

print("\n✅ Done.")
sys.stdout.flush()


