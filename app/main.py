from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI

app = FastAPI(title="live-event-bridge")
