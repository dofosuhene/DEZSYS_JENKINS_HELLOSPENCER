FROM python:3.11-slim-buster
ADD . /python-flask
WORKDIR /python-flask
RUN pip install -r requirements.txt
CMD ["python", "src/hello.py"]