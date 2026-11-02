import os
from flask import Flask, jsonify

app = Flask(__name__)

@app.get('/')
def index():
    return jsonify(message='hello from the secure supply chain demo')

@app.get('/healthz')
def healthz():
    return jsonify(status='ok')

@app.get('/config-check')
def config_check():
    return jsonify(api_key_configured=bool(os.environ.get('API_KEY')))
