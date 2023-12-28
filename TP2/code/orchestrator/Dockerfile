FROM python:3.12

# Set the working directory
WORKDIR /orchestrator_app

# Copy the current directory contents into the container at /orchestrator_app
COPY . .

# Install the dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Expose port 5000 for the Flask app to listen on
EXPOSE 5000

# Run the app
CMD ["python", "orchestrator.py"]
