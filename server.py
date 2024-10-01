import os
import jwt
import time
from typing import Any, Literal, Optional, TypedDict

from flask import Flask, request
import requests

app = Flask(__name__)

FLASK_PORT = int(os.environ.get("FLASK_PORT", 3000))
PEM_FILE_PATH = os.environ.get("PEM_FILE_PATH")
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
    workflow_job: dict[str, Any] = payload.get("workflow_run", {})
    conclusion = workflow_job.get("conclusion")

    if action == "completed" and conclusion == "failed":
        logs_url = workflow_job.get("logs_url")
        print("Logs URL", logs_url)

        installation = payload.get("installation", {})
        installation_id = installation.get("id")

        access_token = _get_or_create_installation_access_token(installation_id)
        print(_fetch_workflow_logs(logs_url, access_token))

def _fetch_workflow_logs(logs_url: str, access_token: str) -> str:
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Accept": "application/vnd.github.v3+json"
    }

    response = requests.get(logs_url, headers=headers)
    response.raise_for_status()

    return response.text



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
