import os
import io
import json
import logging
import time
import json
import requests


from google.cloud import pubsub_v1
import cloudevents.exceptions as cloud_exceptions
from cloudevents.http import from_http

from flask import Flask, jsonify, redirect, render_template, request, Response


app = Flask(__name__)

PROJECT_ID = os.environ.get('PROJECT_ID')

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(PROJECT_ID, "currency-pubsub")

futures = dict()


## Logger

def info(msg):
    app.logger.info(msg)


## App Route

@app.route('/', methods=['POST'])
def default_route():
    if request.method == 'POST':
        content = request.data.decode('utf-8')
        info(f'Event Display received event: {content}')
        content = bytes(content, 'utf-8')
        future = publisher.publish(topic_path, data=content)


        return jsonify(hello=str(future))
    else:
        return jsonify('No Data')


## Run Flask

if __name__ != '__main__':
    # Redirect Flask logs to Gunicorn logs
    gunicorn_logger = logging.getLogger('gunicorn.error')
    app.logger.handlers = gunicorn_logger.handlers
    app.logger.setLevel(gunicorn_logger.level)
    info('Event Display starting')
else:
    app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))