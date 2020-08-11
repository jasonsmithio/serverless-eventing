import os
import io
import json
import logging
import time
import json
import requests


from cloudevents.sdk import converters
from cloudevents.sdk import marshaller
from cloudevents.sdk.converters import structured
from cloudevents.sdk.event import v1

from flask import Flask, jsonify, redirect, render_template, request, Response

import asyncio
from nats.aio.client import Client as NATS
from stan.aio.client import Client as STAN
from nats.aio.errors import ErrConnectionClosed, ErrTimeout, ErrNoServers

app = Flask(__name__)


## Logger

def info(msg):
    app.logger.info(msg)


## App Route

@app.route('/', methods=['POST'])
def default_route():
    if request.method == 'POST':
        content = request.data.decode('utf-8')
        info(f'Event Display received event: {content}')

###
        # Async with NATS Streaming

        async def run(loop):
            nc = NATS()
            sc = STAN()

            await nc.connect("nats://nats-streaming.natss.svc:4222", loop=loop)
            await sc.connect("knative-nats-streaming", "testing-1", nats=nc)

            async def ack_handler(ack):
                print("Received ack: {}".format(ack.guid))

            # Publish asynchronously by using an ack_handler which
            # will be passed the status of the publish.

            await sc.publish("foo.default", json.dumps({"specversion": "1.0", "type" : "dev.knative.messaging.natsschannel", "source" : "/apis/messaging.knative.dev/v1alpha1/namespaces/default/natsschannels/foo", "data" : content }).encode(), ack_handler=ack_handler)
            #await sc.publish("foo.default", event, ack_handler=ack_handler)
            async def cb(msg):
                print("Received a message on subscription (seq: {}): {}".format(msg.sequence, msg.data))

            await sc.subscribe("foo.default", start_at='first', cb=cb)
            await asyncio.sleep(1, loop=loop)

            await sc.close()
            await nc.close()

#####

        loop = asyncio.get_event_loop()
        loop.run_until_complete(run(loop))
        #loop.run_until_complete(run(Eventing(content)))
        #loop.close()

        return jsonify(hello=str(content))
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
