# odoo-bitnami-custom

Custom Bitnami Odoo Docker image

## what differs ?

- Include
  - all the <https://github.com/odoomates/odooapps.git>
  - mail debrand module
  - currency rate update module
  - cron job to backup the database and send it to an email
  - cron job to backup the database and send it to an s3 bucket
    …

## Where ?

```sh
docker pull highcanfly/odoo-bitnami-custom:latest
```

## Full kubernetes stack with Helm ?

- a postfix server relaying to where you want with dkim signing
- pgAdmin4 with the same admin user as odoo
- an weekly autobackup script sending backup via email  
- a smtp relay server
  
In the helm/odoo directory:

```sh
helm repo add highcanfly https://helm-repo.highcanfly.club
helm install --create-namespace --namespace odoo-stack odoo-16 helm/odoo --values - << EOF
odoo:
  persistence:
    size: 2Gi
  odooEmail: Administrator@example.org
  odooPassword: goodPasword
  loadDemoData: false
  ingress:
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-issuer
    enabled: true
    ingressClassName: nginx
    hostname: odoo.example.org
    tls: true
  image:
    repository: highcanfly/odoo-bitnami-custom
    tag: latest
    pullPolicy: Always
  resources:
    limits:
      memory: 3Gi
      cpu: 3000m
    requests:
      memory: 128Mi
      cpu: 500m
  extraEnvVars:
    - name: BACKUP_FROM
      value: "backup-odoo@example.org"
    - name: BACKUP_TO
      value: "myAdmin@somewhere.org"
    - name: FQDN
      value: odoo.example.org
    - name: S3_BUCKET
      value: "odoo-backup"
    - name: S3_ENDPOINT
      value: "https://s3.example.org"
    - name: S3_ACCESS_KEY
      value: "myAccessKey"
    - name: S3_SECRET_KEY
      value: "mySecretKey"
    - name: S3_REGION
      value: "eu-west-1"
  customPostInitScripts:
      start-autobackup-cron: |
          #!/bin/bash
          echo "Generate .env file for cron jobs"
          echo "#!/bin/bash" > /etc/kubernetes.env
          env | sed 's/^\(.*\)$/export \1/g' >> /etc/kubernetes.env
          chmod +x /etc/kubernetes.env
          echo "Run init cron"
          mkdir -p /etc/cron.d/
          echo "0 0 * * 0 bash -c '. /etc/kubernetes.env && /usr/local/bin/autobackup'" > /etc/cron.d/autobackup
          echo "0 1 * * * bash -c '. /etc/kubernetes.env && /usr/local/bin/autobackup-s3'" > /etc/cron.d/autobackup-s3
          chmod +x /usr/local/bin/autobackup
          chmod +x /usr/local/bin/autobackup-s3
          crond -f &
  livenessProbe:
    periodSeconds: 120
    timeoutSeconds: 10

flex-smtpd:
  service:
    name: smtpd
  config:
    useCloudflareDDNS: "1"
    useLetsEncrypt: "0"
    useLetsEncryptStaging: "0"
    postfixHostname: odoo-smtp.example.org
    allowedSenderDomains: example.org
    dkimSelector: dkim
    dkimPrivateKey: "-----BEGIN RSA PRIVATE KEY-----|MIICXAIBAAKBgQCZ1gNzg0yOP3U1XFAW2zVw8P96A848CtmoldTd0XhkOJgMyu0M|t7xC0TAp4wrpqZHVyZLekDPZUHPECsRm/Qp1tiMArKIHlaeBrPYDOgAkzTHQEmfW|5AMll34YukUViaZxuhuD8ErdLWlwEhJJqDf8lpqL8iNPsXQ2OYcIRQcigQIDAQAB|AoGAEti6UYOLdH3nwSLPGQ3ADVcpJWyj7o0xv0qj6o0IH9cjIaYWxpEX+mOgb/FF|2/yPRk7MtIGcKIqHtEPRbgCgMDu3VipWzK34blZ/2Eb/Rrn00kfhkA2N7PXJObBh|u2RKRiMzYkmnZ18LeJW1f8L/qgO42UEqzasu19Dugv021wUCQQD5sM1MYyUNg2PX|KY8tfV+0KJ4ZfmUzpdbEG0Za2AxnyD7NgZJ4579FWVxhKZsNYpLzL/gjuYOWBCA4|Wpw2cWrTAkEAnbkltTf/TIOBQMPaBTEPGBgDjt6Krr0zKMQ+0v5XFshogb1yZ96K|ZRYtvCEqjjnIzQ/NnLxJmsy9+phKJARA2wJBAMJnp9B7uROmYwvZLcMLRIJuxXmv|8Xee/XI+ki6U3EPJoyw6YCKGvWNvSf/Udwaa4zM4/AhEnnEk0TlPQyUYdUUCQDq9|FCz8MMj3BLDw/4YFckCf2NthR7ax4ZaiF1+OtzJV6o2+1xeVymbBLsEsfOPA42Zz|Jzji6mqLK4ljI+Fr8BcCQGus3D0lshbU1TF5A13kmm/kFdo+eaRGLnEiLvNqkRCk|n8VRc/pH4OD3vaSuKYDYRMRyj6Asl+q6zMGydCpeSxY=|-----END RSA PRIVATE KEY-----"
    relayHost: "[smtp-relay.gmail.com]:587"
    relayHostUser: "myuser@gmail.com"
    relayHostPassword: "my good password"
    certificateIssuer: letsencrypt-cloudflare
    certificateSecretName: odoo-smtp-example-org-tls
    cloudflareApiKey: "myCloudflareApiKey"
    cloudflareDnsRecords: odoo-smtp.example.org
    cloudflareZoneId: "myCloudflareZoneId"
  image:
    tag: v4.1.0g

pgadmin:
  ingress:
    annotations:
      cert-manager.io/cluster-issuer: lestsencrypt-issuer
    enabled: true
    ingressClassName: nginx
    hosts:
      - host: pgadmin.example.org
        paths:
          - path: /
            pathType: ImplementationSpecific
    tls:
    - hosts:
      - pgadmin.example.org
      secretName: pgadmin.example.org-tls
EOF
```

## Initializing Odoo Database from a File in an S3 Bucket

If you want to initialize the Odoo database from a file in an S3 bucket, you need to set the environment variable `ODOO_INIT_FROM_S3=true` in the Odoo container.

The `initfrom-s3.sh` script will be executed, which uses the following environment variables:

| Variable | Description |
| --- | --- |
| `S3_BUCKET` | The name of the S3 bucket where the backup file is located. |
| `S3_ACCESS_KEY` | The access key to access the S3 bucket. |
| `S3_SECRET_KEY` | The secret key to access the S3 bucket. |
| `S3_ENDPOINT` | The endpoint of the S3 service. |
| `S3_REGION` | The region of the S3 service. |
| `S3_PATH` | The path in the S3 bucket where the backup file is located. |
| `S3_ODOO_FILE` | The name of the backup file. If this variable is not set, the script will use the most recent file in the specified path. |

The script first checks if all necessary variables are set. Then, it checks if the `mc` tool (MinIO Client) is installed and if the `s3backup` alias is set. If the alias is not set, the script sets it.

Next, the script creates a backup directory, finds the most recent backup file in the S3 bucket (or uses the file specified by `S3_ODOO_FILE`), copies it to the backup directory, and if the backup file has the `.enc` extension, decrypts it.
