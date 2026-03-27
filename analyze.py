import mlflow
import requests
import time
import os
import glob

MLFLOW_URI = os.environ["MLFLOW_URI"]
OLLAMA_URI = os.environ["OLLAMA_URI"]

mlflow.set_tracking_uri(MLFLOW_URI)
os.environ["MLFLOW_TRACKING_URI"] = MLFLOW_URI
mlflow.set_experiment("Fortran_Modernization")

def get_fortran_files():
    return (
        glob.glob("**/*.f90", recursive=True) +
        glob.glob("**/*.f", recursive=True) +
        glob.glob("**/*.for", recursive=True)
    )

def analyze(code):
    prompt = f"Analyze this legacy Fortran for security vulnerabilities and suggest a Python equivalent:\n{code}"
    start = time.time()
    try:
        response = requests.post(
            OLLAMA_URI,
            json={"model": "gemma3:27b", "prompt": prompt, "stream": False},
            timeout=300,
        )
        response.raise_for_status()
        return response.json().get("response", "No response"), time.time() - start
    except Exception as e:
        return f"Error: {e}", 0

files = get_fortran_files()
print(f"Found {len(files)} Fortran file(s)")

for f in files:
    with open(f) as fh:
        code = fh.read()

    with mlflow.start_run(run_name=f"analyze_{os.path.basename(f)}"):
        print(f"Analyzing {f}...")
        analysis, duration = analyze(code)

        mlflow.log_param("model", "gemma3:27b")
        mlflow.log_param("file", f)
        mlflow.log_param("hardware", "RTX 5090")
        mlflow.log_metric("inference_time_sec", duration)

        report = f"File: {f}\n\n{analysis}"
        with open("report.txt", "w") as fh:
            fh.write(report)

        mlflow.log_artifact("report.txt")
        print(f"Done in {duration:.2f}s")