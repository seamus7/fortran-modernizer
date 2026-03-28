import mlflow
import requests
import time
import os
import glob
import re

MLFLOW_URI = os.environ["MLFLOW_URI"]
OLLAMA_URI = os.environ["OLLAMA_URI"]
OLLAMA_BASE_URI = OLLAMA_URI.replace("/api/generate", "")

mlflow.set_tracking_uri(MLFLOW_URI)
os.environ["MLFLOW_TRACKING_URI"] = MLFLOW_URI
mlflow.set_experiment("Fortran_Modernization")

# List of models to analyze with
MODELS = ["gemma3:27b", "qwen3-coder-next"]


def get_fortran_files():
    return (
        glob.glob("**/*.f90", recursive=True)
        + glob.glob("**/*.f", recursive=True)
        + glob.glob("**/*.for", recursive=True)
    )


def count_non_empty_non_comment_lines(code):
    lines = code.splitlines()
    count = 0
    for line in lines:
        stripped = line.strip()
        # Skip empty lines and comment lines (starting with C, *, or !)
        if stripped and not stripped[0].upper() in ["C", "*", "!"]:
            count += 1
    return count


def count_vulnerability_keywords(text):
    keywords = ["vulnerability", "risk", "overflow", "unsafe", "deprecated"]
    text_lower = text.lower()
    count = 0
    for keyword in keywords:
        count += text_lower.count(keyword)
    return count


def has_goto(code):
    # Match GOTO statements (case-insensitive)
    pattern = r"\bgoto\b"
    return 1 if re.search(pattern, code, re.IGNORECASE) else 0


def has_common_block(code):
    # Match COMMON blocks (case-insensitive)
    pattern = r"\bcommon\b"
    return 1 if re.search(pattern, code, re.IGNORECASE) else 0


def has_implicit(code):
    # Match IMPLICIT statements (case-insensitive)
    pattern = r"\bimplicit\b"
    return 1 if re.search(pattern, code, re.IGNORECASE) else 0


def unload_model(model_name):
    """Unload a model from Ollama by calling /api/generate with keep_alive: 0"""
    endpoint = f"{OLLAMA_BASE_URI}/api/generate"
    try:
        response = requests.post(
            endpoint,
            json={"model": model_name, "prompt": "", "stream": False, "keep_alive": 0},
            timeout=30,
        )
        response.raise_for_status()
        return True
    except Exception as e:
        print(f"Warning: Failed to unload model {model_name}: {e}")
        return False


def analyze(code, model_name):
    prompt = f"Analyze this legacy Fortran for security vulnerabilities and suggest a Python equivalent:\n{code}"
    start = time.time()
    try:
        response = requests.post(
            OLLAMA_URI,
            json={"model": model_name, "prompt": prompt, "stream": False},
            timeout=300,
        )
        response.raise_for_status()
        response_json = response.json()
        analysis = response_json.get("response", "No response")
        total_duration = response_json.get("total_duration", 0)
        return analysis, time.time() - start, total_duration
    except Exception as e:
        return f"Error: {e}", 0, 0


files = get_fortran_files()
print(f"Found {len(files)} Fortran file(s)")

for model in MODELS:
    for f in files:
        with open(f) as fh:
            code = fh.read()

        with mlflow.start_run(run_name=f"analyze_{os.path.basename(f)}_{model}"):
            print(f"Analyzing {f} with {model}...")
            analysis, duration, total_duration = analyze(code, model)

            # Existing metrics
            mlflow.log_param("model", model)
            mlflow.log_param("file", f)
            mlflow.log_param("hardware", "RTX 5090")
            mlflow.log_metric("inference_time_sec", duration)

            # New metrics
            lines_of_code = count_non_empty_non_comment_lines(code)
            vulnerability_count = count_vulnerability_keywords(analysis)
            has_goto_flag = has_goto(code)
            has_common_block_flag = has_common_block(code)
            has_implicit_flag = has_implicit(code)
            token_count = total_duration  # total_duration is in nanoseconds, but we'll log as-is per request

            mlflow.log_metric("lines_of_code", lines_of_code)
            mlflow.log_metric("vulnerability_count", vulnerability_count)
            mlflow.log_metric("has_goto", has_goto_flag)
            mlflow.log_metric("has_common_block", has_common_block_flag)
            mlflow.log_metric("has_implicit", has_implicit_flag)
            mlflow.log_metric("token_count", token_count)

            report = f"File: {f}\n\n{analysis}"
            with open("report.txt", "w") as fh:
                fh.write(report)

            mlflow.log_artifact("report.txt")
            print(f"Done in {duration:.2f}s")

    # Unload model after all files for this model are processed
    time.sleep(5)
    unload_model(model)
