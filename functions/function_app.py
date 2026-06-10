import azure.functions as func
import requests
import pandas as pd
from azure.storage.blob import BlobServiceClient
import os
import io
import logging

app = func.FunctionApp()

# 당뇨 관련 약물 목록 (FDA API 조회 대상)
DIABETES_DRUGS = ['insulin', 'metformin', 'glipizide', 'glyburide', 'pioglitazone', 'rosiglitazone']

@app.timer_trigger(schedule="0 0 * * * *", arg_name="timer")
def fetch_fda(timer: func.TimerRequest) -> None:
    """매시간 FDA API에서 약물 부작용 상위 5건을 수집해 Blob Storage에 저장"""
    rows = []

    for drug in DIABETES_DRUGS:
        res = requests.get(
            "https://api.fda.gov/drug/event.json",
            params={
                "search": f"patient.drug.medicinalproduct:{drug}",
                "count": "patient.reaction.reactionmeddrapt.exact",
                "limit": 5
            }
        )
        if res.status_code == 200:
            for item in res.json().get('results', []):
                rows.append({'drug': drug.upper(), 'reaction': item['term'], 'count': item['count']})
        else:
            logging.warning(f"FDA API 요청 실패 - drug={drug}, status={res.status_code}")

    if not rows:
        logging.warning("수집된 FDA 데이터 없음. Blob 업로드 건너뜀.")
        return

    df = pd.DataFrame(rows)
    csv_buf = io.StringIO()
    df.to_csv(csv_buf, index=False)

    conn_str = os.environ["STORAGE_CONNECTION_STRING"]
    client = BlobServiceClient.from_connection_string(conn_str)
    client.get_blob_client("raw", "fda_adverse_events.csv").upload_blob(
        csv_buf.getvalue(), overwrite=True
    )
    logging.info(f"FDA 데이터 업로드 완료: {len(rows)}행")
