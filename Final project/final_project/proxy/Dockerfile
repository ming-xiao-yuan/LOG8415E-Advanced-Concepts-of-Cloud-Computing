FROM python:3.8

# Set the working directory
WORKDIR /proxy_app

# Install ping utility
RUN apt-get update && apt-get install -y iputils-ping

# Copy the current directory contents into the container at /proxy_app
COPY . .

# Install the dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Expose port 5000 for the Flask app to listen on
EXPOSE 5000

# Run the app
CMD ["python", "proxy.py"]
