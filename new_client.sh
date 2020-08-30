#!/bin/bash
current_dir=${PWD}
new_client () {
  # Generates the custom client.ovpn
  {
  cat /etc/openvpn/server/client-common.txt
  echo "<ca>"
  cat /etc/openvpn/server/easy-rsa/pki/ca.crt
  echo "</ca>"
  echo "<cert>"
  sed -ne '/BEGIN CERTIFICATE/,$ p' /etc/openvpn/server/easy-rsa/pki/issued/"$client".crt
  echo "</cert>"
  echo "<key>"
  cat /etc/openvpn/server/easy-rsa/pki/private/"$client".key
  echo "</key>"
  echo "<tls-crypt>"
  sed -ne '/BEGIN OpenVPN Static key/,$ p' /etc/openvpn/server/tc.key
  echo "</tls-crypt>"
  } > "${current_dir}/${client}.ovpn"
}

telegram_load_config () {
  if [[ ! -e "$(dirname "$(readlink -f "$0")")/.telegramconfig" ]];
  then
    echo telegram config does not exists
    {
    echo "export TelegramToken=''"
    echo "export TelegramChatID=''"
    echo ""
    } > "$(dirname "$(readlink -f "$0")")/.telegramconfig"
    exit 1
  fi
  TelegramToken=''
  TelegramChatID=''
  source "$(dirname "$(readlink -f "$0")")/.telegramconfig"
  if [[ -z "${TelegramToken}" || -z "${TelegramChatID}" ]]
  then
    echo "Not all parameters in $(dirname "$(readlink -f "$0")")/.telegramconfig are filled"
    exit 1
  fi
  export TelegramAPIURL="https://api.telegram.org/bot$TelegramToken/sendDocument"
}

telegram_send_file () {
  curl -F chat_id="${TelegramChatID}" -F document=@"$1" "${TelegramAPIURL}"
}

telegram_load_config

if [[ -z "${1}" ]]
then
  echo "Client name is not set"
  exit 1
fi

unsanitized_client="${1}"
client="${unsanitized_client/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_}"

if [[ -e /etc/openvpn/server/easy-rsa/pki/issued/"$client".crt ]]
then
  echo "Client already exists"
  exit 1
fi

cd /etc/openvpn/server/easy-rsa/ || exit
EASYRSA_CERT_EXPIRE=3650 ./easyrsa build-client-full "$client" nopass

new_client

telegram_send_file "${current_dir}/${client}.ovpn"
