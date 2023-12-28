FROM python:3.12

WORKDIR /flask_app_docker
COPY . /flask_app_docker

RUN pip install -r requirements.txt

RUN python -m venv venv
RUN . venv/bin/activate

EXPOSE 5000

ENV FLASK_APP=flask_app.py

CMD ["python", "-m" , "flask", "run", "--host=0.0.0.0"]