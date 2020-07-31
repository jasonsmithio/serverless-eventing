
FROM python:3.7-slim

ADD . .

RUN apt-get update && \
    pip install --upgrade pip && \
    pip install -r requirements.txt

ENTRYPOINT ["python", "-u", "/natss-client.py"]