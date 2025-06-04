import matplotlib.pyplot as plt
import numpy as np

# ======================
# 🔢 Model Results (fill in based on your outputs)
# ======================

models = [
    "Logistic Regression",
    "Random Forest Classifier",
    "Naive Bayes",
    "SVM",
    "ANN (MLP)",
]

accuracy = [1.00, 1.00, 1.00, 0.50, 1.00]
mse =      [0.00, 0.00, 0.00, 0.50, 0.00]
r2 =       [1.00, 1.00, 1.00, -1.00, 1.00]

x = np.arange(len(models))  # X-axis positions
width = 0.25  # Bar width

# ======================
# 📊 Plotting
# ======================

plt.figure(figsize=(12, 6))
plt.bar(x - width, accuracy, width, label='Accuracy', color='mediumseagreen')
plt.bar(x, mse, width, label='MSE', color='tomato')
plt.bar(x + width, r2, width, label='R² Score', color='dodgerblue')

plt.xlabel('Model')
plt.ylabel('Metric Value')
plt.title('🧠 Hydration Model Comparison')
plt.xticks(ticks=x, labels=models, rotation=20)
plt.legend()
plt.grid(True, axis='y', linestyle='--', alpha=0.6)
plt.tight_layout()
plt.show()
