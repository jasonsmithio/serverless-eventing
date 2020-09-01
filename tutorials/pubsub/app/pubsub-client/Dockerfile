FROM python:3.7-slim

ADD . .

ARG PROJECT_ID
ENV PROJECT_ID ${PROJECT_ID}

RUN apt-get update && \
    pip install --upgrade pip && \
    pip install -r requirements.txt

#ENTRYPOINT ["python", "-u", "/pubsub-client.py"]

CMD exec gunicorn --bind :$PORT --workers 1 --threads 1 --timeout 0 pubsub-client:app