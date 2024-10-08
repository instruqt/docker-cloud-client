#!/bin/bash

# Available env vars:
# INSTRUQT_AWS_ACCOUNTS
# INSTRUQT_AWS_ACCOUNT_%s_ACCOUNT_NAME
# INSTRUQT_AWS_ACCOUNT_%s_ACCOUNT_ID
# INSTRUQT_AWS_ACCOUNT_%s_USERNAME
# INSTRUQT_AWS_ACCOUNT_%s_PASSWORD
# INSTRUQT_AWS_ACCOUNT_%s_AWS_ACCESS_KEY_ID
# INSTRUQT_AWS_ACCOUNT_%s_AWS_SECRET_ACCESS_KEY

# INSTRUQT_GCP_PROJECTS
# INSTRUQT_GCP_PROJECT_%s_PROJECT_NAME
# INSTRUQT_GCP_PROJECT_%s_PROJECT_ID
# INSTRUQT_GCP_PROJECT_%s_USER_EMAIL
# INSTRUQT_GCP_PROJECT_%s_USER_PASSWORD
# INSTRUQT_GCP_PROJECT_%s_SERVICE_ACCOUNT_EMAIL
# INSTRUQT_GCP_PROJECT_%s_SERVICE_ACCOUNT_KEY

BASEDIR=/opt/instruqt/bootstrap

gcloud_init() {
    if [ -n "${INSTRUQT_GCP_PROJECTS}" ]; then
        IFS=',' read -r -a PROJECTS <<< "$INSTRUQT_GCP_PROJECTS"

        # load all credentials into gcloud
        for PROJECT in "${PROJECTS[@]}"; do
            TMP_FILE=$(mktemp)
            SERVICE_ACCOUNT_KEY="INSTRUQT_GCP_PROJECT_${PROJECT}_SERVICE_ACCOUNT_KEY"
            SERVICE_ACCOUNT_EMAIL="INSTRUQT_GCP_PROJECT_${PROJECT}_SERVICE_ACCOUNT_EMAIL"
            base64 -d <(echo "${!SERVICE_ACCOUNT_KEY}") > "$TMP_FILE"

            service_account_activated=false
            # Retry gcloud auth activate service account.
            for (( i = 1, retries = 5; i <= retries; i++ )); do
                if gcloud auth activate-service-account --key-file="$TMP_FILE"; then
                    service_account_activated=true
                    echo "Command succeeded on attempt $i."
                    break
                else
                    echo "Command failed on attempt $i."
                    # If it's not the last attempt, wait before retrying.
                    if [ "$i" -lt "$retries" ]; then
                        echo "Retrying in $i seconds..."
                        sleep "$i"
                    fi
                fi
            done

            rm "$TMP_FILE"

            # If the account is not activated then we should skip waiting
            # for it to be marked as active.
            if [[ $service_account_activated == false ]]; then
              continue
            fi

            # Retry checking account is active.
            for (( i = 1, retries = 5; i <= retries; i++ )); do
                is_active=$(gcloud auth list \
                  --filter="status:ACTIVE AND account:${!SERVICE_ACCOUNT_EMAIL}" \
                  --format="json(account)" | jq ". | length")
                if [[ $is_active -eq 1 ]]; then
                    echo "Service account ${!SERVICE_ACCOUNT_EMAIL} is active on attempt $i."
                    break
                else
                    echo "Service account ${!SERVICE_ACCOUNT_EMAIL} is not yet active. Retrying in 5 seconds..."
                    sleep 5
                fi
            done
        done

        # activate service account for first project
        SERVICE_ACCOUNT_EMAIL="INSTRUQT_GCP_PROJECT_${PROJECTS[0]}_SERVICE_ACCOUNT_EMAIL"
        gcloud config set account "${!SERVICE_ACCOUNT_EMAIL}" --quiet

        # configure project
        PROJECT_ID="INSTRUQT_GCP_PROJECT_${PROJECTS[0]}_PROJECT_ID"
        gcloud config set project "${!PROJECT_ID}" --quiet

        # create the boostrap folder if it doesn't exist.
        if [ ! -d "$BASEDIR" ]; then
          mkdir -p "$BASEDIR"
        fi

        echo "GCP setup complete"
        touch ${BASEDIR}/gcp-bootstrap-completed
    fi
}

aws_init() {
    if [[ -n ${INSTRUQT_AWS_ACCOUNTS} ]]; then
        IFS=',' read -r -a PROJECTS <<< "$INSTRUQT_AWS_ACCOUNTS"

        # load all credentials into aws configure
        for PROJECT in "${PROJECTS[@]}"; do
            aws configure --profile "$PROJECT"  set region eu-west-1
            [[ "$PROJECT" == "${PROJECTS[0]}" ]] && aws configure --profile default set region eu-west-1
            VAR="INSTRUQT_AWS_ACCOUNT_${PROJECT}_AWS_ACCESS_KEY_ID"
            aws configure --profile "$PROJECT"  set aws_access_key_id "${!VAR}"
            [[ "$PROJECT" == "${PROJECTS[0]}" ]] && aws configure --profile default set aws_access_key_id "${!VAR}"
            VAR="INSTRUQT_AWS_ACCOUNT_${PROJECT}_AWS_SECRET_ACCESS_KEY"
            aws configure --profile "$PROJECT"  set aws_secret_access_key "${!VAR}"
            [[ "$PROJECT" == "${PROJECTS[0]}" ]] && aws configure --profile default set aws_secret_access_key "${!VAR}"
            VAR="INSTRUQT_AWS_ACCOUNT_${PROJECT}_USERNAME"
            USERNAME="${!VAR}"
        done

        # create the boostrap folder if it doesn't exist.
        if [ ! -d "$BASEDIR" ]; then
          mkdir -p "$BASEDIR"
        fi

        echo "AWS setup complete"
        touch ${BASEDIR}/aws-bootstrap-completed
    fi
}

azure_init() {
    if [[ -n $INSTRUQT_AZURE_SUBSCRIPTIONS ]]; then
        IFS=',' read -r -a SUBSCRIPTIONS <<< "$INSTRUQT_AZURE_SUBSCRIPTIONS"

        source /etc/bash_completion.d/azure-cli
        USERNAME="INSTRUQT_AZURE_SUBSCRIPTION_${SUBSCRIPTIONS[0]}_USERNAME"
        PASSWORD="INSTRUQT_AZURE_SUBSCRIPTION_${SUBSCRIPTIONS[0]}_PASSWORD"
        az login --username="${!USERNAME}" --password="${!PASSWORD}"

        mkdir -p "$HOME/.azure"
        cat <<EOF > "$HOME/.azure/credentials"
[$ARM_SUBSCRIPTION_ID]
client_id=$ARM_CLIENT_ID
secret=$ARM_CLIENT_SECRET
tenant=$ARM_TENANT_ID
EOF

        # create the boostrap folder if it doesn't exist.
        if [ ! -d "$BASEDIR" ]; then
          mkdir -p "$BASEDIR"
        fi

        echo "Azure setup complete"
        touch ${BASEDIR}/azure-bootstrap-completed
    fi
}

aws_init
gcloud_init
azure_init

gomplate -f /opt/instruqt/index.html.tmpl -o /var/www/html/index.html
nginx -g "daemon off;"
