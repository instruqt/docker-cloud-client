#!/bin/bash

set -euxo pipefail

# Available env vars:

# INSTRUQT_SYSDIG_ACCOUNT
# INSTRUQT_SYSDIG_ACCOUNT_REGION_URL
# INSTRUQT_SYSDIG_ACCOUNT_USERNAME
# INSTRUQT_SYSDIG_ACCOUNT_PASSWORD
# INSTRUQT_SYSDIG_ACCOUNT_SYSDIG_SECURE_API_TOKEN
# INSTRUQT_SYSDIG_ACCOUNT_SYSDIG_MONITOR_API_TOKEN

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

azure_init() {
    if [[ -n $INSTRUQT_AZURE_SUBSCRIPTIONS ]]; then
        SUBSCRIPTIONS=("${INSTRUQT_AZURE_SUBSCRIPTIONS//,/ }")

        source /etc/bash_completion.d/azure-cli
        USERNAME="INSTRUQT_AZURE_SUBSCRIPTION_${SUBSCRIPTIONS[0]}_USERNAME"
        PASSWORD="INSTRUQT_AZURE_SUBSCRIPTION_${SUBSCRIPTIONS[0]}_PASSWORD"
        az login --username="${!USERNAME}" --password="${!PASSWORD}"

        mkdir -p "$HOME/.azure/credentials"
        cat <<EOF > "$HOME/.azure/credentials"
[$ARM_SUBSCRIPTION_ID]
client_id=$ARM_CLIENT_ID
secret=$ARM_CLIENT_SECRET
tenant=$ARM_TENANT_ID
EOF
    fi
}

function provision_monitor_user(){

    json_file="$WORK_DIR/monitor-operations-team.json"
    tmp_file="$WORK_DIR/monitor-operations-team.json.tmp"

    MONITOR_OPS_TEAM_ID=$(curl -s -k -X GET \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${ACCOUNT_PROVISIONER_SECURE_API_TOKEN}" \
        ${ACCOUNT_PROVISIONER_SECURE_API_URL}/api/teams \
        | jq -r '.[][] | select(.immutable) | select(.products[] | contains("SDC"))| .id')  

    # get monitor operations team info
    curl -s -k -X GET \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${ACCOUNT_PROVISIONER_SECURE_API_TOKEN}" \
        ${ACCOUNT_PROVISIONER_SECURE_API_URL}/api/teams/${MONITOR_OPS_TEAM_ID} \
        | jq > "$json_file"

    # edits
    #   remove team, get all other info
    jq '.team' "$json_file" > "$tmp_file"
    cp "$tmp_file" "$json_file"; rm "$tmp_file"

    # remove all users that are role ROLE_TEAM_MANAGER
    jq '.userRoles[] |= del(. | select(.role == "ROLE_TEAM_MANAGER"))' "$json_file" > "$tmp_file"
    cp "$tmp_file" "$json_file"; rm "$tmp_file"

    # clean nulls in .userRoles[]
    # del(.[][] | nulls)
    jq '.userRoles |= del(.[] | nulls)' "$json_file" > "$tmp_file"
    cp "$tmp_file" "$json_file"; rm "$tmp_file"

    # remove fields
    fields=("properties" "customerId" "dateCreated" "lastUpdated" "userCount")
    for field in "${fields[@]}"; do
        jq ". |= del(.$field)" "$json_file" > "$tmp_file"
        cp "$tmp_file" "$json_file"
    done
    rm "$tmp_file"

    # add fields   "searchFilter" "filter"
    jq --argjson var null '. + {searchFilter: $var}' "$json_file" > "$tmp_file"
    cp "$tmp_file" "$json_file"; rm "$tmp_file"

    jq --argjson var null '. + {filter: $var}' "$json_file" > "$tmp_file"
    cp "$tmp_file" "$json_file"; rm "$tmp_file"

    # add new user to group
    # this is not working:
    #    we should remove existing users (account managers) and push only the new ones. 
    # the get is returning account_managers
    jq '.userRoles[.userRoles| length] |= . + {
            "teamId": '${MONITOR_OPS_TEAM_ID}',
            "teamName": "Monitor Operations",
            "teamTheme": "#7BB0B2",
            "userId": '${SPA_USER_ID}',
            "userName": "'${SPA_USER}'",
            "role": "ROLE_TEAM_STANDARD"
        }' "$json_file" > "$tmp_file"
    cp "$tmp_file" "$json_file"; rm "$tmp_file"

    # update Monitor Operations team with new user assigned
    curl -s -k -X PUT \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${ACCOUNT_PROVISIONER_MONITOR_API_TOKEN}" \
        -d @$json_file \
        ${ACCOUNT_PROVISIONER_MONITOR_API_URL}/api/teams/${MONITOR_OPS_TEAM_ID} \
        | jq > /dev/null

}

function provision_secure_user(){

    curl -s -k -X POST \
        -D headers.txt \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${ACCOUNT_PROVISIONER_SECURE_API_TOKEN}" \
        --data-binary '{
"username": "'${SPA_USER}'",
"password": "'${SPA_PASS}'",
"firstName": "Training",
"lastName": "Student",
"systemRole": "ROLE_USER"
}' \
        ${ACCOUNT_PROVISIONER_SECURE_API_URL}/api/user/provisioning/ \
        | jq > $WORK_DIR/account.json

    if [ TODO ] # creation succeded
    then
        touch $WORK_DIR/user_provisioned_COMPLETED

        SPA_USER_ID=$(cat  $WORK_DIR/account.json | jq .user.id)
        SPA_USER_API_TOKEN=$(cat  $WORK_DIR/account.json | jq -r  .token.key)

        curl -s -k -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${SPA_USER_API_TOKEN}" \
            --data-binary '[
  {
    "id": "additionalEnvironments",
    "displayQuestion": "What are all the environments your company has?",
    "choices": []
  },
  {
    "id": "iacManifests",
    "displayQuestion": "Where do you store your Infrastructure as Code manifests?",
    "choices": []
  },
  {
    "id": "cicdTool",
    "displayQuestion": "What are your CI/CD tools?",
    "choices": []
  },
  {
    "id": "notificationChannels",
    "displayQuestion": "How do you want to be notified outside of Sysdig?",
    "choices": []
  }
]' ${ACCOUNT_PROVISIONER_SECURE_API_URL}/api/secure/onboarding/v2/userProfile/questionnaire \
            | jq > /dev/null

    else
        echo "provision_secure_user: failed"
        exit 1
    fi

}

function generate_random_id () {

    if [ ! -f $WORK_DIR/random_string_OK ] # random_id not set
    then

        mapfile nouns < /opt/sysdig/lab_random_string_id_nouns
        mapfile adjectives < /opt/sysdig/lab_random_string_id_adjectives

        nounIndex=$RANDOM%$((${#nouns[@]}-1))
        adjectiveIndex=$RANDOM%$((${#adjectives[@]}-1))

        adjective="$(echo -e "${adjectives[$adjectiveIndex]}" | tr -d '[:space:]')"
        noun="$(echo -e "${nouns[$nounIndex]}" | tr -d '[:space:]')"
        salt="$(shuf -i 1-99999 -n 1)"
        random_id="$adjective"_"$noun"_"$salt"

        echo "${random_id}_student@sysdigtraining.com" > $WORK_DIR/ACCOUNT_PROVISIONED_USER
        #create flag
        echo "$random_id" > $WORK_DIR/random_string_OK
        agent variable set RANDOM_ID ${random_id}

    fi
        echo "Random user string from dictionary: $random_id"
        
    # generate random password
    # set user/pass 
    SPA_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 9 ; echo '')
    echo "${SPA_PASS}" > $WORK_DIR/ACCOUNT_PROVISIONED_PASS
    agent variable set SPA_PASS ${SPA_PASS}
    SPA_USER=$(cat $WORK_DIR/ACCOUNT_PROVISIONED_USER)
    agent variable set SPA_USER ${SPA_USER}
    agent variable set SPA_SECURE_API_TOKEN ${ACCOUNT_PROVISIONER_SECURE_API_TOKEN}

}

function sysdig_init() {
    if [[ -n $INSTRUQT_SYSDIG_ACCOUNT ]]; then
        # INPUTs
        # TODO, this might not work for those regions
        # where no equivalence between Monitor & Secure exists
        # testing
INSTRUQT_SECRET_ACCOUNT_PROVISIONER_AGENT_ACCESS_KEY=9f1c06cf-f7ee-45b8-943f-73740472e978
INSTRUQT_SECRET_ACCOUNT_PROVISIONER_MONITOR_API_TOKEN=970a55f3-889e-4c80-9f73-3dba104ccb53
INSTRUQT_SECRET_ACCOUNT_PROVISIONER_SECURE_API_TOKEN=cce028ab-d10b-48e2-92d6-389317d9d92e
INSTRUQT_SECRET_ACCOUNT_PROVISIONER_API_URL=https://us2.app.sysdig.com
INSTRUQT_SECRET_ACCOUNT_PROVISIONER_REGION=2

        if [[ -z $INSTRUQT_SECRET_ACCOUNT_PROVISIONER_AGENT_ACCESS_KEY \
            || -z $INSTRUQT_SECRET_ACCOUNT_PROVISIONER_MONITOR_API_TOKEN \
            || -z $INSTRUQT_SECRET_ACCOUNT_PROVISIONER_SECURE_API_TOKEN \
            || -z $INSTRUQT_SECRET_ACCOUNT_PROVISIONER_API_URL \
            || -z $INSTRUQT_SECRET_ACCOUNT_PROVISIONER_REGION \
        ]]; then
            echo 'One or more required variables to provision for this lab are undefined'
            exit 1
        else
            ACCOUNT_PROVISIONER_MONITOR_API_TOKEN=$INSTRUQT_SECRET_ACCOUNT_PROVISIONER_MONITOR_API_TOKEN
            ACCOUNT_PROVISIONER_MONITOR_API_URL=$INSTRUQT_SECRET_ACCOUNT_PROVISIONER_API_URL
            ACCOUNT_PROVISIONER_SECURE_API_TOKEN=$INSTRUQT_SECRET_ACCOUNT_PROVISIONER_SECURE_API_TOKEN
            ACCOUNT_PROVISIONER_SECURE_API_URL=$INSTRUQT_SECRET_ACCOUNT_PROVISIONER_API_URL
            ACCOUNT_PROVISIONER_AGENT_ACCESS_KEY=$INSTRUQT_SECRET_ACCOUNT_PROVISIONER_AGENT_ACCESS_KEY
            ACCOUNT_PROVISIONER_REGION_NUMBER=$INSTRUQT_SECRET_ACCOUNT_PROVISIONER_REGION_NUMBER
        fi

        WORK_DIR=/opt/sysdig
        WORK_DIR=/tmp/sysdig
        TRACK_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P )
        mkdir -p $WORK_DIR
        mkdir -p $TRACK_DIR

        # provision user
        generate_random_id
        provision_secure_user
        provision_monitor_user

        #set values to present to student in the UI -> OUT
        INSTRUQT_SYSDIG_ACCOUNT_USERNAME=${SPA_USER}
        INSTRUQT_SYSDIG_ACCOUNT_PASSWORD=${SPA_PASS}
        INSTRUQT_SYSDIG_ACCOUNT_REGION_URL=${ACCOUNT_PROVISIONER_SECURE_API_URL}/
        INSTRUQT_SYSDIG_ACCOUNT_SECURE_API_TOKEN=${SPA_USER_API_TOKEN}
        INSTRUQT_SYSDIG_ACCOUNT_MONITOR_API_TOKEN=${SPA_USER}
    fi
}

sysdig_init
aws_init
gcloud_init &
azure_init &

gomplate -f /opt/instruqt/index.html.tmpl -o /var/www/html/index.html
nginx -g "daemon off;"
