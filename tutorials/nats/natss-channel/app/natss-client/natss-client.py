import os
import json
import logging
import time
import json



from flask import Flask, jsonify, redirect, render_template, request, Response


from pynats import NATSClient

import asyncio
from nats.aio.client import Client as NATS
from stan.aio.client import Client as STAN
from nats.aio.errors import ErrConnectionClosed, ErrTimeout, ErrNoServers

app = Flask(__name__)

# Async with NATS Streaming
async def run(loop):
    nc = NATS()
    sc = STAN()
    await nc.connect("nats://nats-streaming.natss.svc:4222", loop=loop)
    #await sc.connect("nats://nats-streaming.natss.svc:4222", "client-123", nats=nc)
    await sc.connect("knative-nats-streaming", "testing", nats=nc)

    async def ack_handler(ack):
        print("Received ack: {}".format(ack.guid))

    # Publish asynchronously by using an ack_handler which
    # will be passed the status of the publish.
    for i in range(0, 1024):
        await sc.publish("foo", b'hello-world', ack_handler=ack_handler)

    async def cb(msg):
        print("Received a message on subscription (seq: {}): {}".format(msg.sequence, msg.data))

    await sc.subscribe("foo", start_at='first', cb=cb)
    await asyncio.sleep(1, loop=loop)

    await sc.close()
    await nc.close()


## Logger

def info(msg):
    app.logger.info(msg)



## NATS example

async def example():

   # [begin publish_json]
   nc = NATS()

   await nc.connect(servers=["nats://nats-streaming.natss.svc:4222"])

   await nc.publish("foo", json.dumps({"symbol": "GOOG", "price": 1200 }).encode())

   # [end publish_json]

   await nc.close()


## App Route

@app.route('/', methods=['POST'])
def default_route():
    if request.method == 'POST':
        content = request.data.decode('utf-8')
        info(f'Event Display received event: {content}')

        loop = asyncio.get_event_loop()
        #loop.run_until_complete(example())
        loop.run_until_complete(run(loop))
        loop.close()

        return jsonify(hello=str(content))
    else:
        return jsonify('No Data')



#if __name__ == '__main__':
#    loop = asyncio.get_event_loop()
#    loop.run_until_complete(run(loop))
#    loop.close()




## Rnu Flask

if __name__ != '__main__':
    # Redirect Flask logs to Gunicorn logs
    gunicorn_logger = logging.getLogger('gunicorn.error')
    app.logger.handlers = gunicorn_logger.handlers
    app.logger.setLevel(gunicorn_logger.level)
    info('Event Display starting')
else:
    app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))