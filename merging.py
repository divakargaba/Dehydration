import pandas as pd
import os

# Path where your CSVs are
data_path = 'data/'  # Change this if your folder is named differently

# Load sensor data
eda = pd.read_csv(os.path.join(data_path, 'EDA.csv'), header=None)
temp = pd.read_csv(os.path.join(data_path, 'TEMP.csv'), header=None)
hr = pd.read_csv(os.path.join(data_path, 'HR.csv'), header=None)
acc = pd.read_csv(os.path.join(data_path, 'ACC.csv'), header=None)

# Load labels and subject info
stress_v1 = pd.read_csv(os.path.join(data_path, 'Stress_level_v1.csv'))
subject_info = pd.read_csv(os.path.join(data_path, 'subject-info.csv'))

# OPTIONAL: Give column names (if missing)
eda.columns = ['EDA']
temp.columns = ['Temp']
hr.columns = ['HR']
acc.columns = ['Acc_X', 'Acc_Y', 'Acc_Z']

# Reset indexes just to be sure
eda.reset_index(drop=True, inplace=True)
temp.reset_index(drop=True, inplace=True)
hr.reset_index(drop=True, inplace=True)
acc.reset_index(drop=True, inplace=True)

# Combine features horizontally
merged = pd.concat([eda, temp, hr, acc], axis=1)

# Check length match
print("Merged shape:", merged.shape)
print("Stress labels shape:", stress_v1.shape)

# If stress_v1 has one label per sample:
# (or you might need to adjust this depending how many labels vs samples you have)

merged['stress_level'] = stress_v1['Stroop'] # diff column name (had some issue)


# Drop any rows with missing values
merged = merged.dropna()

# Save merged dataset
merged.to_csv('merged_dataset.csv', index=False)

print("✅ Merged dataset saved as 'merged_dataset.csv'")
