FROM python:3.7-slim

ADD . .

ARG PROJECT_ID
ARG TOPIC
ENV PROJECT_ID=${PROJECT_ID}
ENV TOPIC=${TOPIC}


RUN pip install --upgrade pip
RUN pip install -r requirements.txt

ENTRYPOINT ["python", "-u", "/twitter-producer.py"]
