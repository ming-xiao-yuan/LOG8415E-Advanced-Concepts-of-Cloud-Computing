"""
This Flask application serves as a worker instance for running ML inference using a pre-trained DistilBert model.
The '/run_model' route listens for POST requests to perform inference on randomly generated text.
It tokenizes the input, runs it through the DistilBertForSequenceClassification model, and returns the probabilities as a JSON response.

Usage:
The server starts on port 5000 and listens on all network interfaces.
"""

import os
from flask import Flask, jsonify
from transformers import DistilBertTokenizer, DistilBertForSequenceClassification
import torch
import random
import string


app = Flask(__name__)

# Load the pre-trained model and tokenizer
tokenizer = DistilBertTokenizer.from_pretrained("distilbert-base-uncased")
model = DistilBertForSequenceClassification.from_pretrained(
    "distilbert-base-uncased", num_labels=2
)


def generate_random_text(length=50):
    letters = string.ascii_lowercase + " "
    return "".join(random.choice(letters) for i in range(length))


@app.route("/health_check", methods=["GET"])
def health_check():
    return "<h1>Hello, I am a worker instance {} and I am running!</h1>".format(
        os.environ["INSTANCE_ID_EC2"]
    )


@app.route("/run_model", methods=["POST"])
def run_model():
    # Generate random input text
    input_text = generate_random_text()

    # Tokenize the input text and run it through the model
    inputs = tokenizer(input_text, return_tensors="pt", padding=True, truncation=True)
    outputs = model(**inputs)

    # The model returns logits, so let's turn that into probabilities
    probabilities = torch.softmax(outputs.logits, dim=-1)

    # Convert the tensor to a list and return
    probabilities_list = probabilities.tolist()[0]

    return jsonify({"input_text": input_text, "probabilities": probabilities_list})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)  # Adjust the port as needed for your setup
