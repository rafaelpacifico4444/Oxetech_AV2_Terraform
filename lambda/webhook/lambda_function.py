# lambda_function.py
import boto3, json, hmac, hashlib, os

ssm    = boto3.client("ssm")
SECRET = os.environ["GITHUB_WEBHOOK_SECRET"]

def handler(event, context):
    # 1. Valida a assinatura que o GitHub manda em todo webhook
    body      = event.get("body") or ""
    signature = (event.get("headers") or {}).get("x-hub-signature-256", "")
    expected  = "sha256=" + hmac.new(
        SECRET.encode(), body.encode(), hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(expected, signature):
        return {"statusCode": 401, "body": "assinatura invalida"}

    # 2. Só age quando o push foi na branch main
    payload = json.loads(body)
    if payload.get("ref") != "refs/heads/main":
        return {"statusCode": 200, "body": "ignorado (branch diferente)"}

    # 3. Dispara o update em TODAS as instâncias do ASG de uma vez via SSM
    ssm.send_command(
        Targets=[{"Key": "tag:Name", "Values": ["lab-iac-dev-web"]}],
        DocumentName="AWS-RunShellScript",
        Parameters={"commands": [
            "cd /opt/app && git pull && systemctl restart gunicorn"
        ]},
    )
    return {"statusCode": 200, "body": "deploy disparado"}# test trigger deploy lambda
