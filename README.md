# odoo-bitnami-custom
Custom Bitnami Odoo Docker image

# what differs ?
- Include
  - all the https://github.com/odoomates/odooapps.git
  - mail debrand module
  - currency rate update module
    …
# Where ?
```sh
docker pull highcanfly/odoo-bitnami-custom:latest
```

# Full kubernetes stack with Helm ?

- a postfix server relaying to where you want with dkim signing
- pgAdmin4 with the same admin user as odoo
- an weekly autobackup script sending backup via email  
  
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
  customPostInitScripts:
      start-autobackup-cron: |
          #!/bin/bash
          echo "Run init cron"
          ln -svf /usr/local/bin/autobackup /etc/cron.weekly/
          cron -f &
  livenessProbe:
    periodSeconds: 120
    timeoutSeconds: 10

smtpd:
  postfixHostname: odoo-smtp.example.org
  allowedSenderDomains: example.org
  dkimSelector: dkim
  dkimPrivateKey: "-----BEGIN RSA PRIVATE KEY-----|MIICXAIBAAKBgQCZ1gNzg0yOP3U1XFAW2zVw8P96A848CtmoldTd0XhkOJgMyu0M|t7xC0TAp4wrpqZHVyZLekDPZUHPECsRm/Qp1tiMArKIHlaeBrPYDOgAkzTHQEmfW|5AMll34YukUViaZxuhuD8ErdLWlwEhJJqDf8lpqL8iNPsXQ2OYcIRQcigQIDAQAB|AoGAEti6UYOLdH3nwSLPGQ3ADVcpJWyj7o0xv0qj6o0IH9cjIaYWxpEX+mOgb/FF|2/yPRk7MtIGcKIqHtEPRbgCgMDu3VipWzK34blZ/2Eb/Rrn00kfhkA2N7PXJObBh|u2RKRiMzYkmnZ18LeJW1f8L/qgO42UEqzasu19Dugv021wUCQQD5sM1MYyUNg2PX|KY8tfV+0KJ4ZfmUzpdbEG0Za2AxnyD7NgZJ4579FWVxhKZsNYpLzL/gjuYOWBCA4|Wpw2cWrTAkEAnbkltTf/TIOBQMPaBTEPGBgDjt6Krr0zKMQ+0v5XFshogb1yZ96K|ZRYtvCEqjjnIzQ/NnLxJmsy9+phKJARA2wJBAMJnp9B7uROmYwvZLcMLRIJuxXmv|8Xee/XI+ki6U3EPJoyw6YCKGvWNvSf/Udwaa4zM4/AhEnnEk0TlPQyUYdUUCQDq9|FCz8MMj3BLDw/4YFckCf2NthR7ax4ZaiF1+OtzJV6o2+1xeVymbBLsEsfOPA42Zz|Jzji6mqLK4ljI+Fr8BcCQGus3D0lshbU1TF5A13kmm/kFdo+eaRGLnEiLvNqkRCk|n8VRc/pH4OD3vaSuKYDYRMRyj6Asl+q6zMGydCpeSxY=|-----END RSA PRIVATE KEY-----"
  relayHost: "[smtp-relay.gmail.com]:587"

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