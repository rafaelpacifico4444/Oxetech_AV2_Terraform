#!/bin/bash
set -euxo pipefail

apt-get update -y
apt-get install -y python3-pip python3-venv nginx postgresql-client git

APP_DIR=/opt/app
mkdir -p "$APP_DIR"

git clone https://github.com/rafaelpacifico4444/Oxetech_AV2_Repo "$APP_DIR"
# ou baixe do S3: aws s3 cp s3://$${bucket_name}/app.zip /tmp/app.zip && unzip -d $APP_DIR /tmp/app.zip

python3 -m venv "$APP_DIR/venv"
"$APP_DIR/venv/bin/pip" install --upgrade pip
"$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"

# Variáveis de ambiente da aplicação (injetadas via templatefile).
# SECRET_KEY precisa ser IDÊNTICA em todas as instâncias do ASG, pois
# assina o cookie de sessão do Flask-Login: se cada instância gerasse a
# sua, o usuário seria deslogado a cada troca de instância pelo ALB.
cat > /etc/app.env <<ENV
SECRET_KEY=${flask_secret_key}
DB_HOST=${db_host}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
SESSION_COOKIE_SECURE=true
ENV
chmod 600 /etc/app.env
chown root:www-data /etc/app.env

cat > /etc/systemd/system/gunicorn.service <<'UNIT'
[Unit]
Description=Gunicorn - Flask app
After=network.target

[Service]
User=www-data
WorkingDirectory=/opt/app
EnvironmentFile=/etc/app.env
ExecStart=/opt/app/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:8000 wsgi:app
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

cat > /etc/nginx/sites-available/app <<'NGINX'
server {
    listen 80;
    server_name _;

    location /health {
        proxy_pass http://127.0.0.1:8000;
        access_log off;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        # Repassa o X-Forwarded-Proto que o ALB já define (https), em vez de
        # sobrescrever com $scheme (que aqui seria sempre "http", pois o ALB
        # entrega texto puro na porta 80 da instância após terminar o TLS).
        proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app
rm -f /etc/nginx/sites-enabled/default

systemctl daemon-reload
systemctl enable gunicorn nginx
systemctl restart gunicorn nginx
