import os
from flask import Flask

app = Flask(__name__)


@app.route('/')
def base_route():
    return '<h1>Hey I am {}!</h1>'.format(os.environ['INSTANCE_ID_EC2'])

@app.route('/cluster1')
def cluster_route_1():
    return '<h1>Hey I am {} and I am currently running of the first cluster</h1>'.format(os.environ['INSTANCE_ID_EC2'])

@app.route('/cluster2')
def cluster_route_2():
    return '<h1>Hey I am {} and I am currently running of the second cluster</h1>'.format(os.environ['INSTANCE_ID_EC2'])

@app.route('/hello')
def hello_route():
    return '<h1>Hello World</h1>'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

