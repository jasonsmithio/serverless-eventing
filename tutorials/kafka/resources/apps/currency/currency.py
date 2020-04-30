import os
import json
import requests
import time

from google.cloud import secretmanager

from pathlib import Path  # python3 only

from alpha_vantage.timeseries import TimeSeries

sink_url = os.getenv('K_SINK')

PROJECT_ID = os.environ.get('PROJECT_ID')

secrets = secretmanager.SecretManagerServiceClient()

ALPHAVANTAGE_KEY = secrets.access_secret_version("projects/"+PROJECT_ID+"/secrets/alpha-vantage-key/versions/1").payload.data.decode("utf-8")

CURR1 = 'USD'
CURR2 = 'JPY'

afx = ForeignExchange(key=ALPHAVANTAGE_KEY)

def make_msg(message):
    msg = '{"msg": "%s"}' % (message)
    return msgs


def get_currency():
    data, _ = afx.get_currency_exchange_rate(
            from_currency=CURR1, to_currency=CURR2)
    exchangeObj = json.dumps(data)
    exrate = float(exchange['5. Exchange Rate'])
    return exrate


while True:
    headers = {'Content-Type': 'application/cloudevents+json'}
    body = get_currency()
    requests.post(sink_url, data=json.dumps(body), headers=headers)
    time.sleep(30)