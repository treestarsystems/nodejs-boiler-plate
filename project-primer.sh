#!/bin/bash

projectName=''
projectDir=''
systemId=''
baseDir=''
appProdPort=''
appDevPort=''

function genrandom {
 date +%s | sha256sum | base64 | head -c $1 ; echo
}

function do_system_dependencies {
 echo "Installing system dependencies"
 apt update
 apt -y upgrade
 apt install -y nodejs nmap whois rsync screen git build-essential npm nano
 npm install pm2 -g
}

function do_generate_pm2 {
 #Generate PM2 conf
 echo "
  module.exports = {
   apps : [{
     name        : \"$projectDir\",
     script      : \"server/index.js\",
     watch       : true,
     cwd         : \"$baseDir/$projectDir\",
     instances   : \"max\",
     exec_mode   : \"cluster\",
     watch       : [\"./server\",\"./system_confs\"],
     ignore_watch        : [\"./log_storage\",\"./db_storage\"],
     out_file    : \"./log_storage/"$projectDir"_out.log\",
     error_file  : \"./log_storage/"$projectDir"_err.log\",
     pid_file    : \"./log_storage/pid/"$projectDir"_id.pid\",
     log_date_format     : \"YYYY-MM-DD HH:mm Z\",
     kill_timeout : 60000,
     env: {
       \"NODE_ENV\": \"prod\",
       \"PORT\": \"$appProdPort\",
       \"HOST\": \"0.0.0.0\"
     },
     env_dev : {
       \"NODE_ENV\": \"dev\",
       \"PORT\": \"$appDevPort\",
       \"HOST\": \"0.0.0.0\"
     }
   }]
  }" # > system_confs/ecosystem.config.js
}

function do_generate_system_vars {
 #Generate system_vars.json file
 echo "
  {
   "username":"root",
   "homedir":\"$baseDir/$projectDir\",
   "shell":"/bin/bash",
   "systemId": "$systemId"
  }" #> system_confs/system_vars.json
}

function do_generate_mongod_conf {
 #Generate mongod.conf file
 echo "
  storage:
    dbPath: $baseDir/$projectDir/db_storage
    journal:
      enabled: true
    engine: \"wiredTiger\"
  systemLog:
    destination: file
    logAppend: true
    logRotate: rename
    timeStampFormat: \"ctime\"
    path: $baseDir/$projectDir/log_storage/$projectName_Mongod.log
  net:
    port: $mongoPort
    bindIp: 127.0.0.1,::1
    ipv6: true
    tls:
      mode: "requireTLS"
      certificateKeyFile: $baseDir/$projectDir/system_confs/certs/$projectName_Cert.pem
    compression:
      compressors: zstd,snappy
  processManagement:
    fork: true
    pidFilePath: $baseDir/$projectDir/log_storage/pid/$projectDir"_Mongod.pid"
    timeZoneInfo: /usr/share/zoneinfo
  setParameter:
    enableLocalhostAuthBypass: false
 " #> system_confs/mongod.conf
}

#Just to test small bits of code at a time.
function do_prompts_test {

}

#For testing purposes
do_prompts_test

function do_prompts {
 #Prompt for projectName
 read -e -p "Enter Project Name (Valid Chars: Letter,Numbers,-,_): " projectName
 #Validate the input and keep asking until it is correct.
 #Source: https://stackoverflow.com/a/49832505
 while [[ $projectName == "" ]] || [[ $projectName == "." ]] || [[ $projectName == ".." ]] || [ $(echo "${#projectName}") -gt 255 ] || [[ ! $projectName =~ ^[0-9a-zA-Z._-]+$ ]] || [[ ! $(echo $projectName | cut -c1-1) =~ ^[0-9a-zA-Z.]+$ ]]
 do
  read -e -p "Enter a valid Project Name (Valid Chars: Letter,Numbers,-,_): " projectName
 done


 #UnTested code blocks

 #Prompt for installation directory
 read -e -p "Please enter the full destination path (Ex: /opt): " baseDir
 #Validate the input and keep asking until it is correct.
 while [[ ! -d $baseDir ]]
 do
  read -e -p "Please enter a valid directory (Ex: /opt): " baseDir
 done
}
