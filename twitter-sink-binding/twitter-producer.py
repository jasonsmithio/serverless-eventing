#!/usr/bin/env python

import os
import json
import requests
import time

from google.cloud import secretmanager

import tweepy


sink_url = os.getenv('K_SINK')

PROJECT_ID = os.environ.get('PROJECT_ID')

TOPIC = os.environ.get('TOPIC')

secrets = secretmanager.SecretManagerServiceClient()
TWITTER_KEY = secrets.access_secret_version("projects/"+PROJECT_ID+"/secrets/twitter-api-key/versions/1").payload.data.decode("utf-8")
TWITTER_SECRET = secrets.access_secret_version("projects/"+PROJECT_ID+"/secrets/twitter-api-secret/versions/1").payload.data.decode("utf-8")
ACCESS_TOKEN = secrets.access_secret_version("projects/"+PROJECT_ID+"/secrets/twitter-access-key/versions/1").payload.data.decode("utf-8")
ACCESS_SECRET = secrets.access_secret_version("projects/"+PROJECT_ID+"/secrets/twitter-access-secret/versions/1").payload.data.decode("utf-8")



auth = tweepy.OAuthHandler(TWITTER_KEY, TWITTER_SECRET)
auth.set_access_token(ACCESS_TOKEN, ACCESS_SECRET)
api = tweepy.API(auth)


def make_msg(message):
    msg = '{"msg": "%s"}' % (message)
    return msg

def get_tweet():
    tweets = []
    for tweet in api.search(q=TOPIC,count=25,
                        lang="en",
                        since="2020-01-01"):
        newmsg = make_msg(tweet.text)   
        tweets.append(newmsg)

    return tweets


headers = {'Content-Type': 'application/cloudevents+json'}

while True:
    body = get_tweet()
    requests.post(sink_url, data=json.dumps(body), headers=headers)
    time.sleep(30)
