#!/usr/bin/env bash

# Copyright 2024 Versity Software
# This file is licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

source ./tests/commands/command.sh

# shellcheck disable=SC2153,SC2034
aws_access_key_id="$AWS_ACCESS_KEY_ID"
# shellcheck disable=SC2153,SC2034
aws_secret_access_key="$AWS_SECRET_ACCESS_KEY"

if [ -z "$AWS_ENDPOINT_URL" ]; then
  host="localhost:7070"
else
  # shellcheck disable=SC2034
  host="$(echo "$AWS_ENDPOINT_URL" | awk -F'//' '{print $2}')"
fi

if [ -z "$AWS_REGION" ]; then
  aws_region="us-east-1"
else
  # shellcheck disable=SC2034
  aws_region="$AWS_REGION"
fi

add_command_recording_if_enabled() {
  if [ -n "$COMMAND_LOG" ]; then
    curl_command+=(send_command)
  fi
}

create_canonical_hash_sts_and_signature() {
  # shellcheck disable=SC2154
  canonical_request_hash="$(echo -n "$canonical_request" | openssl dgst -sha256 | awk '{print $2}')"

  # shellcheck disable=SC2154
  year_month_day="$(echo "$current_date_time" | cut -c1-8)"

  sts_data="AWS4-HMAC-SHA256
$current_date_time
$year_month_day/$aws_region/s3/aws4_request
$canonical_request_hash"

  date_key=$(echo -n "$year_month_day" | openssl dgst -sha256 -mac HMAC -macopt key:"AWS4${aws_secret_access_key}" | awk '{print $2}')
  date_region_key=$(echo -n "$aws_region" | openssl dgst -sha256 -mac HMAC -macopt hexkey:"$date_key" | awk '{print $2}')
  date_region_service_key=$(echo -n "s3" | openssl dgst -sha256 -mac HMAC -macopt hexkey:"$date_region_key" | awk '{print $2}')
  signing_key=$(echo -n "aws4_request" | openssl dgst -sha256 -mac HMAC -macopt hexkey:"$date_region_service_key" | awk '{print $2}')
  # shellcheck disable=SC2034
  signature=$(echo -n "$sts_data" | openssl dgst -sha256 \
                   -mac HMAC \
                   -macopt hexkey:"$signing_key" | awk '{print $2}')

  curl_command=()
  add_command_recording_if_enabled
}
