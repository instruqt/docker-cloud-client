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

gcloud_init() {
    if [ -n "${INSTRUQT_GCP_PROJECTS}" ]; then
        PROJECTS=("${INSTRUQT_GCP_PROJECTS//,/ }")

        # load all credentials into gcloud
        for PROJECT in ${PROJECTS[@]}; do
            TMP_FILE=$(mktemp)
            SERVICE_ACCOUNT_KEY="INSTRUQT_GCP_PROJECT_${PROJECT}_SERVICE_ACCOUNT_KEY"
            base64 -d <(echo ${!SERVICE_ACCOUNT_KEY}) > "$TMP_FILE"
            gcloud auth activate-service-account --key-file="$TMP_FILE"
            rm "$TMP_FILE"
        done

        # activate service account for first project
        SERVICE_ACCOUNT_EMAIL="INSTRUQT_GCP_PROJECT_${PROJECTS[0]}_SERVICE_ACCOUNT_EMAIL"
        gcloud config set account "${!SERVICE_ACCOUNT_EMAIL}"

        # configure project
        PROJECT_ID="INSTRUQT_GCP_PROJECT_${PROJECTS[0]}_PROJECT_ID"
        gcloud config set project "${!PROJECT_ID}"
    fi
}

aws_init() {
    if [[ -n ${INSTRUQT_AWS_ACCOUNTS} ]]; then
        PROJECTS=("${INSTRUQT_AWS_ACCOUNTS//,/ }")

        # load all credentials into aws configure
        for PROJECT in ${PROJECTS[@]}; do
		aws configure --profile $PROJECT  set region eu-west-1
		[[ $PROJECT == ${PROJECTS[0]} ]] && aws configure --profile default set region eu-west-1
		VAR="INSTRUQT_AWS_ACCOUNT_${PROJECT}_AWS_ACCESS_KEY_ID"
		aws configure --profile $PROJECT  set aws_access_key_id "${!VAR}"
		[[ $PROJECT == ${PROJECTS[0]} ]] && aws configure --profile default set aws_access_key_id "${!VAR}"
		VAR="INSTRUQT_AWS_ACCOUNT_${PROJECT}_AWS_SECRET_ACCESS_KEY"
		aws configure --profile $PROJECT  set aws_secret_access_key "${!VAR}"
		[[ $PROJECT == ${PROJECTS[0]} ]] && aws configure --profile default set aws_secret_access_key "${!VAR}"
		VAR="INSTRUQT_AWS_ACCOUNT_${PROJECT}_USERNAME"
		USERNAME="${!VAR}"
        done
    fi
}

aws_init
gcloud_init &

gomplate -f /opt/instruqt/index.html.tmpl -o /var/www/html/index.html
nginx -g "daemon off;"
