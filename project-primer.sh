#!/bin/bash

projectName=''
systemId=''
baseDir=''
appProdPort=''
appDevPort=''
mongoPort=''

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
     name        : \"$projectName\",
     script      : \"server/index.js\",
     watch       : true,
     cwd         : \"$baseDir/$projectName\",
     instances   : \"max\",
     exec_mode   : \"cluster\",
     watch       : [\"./server\",\"./system_confs\"],
     ignore_watch        : [\"./log_storage\",\"./db_storage\"],
     out_file    : \"./log_storage/"$projectName"_out.log\",
     error_file  : \"./log_storage/"$projectName"_err.log\",
     pid_file    : \"./log_storage/pid/"$projectName"_id.pid\",
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
   "homedir":\"$baseDir/$projectName\",
   "shell":"/bin/bash",
   "systemId": "$systemId"
  }" #> system_confs/system_vars.json
}

function do_generate_mongod_conf {
 #Generate mongod.conf file
 echo "
  storage:
    dbPath: $baseDir/$projectName/db_storage
    journal:
      enabled: true
    engine: \"wiredTiger\"
  systemLog:
    destination: file
    logAppend: true
    logRotate: rename
    timeStampFormat: \"ctime\"
    path: $baseDir/$projectName/log_storage/$projectName"_Mongod.log"
  net:
    port: $mongoPort
    bindIp: 127.0.0.1,::1
    ipv6: true
    tls:
      mode: "requireTLS"
      certificateKeyFile: $baseDir/$projectName/system_confs/certs/$projectName"_Cert.pem"
    compression:
      compressors: zstd,snappy
  processManagement:
    fork: true
    pidFilePath: $baseDir/$projectName/log_storage/pid/$projectName"_Mongod.pid"
    timeZoneInfo: /usr/share/zoneinfo
  setParameter:
    enableLocalhostAuthBypass: false
 " #> system_confs/mongod.conf
}

#Just to test small bits of code at a time.
function do_prompts_test {
 #Prompt for appPort
 read -e -p "Enter The Application's Production Port Number (Valid Chars: Numbers): " appProdPort
 #Validate the input and keep asking until it is correct.
 #Source: https://stackoverflow.com/a/49832505
 while [[ $appProdPort == "" ]] || [ $appProdPort -ge 65536 ] || [[ ! $appProdPort =~ ^[0-9]+$ ]]
 do
  read -e -p "Enter A Valid Port Number (Valid Chars: Numbers): " appProdPort
 done
 #Prompt for appDevPort
 read -e -p "Enter The Application's Development Port Number (Valid Chars: Numbers): " appDevPort
 #Validate the input and keep asking until it is correct.
 #Source: https://stackoverflow.com/a/49832505
 while [[ $appDevPort == "" ]] || [ $appDevPort -ge 65536 ] || [[ ! $appDevPort =~ ^[0-9]+$ ]] || [[ ! $appDevPort -ne $appProdPort ]]
 do
  read -e -p "Enter A Valid & Unused Port Number (Valid Chars: Numbers): " appDevPort
 done
}

#For testing purposes
#do_prompts_test

function do_prompts {
 #Prompt for projectName
 read -e -p "Enter Project Name (Valid Chars: Letter,Numbers,-,_): " projectName
 #Validate the input and keep asking until it is correct.
 #Source: https://stackoverflow.com/a/49832505
 while [[ $projectName == "" ]] || [[ $projectName == "." ]] || [[ $projectName == ".." ]] || [ $(echo "${#projectName}") -gt 255 ] || [[ ! $projectName =~ ^[0-9a-zA-Z._-]+$ ]] || [[ ! $(echo $projectName | cut -c1-1) =~ ^[0-9a-zA-Z.]+$ ]]
 do
  read -e -p "Enter A Valid Project Name (Valid Chars: Letter,Numbers,-,_): " projectName
 done

 #Prompt for systemId
 read -e -p "Enter A System ID (Valid Chars: Letter,Numbers,-,_): " systemId
 #Validate the input and keep asking until it is correct.
 #Source: https://stackoverflow.com/a/49832505
 while [[ $systemId == "" ]] || [[ $systemId == "." ]] || [[ $systemId == ".." ]] || [ $(echo "${#systemId}") -gt 255 ] || [[ ! $systemId =~ ^[0-9a-zA-Z._-]+$ ]] || [[ ! $(echo $systemId | cut -c1-1) =~ ^[0-9a-zA-Z.]+$ ]]
 do
  read -e -p "Enter A Valid System ID (Valid Chars: Letter,Numbers,-,_): " systemId
 done

 #Prompt for appProdPort
 read -e -p "Enter The Application's Production Port Number (Valid Chars: Numbers): " appProdPort
 #Validate the input and keep asking until it is correct.
 #Source: https://stackoverflow.com/a/49832505
 while [[ $appProdPort == "" ]] || [ $appProdPort -ge 65536 ] || [[ ! $appProdPort =~ ^[0-9]+$ ]]
 do
  read -e -p "Enter A Valid Port & Unused Number (Valid Chars: Numbers): " appProdPort
 done

 #Prompt for appDevPort
 read -e -p "Enter The Application's Development Port Number (Valid Chars: Numbers): " appDevPort
 #Validate the input and keep asking until it is correct.
 #Source: https://stackoverflow.com/a/49832505
 while [[ $appDevPort == "" ]] || [ $appDevPort -ge 65536 ] || [[ ! $appDevPort =~ ^[0-9]+$ ]] || [[ ! $appDevPort -ne $appProdPort ]]
 do
  read -e -p "Enter A Valid & Unused Port Number (Valid Chars: Numbers): " appDevPort
 done

 #Prompt for mongoPort
 read -e -p "Enter The Application's MongoDB Port Number (Valid Chars: Numbers): " mongoPort
 #Validate the input and keep asking until it is correct.
 #Source: https://stackoverflow.com/a/49832505
 while [[ $mongoPort == "" ]] || [ $mongoPort -ge 65536 ] || [[ ! $mongoPort =~ ^[0-9]+$ ]] || [[ ! $mongoPort -ne $appProdPort ]] || [[ ! $mongoPort -ne $appDevPort ]]
 do
  read -e -p "Enter A Valid & Unused Port Number (Valid Chars: Numbers): " mongoPort
 done

 #Prompt for installation's base directory
 read -e -p "Enter The Base Installation Directory (Ex: /opt|Default: /opt): " baseDir
 #Default variable if blank
 if [ $baseDir == ""]
 then
  baseDir='/opt'
 fi
 #Validate the input and keep asking until it is correct.
 while [[ ! -d $baseDir ]]
 do
  read -e -p "Enter A Valid Directory (Ex: /opt): " baseDir
  #Default variable if blank
  if [ $baseDir == ""]
  then
   baseDir='/opt'
  fi
 done

 #UnTested code blocks
 #Prompt for installation directory
# read -e -p ": " Dir
 #Validate the input and keep asking until it is correct.
# while [[ !  $ ]]
# do
#  read -e -p ": " Dir
# done

 do_generate_pm2
 do_generate_system_vars
 do_generate_mongod_conf
}

do_prompts
