# comments added....
import mlflow  # Azure ML tracks experiments natively via MLflow integration
import argparse  # Library for parsing command-line arguments passed to the script
import glob  # Wildcard matching library used here to scan folders for files
import os  # System library to manipulate file paths and check directories
import pandas as pd  # Data manipulation library for handling tabular DataFrames
import numpy as np  # Mathematical array library used here to compute metric averages
from sklearn.model_selection import train_test_split  # Utility to partition data splits
from sklearn.linear_model import LogisticRegression  # Traditional supervised ML algorithm
from sklearn.metrics import roc_auc_score  # Evaluation metric: Area Under the ROC Curve
from sklearn.metrics import roc_curve  # Calculates True/False Positive Rates for plotting
import matplotlib.pyplot as plt  # Data visualization library for rendering charts


def main(args):
    """
    Orchestration function running the end-to-end training and evaluation lifecycle.
    """
    # 1. Ingest and consolidate the structured tabular source data
    df = get_data(args.training_data)

    # 2. Separate independent variables (features) from the dependent target column
    X_train, X_test, y_train, y_test = split_data(df)

    # 3. Fit the Logistic Regression model using hyperparameter parameters
    model = train_model(args.reg_rate, X_train, X_test, y_train, y_test)

    # 4. Score predictions against testing splits and calculate model performance
    eval_model(model, X_test, y_test)


def get_data(path):
    """
    Reads dataset files. Handles both single CSV paths or folders containing multiple fragments.
    """
    print("Reading data...")

    # If the user passed a folder path, find and combine all internal CSV segments
    if os.path.isdir(path):
        csv_files = glob.glob(os.path.join(path, "*.csv"))
        if not csv_files:
            raise RuntimeError(
                f"No CSV files found in provided data path: {path}"
            )
        # Python generator reading and stacking chunks row-wise into a unified DataFrame
        df = pd.concat((pd.read_csv(f) for f in csv_files), ignore_index=True)
    else:
        # Standard path ingestion for a single standalone CSV data file
        df = pd.read_csv(path)

    return df


def split_data(df):
    """
    Performs feature engineering isolation and splits data into Train/Test subsets.
    """
    print("Splitting data...")

    # Select the independent feature columns (X) used by the math model to spot trends
    X = df[[
        'Pregnancies', 'PlasmaGlucose', 'DiastolicBloodPressure',
        'TricepsThickness', 'SerumInsulin', 'BMI', 'DiabetesPedigree', 'Age'
    ]].values

    # Isolate the binary target variable column (y) representing the ground-truth prediction
    y = df['Diabetic'].values

    # Partition data: 70% used to fit parameters, 30% held back as a validation check
    # random_state=0 ensures reproducible index shuffling every time this code triggers
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.30, random_state=0
    )

    return X_train, X_test, y_train, y_test


def train_model(reg_rate, X_train, X_test, y_train, y_test):
    """
    Executes supervised model building and logs input parameters to the tracking server.
    """
    # MLflow tracking: Logs hyperparameter settings to compare across different runs
    mlflow.log_param("Regularization rate", reg_rate)

    print("Training model...")
    # C parameter handles regularization tuning (inverse of regularization strength)
    # liblinear solver is optimized for simple, smaller binary classification tables
    model = LogisticRegression(C=1 / reg_rate, solver="liblinear").fit(
        X_train, y_train
    )

    return model


def eval_model(model, X_test, y_test):
    """
    Evaluates model efficacy using accuracy/AUC metrics and uploads visual assets.
    """
    # --- Accuracy Calculation ---
    y_hat = model.predict(X_test)  # Generate concrete predictions (0 or 1)
    acc = np.average(y_hat == y_test)  # Calculate percentage of correct rows
    print('Accuracy:', acc)
    mlflow.log_metric("Accuracy", acc)  # Track metric value globally over the run

    # --- AUC Metric Calculation ---
    y_scores = model.predict_proba(X_test)  # Retrieve decimals indicating probability
    auc = roc_auc_score(
        y_test, y_scores[:, 1]
    )  # Check how well model isolates classes
    print('AUC: ' + str(auc))
    mlflow.log_metric("AUC", auc)  # Save the area metric score inside the cloud UI

    # --- Plotting and Saving the ROC Curve Chart ---
    fpr, tpr, thresholds = roc_curve(
        y_test, y_scores[:, 1]
    )  # Extract True/False Positive Rates
    fig = plt.figure(figsize=(6, 4))

    # Render a diagonal 50% baseline indicating performance equivalent to blind guessing
    plt.plot([0, 1], [0, 1], 'k--')
    plt.plot(fpr, tpr)  # Plot the actual curve calculated from our validation scores
    plt.xlabel('False Positive Rate')
    plt.ylabel('True Positive Rate')
    plt.title('ROC Curve')

    # Save the rendered graph directly to the local disk workspace
    plt.savefig("ROC-Curve.png")

    # MLflow Tracking: Uploads physical media/files directly to the run's cloud registry
    mlflow.log_artifact("ROC-Curve.png")


def parse_args():
    """
    Parses command-line inputs to make paths and configurations dynamic variables.
    """
    parser = argparse.ArgumentParser()

    # --training_data maps to the data path input flag used inside Azure ML jobs
    parser.add_argument("--training_data", dest='training_data', type=str)
    # --reg_rate specifies the model complexity controller parameter
    parser.add_argument("--reg_rate", dest='reg_rate', type=float, default=0.01)

    args = parser.parse_args()
    return args


if __name__ == "__main__":
    print("\n\n")
    print("*" * 60)

    # Ingest inputs and pass parsed variables to launch primary sequence
    args = parse_args()
    main(args)

    print("*" * 60)
    print("\n\n")