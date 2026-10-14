# Mealie Backup & Restore

Bash scripts to backup and restore Mealie Docker container (SQLite + recipe images).

## Issue: Mealie's backup restore sometime corruptes the login authentication making user unable to login. 

Fix: 
- Bypass Mealie's backup and restore, use mealie_backup.sh to backup Mealie database and images.
- Use mealie_restore.sh to copy backup the raw database and image files backup into the Mealie docker container.

## Folder Structure
```
mealie_backup_deploy/
├── .gitignore
├── README.md
├── mealie.env              # Create only if using Okta (see mealie.env.example)
├── mealie.env.example
├── mealie_backup.sh        # (Important: stop Mealie before running this bash script)
├── mealie_restore.sh       # Pulls image, restores from latest backup_YYMMDD_HHMMSS/
└── backup_YYMMDD_HHMMSS/   # Created by backup script (gitignored)
    ├── mealie.db           # SQLite database (recipes, users, settings)
    └── recipe_images.tar.gz  # All recipe images
```

## Backup
```./mealie_backup.sh```   

- Stops the Mealie container
- Copies mealie.db and recipe_images/ from the container
- Compresses images into recipe_images.tar.gz
- Creates a timestamped folder: backup_YYMMDD_HHMMSS/
- Starts Mealie back up

## Restore
```./mealie_restore.sh```

- Pulls the latest ghcr.io/mealie-recipes/mealie:latest image
- Removes any existing Mealie container
- Copies mealie.db and extracts recipe_images.tar.gz into the data volume
- Starts a new container with any env vars from mealie.env

## mealie.env
Only needed if you use Okta/OIDC login. Not required for basic operation.

Create it from the template:
```cp mealie.env.example mealie.env```   

Then fill in your Okta values:
```
OIDC_AUTH_ENABLED=true
OIDC_SIGNUP_ENABLED=true
OIDC_CONFIGURATION_URL=https://your-tenant.okta.com/.well-known/openid-configuration
OIDC_CLIENT_ID=your_client_id
OIDC_CLIENT_SECRET=your_client_secret
OIDC_PROVIDER_NAME=Okta
```

| Variable | Required | Description |
|---|---|---|
| `OIDC_AUTH_ENABLED` | Yes | Enables OIDC login |
| `OIDC_SIGNUP_ENABLED` | Yes | Auto-creates Mealie accounts on first Okta login |
| `OIDC_CONFIGURATION_URL` | Yes | Your Okta tenant's OIDC discovery URL |
| `OIDC_CLIENT_ID` | Yes | Okta app client ID |
| `OIDC_CLIENT_SECRET` | Yes | Okta app client secret |
| `OIDC_PROVIDER_NAME` | No | Display name on login button (default: OAuth) |
| `OIDC_USER_GROUP` | No | Restrict access to a specific Okta group |
| `OIDC_ADMIN_GROUP` | No | Okta group that gets Mealie admin |

## Notes

- Backup requires the container to be stopped (script handles this automatically)
- Restore uses $HOME/mealie/data as the volume path
- The restore script picks the newest backup_YYMMDD_HHMMSS/ folder automatically
- This is a raw file swap (not Mealie's in-app restore), so it avoids the auth bug in Mealie's restore process

get list of users
```
docker exec -it mealie python -c "
import sqlite3
conn = sqlite3.connect('/app/data/mealie.db')
rows = conn.execute('SELECT id, email, auth_method, locked_at, login_attemps, cache_key FROM users').fetchall()
for r in rows:
    print(r)
conn.close()
"
```
change the password
```
docker exec -it mealie python /opt/mealie/lib/python3.14/site-packages/mealie/scripts/change_password.py
```

reset locked users
```
docker exec -it mealie python /opt/mealie/lib/python3.14/site-packages/mealie/scripts/reset_locked_users.py
```   
