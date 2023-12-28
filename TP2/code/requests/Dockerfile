FROM python:3.12

# Set the working directory in the container
WORKDIR /requests_app

# Copy the current directory contents into the container at /usr/src/app
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Run app.py when the container launches
CMD ["python", "requests_app.py"]
