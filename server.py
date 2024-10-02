import io
import os
import time
import zipfile
from typing import Any, Literal, Optional, TypedDict

import jwt
import requests
from dotenv import load_dotenv
from flask import Flask, request

load_dotenv()

app = Flask(__name__)

FLASK_PORT = int(os.environ.get("FLASK_PORT", 3000))
PEM_FILE_PATH = os.getenv("PEM_FILE_PATH")
GITHUB_APP_CLIENT_ID = "Iv23limjQewW9Ze9C50p"

cached_token: Optional[str] = None
token_expires_at = 0


class WorkflowJobPayload(TypedDict):
    action: Literal["completed"] | str
    workflow_job: str


class WorkflowJob(TypedDict):
    conclusion: Literal["failure"] | str


class EnvVarNotFound(Exception):
    def __init__(self, var: str):
        self.var = var

    def __str__(self):
        return f"{self.var} environment variable not found"


@app.post("/")
def events():
    if not request.is_json:
        return {"error": "Request must be JSON"}, 415

    event = request.headers.get("X-GitHub-Event", "unknown")
    print(f"Received event {event}")

    if event == "workflow_run":
        _handle_workflow_run_event()
    else:
        print(f"Ignored unsupported event {event}")

    return "", 204


def _handle_workflow_run_event() -> None:
    payload = request.json
    # print(payload)

    action: Optional[str] = payload.get("action")
    workflow_run: dict[str, Any] = payload.get("workflow_run", {})
    conclusion = workflow_run.get("conclusion")
    # print(action, workflow_run, conclusion)

    if action == "completed" and conclusion == "failure":
        logs_url = workflow_run.get("logs_url")
        print("Logs URL", logs_url)

        installation = payload.get("installation", {})
        installation_id = installation.get("id")

        access_token = _get_or_create_installation_access_token(installation_id)

        zip_content = _download_workflow_logs_zip(logs_url, access_token)
        print("Downloaded ZIP content from logs_url.")

        logs = _extract_logs_from_zip(zip_content)
        # print("Extracted Logs:", logs)

        gemini_summary = _summarize_logs_with_gemini(logs)
        content = gemini_summary["candidates"][0]["content"]["parts"][0]["text"]

        pr_number = _get_pr_number_from_workflow_run(payload)
        if pr_number:
            _comment_on_pr(payload, pr_number, content, access_token)
        else:
            print("No associated PR found for this workflow run.")



def _download_workflow_logs_zip(logs_url: str, access_token: str) -> bytes:
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Accept": "application/vnd.github.v3+json",
    }

    response = requests.get(logs_url, headers=headers)
    response.raise_for_status()

    return response.content


def _extract_logs_from_zip(zip_content: bytes) -> str:
    with zipfile.ZipFile(io.BytesIO(zip_content)) as z:
        log_files = [f for f in z.namelist() if f.endswith(".txt")]
        if not log_files:
            return "No log files found in the workflow logs."

        logs = ""
        for log_file in log_files:
            with z.open(log_file) as file_:
                logs += file_.read().decode("utf-8") + "\n"

    return logs


def _summarize_logs_with_gemini(logs: str) -> str:
    if (api_key := os.getenv("GEMINI_API_KEY")) is None:
        raise EnvVarNotFound("GEMINI_API_KEY")

    headers = {
        "Content-Type": "application/json"
    }

    params = {
        "key": api_key
    }

    payload = {
        "contents": [{
            "parts": [{
                "text": logs
            }]
        }]
    }

    response = requests.post("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent", json=payload, headers=headers, params=params)
    response.raise_for_status()
    return response.json()

def _get_or_create_installation_access_token(installation_id: str) -> str:
    global cached_token, token_expires_at

    current_time = int(time.time())
    if cached_token and current_time < token_expires_at:
        return cached_token

    signing_key = _get_signing_key()
    client_id = GITHUB_APP_CLIENT_ID

    encoded_jwt = _generate_jwt(client_id, signing_key)
    token_data = _create_installation_access_token(encoded_jwt, installation_id)

    cached_token = token_data.get("token")
    expires_at_str = token_data.get("expires_at")
    expires_at_struct = time.strptime(expires_at_str, "%Y-%m-%dT%H:%M:%SZ")
    token_expires_at = int(time.mktime(expires_at_struct)) - 60

    return cached_token

def _get_pr_number_from_workflow_run(payload: dict[str, Any]) -> int:
    workflow_run = payload["workflow_run"]
    pulls = workflow_run["pull_requests"]

    pr_number = pulls[0]["number"]
    return pr_number


def _comment_on_pr(payload: dict[str, Any], pr_number: int, content: str, access_token: str) -> None:
    repository = payload.get("repository", {})
    owner = repository.get("owner", {}).get("login")
    repo = repository.get("name")

    if not all([owner, repo, pr_number]):
        print("Insufficient information to post a comment.")
        return

    url = f"https://api.github.com/repos/{owner}/{repo}/issues/{pr_number}/comments"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Accept": "application/vnd.github.v3+json",
    }
    data = {
        "body": content
    }

    response = requests.post(url, headers=headers, json=data)
    response.raise_for_status()
    print(f"Posted Gemini summary as a comment on PR #{pr_number}.")

def _create_installation_access_token(encoded_jwt: str, installation_id: str) -> str:
    headers = {
        "Authorization": f"Bearer {encoded_jwt}",
        "Accept": "application/vnd.github.v3+json",
    }
    url = f"https://api.github.com/app/installations/{installation_id}/access_tokens"

    response = requests.post(url, headers=headers)
    response.raise_for_status()

    return response.json()


def _get_signing_key() -> str:
    with open(PEM_FILE_PATH, "rb") as f:
        return f.read()


def _generate_jwt(client_id: str, signing_key: str) -> str:
    payload = {
        "iat": int(time.time()),
        "exp": int(time.time()) + 600,
        "iss": GITHUB_APP_CLIENT_ID,
    }

    encoded_jwt = jwt.encode(payload, signing_key, algorithm="RS256")

    return encoded_jwt


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=FLASK_PORT, debug=True)
