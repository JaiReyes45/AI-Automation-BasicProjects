import requests

response = requests.post(
    "http://localhost:5678/webhook-test/f4fa322b-4e70-4068-812b-012d576729df",
    json={
        "description": "YouTube subscription",
        "amount":300,
        "date": "2026-08-18"
    }
)

print(response.status_code)