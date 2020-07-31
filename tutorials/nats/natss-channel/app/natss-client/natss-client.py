import os
import json
import logging
import time
import json



from flask import Flask, jsonify, redirect, render_template, request, Response


from pynats import NATSClient

import asyncio
from nats.aio.client import Client as NATS
from nats.aio.errors import ErrConnectionClosed, ErrTimeout, ErrNoServers

app = Flask(__name__)


def info(msg):
    app.logger.info(msg)

@app.route('/', methods=['POST'])
def default_route():
    if request.method == 'POST':
        content = request.data.decode('utf-8')
        info(f'Event Display received event: {content}')

        producer.send('money-demo', bytes(content, encoding='utf-8'))

        return jsonify(hello=str(content))
    else:
        return jsonify('hello world')

async def run(loop):
    nc = NATS()

    await nc.connect("nats://nats-streaming.natss.svc:4222", loop=loop)

    async def message_handler(msg):
        subject = msg.subject
        reply = msg.reply
        data = msg.data.decode()
        print("Received a message on '{subject} {reply}': {data}".format(
            subject=subject, reply=reply, data=data))

    # Simple publisher and async subscriber via coroutine.
    sid = await nc.subscribe("foo", cb=message_handler)

    # Stop receiving after 2 messages.
    await nc.auto_unsubscribe(sid, 2)
    await nc.publish("foo", b'Hello')
    await nc.publish("foo", b'World')
    await nc.publish("foo", b'!!!!!')

    async def help_request(msg):
        subject = msg.subject
        reply = msg.reply
        data = msg.data.decode()
        print("Received a message on '{subject} {reply}': {data}".format(
            subject=subject, reply=reply, data=data))
        await nc.publish(reply, b'I can help')

    # Use queue named 'workers' for distributing requests
    # among subscribers.
    sid = await nc.subscribe("help", "workers", help_request)

    # Send a request and expect a single response
    # and trigger timeout if not faster than 1 second.
    try:
        response = await nc.request("help", b'help me', timeout=1)
        print("Received response: {message}".format(
            message=response.data.decode()))
    except ErrTimeout:
        print("Request timed out")

    # Remove interest in subscription.
    await nc.unsubscribe(sid)

    # Terminate connection to NATS.
    await nc.close()

if __name__ == '__main__':
    loop = asyncio.get_event_loop()
    loop.run_until_complete(run(loop))
    loop.close()






#if __name__ != '__main__':
#    # Redirect Flask logs to Gunicorn logs
#    gunicorn_logger = logging.getLogger('gunicorn.error')
#    app.logger.handlers = gunicorn_logger.handlers
#    app.logger.setLevel(gunicorn_logger.level)
#    info('Event Display starting')
#else:
#    app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))