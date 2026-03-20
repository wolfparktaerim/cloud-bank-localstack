import os
import pymongo
from pymongo.mongo_client import MongoClient
from pymongo.server_api import ServerApi
import dotenv

dotenv.load_dotenv()

# Get credentials from environment variables
MONGODB_USER = os.getenv('MONGODB_USER')
MONGODB_PASS = os.getenv('MONGODB_PASS')

if not MONGODB_USER or not MONGODB_PASS:
    raise ValueError("MongoDB credentials not set in environment variables.")

# Construct the connection string
uri = f"mongodb+srv://{MONGODB_USER}:{MONGODB_PASS}@cluster0.mdwdeqg.mongodb.net/?retryWrites=true&w=majority"

# Create a new client and connect to the server
client = MongoClient(uri, server_api=ServerApi('1'))

try:
    # Send a ping to confirm a successful connection
    client.admin.command('ping')
    print("Pinged your deployment. You successfully connected to MongoDB Atlas!")
except Exception as e:
    print(f"Failed to connect to MongoDB Atlas: {e}")
finally:
    client.close()
