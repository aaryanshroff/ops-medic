import os

from flask import Flask, request

from lambda_function import lambda_handler

app = Flask(__name__)

@app.route("/")
def hello_world():
    return "<p>Hello, World!</p>"

@app.route("/webhook")
def webhook():
    print(request)

if __name__ == "__main__":
    port = int(os.environ.get("FLASK_PORT", 8080))
    app.run(host='0.0.0.0', port=port)