# Use the official Python image from Docker Hub
FROM python:3.11-slim

# Set the working directory inside the container
WORKDIR /app

# Copy the Python script into the container
COPY ../scripts/mongodb.py .

# Install pymongo
RUN pip install requirements.txt

# Run the script by default
CMD ["python", "mongodb.py"]

