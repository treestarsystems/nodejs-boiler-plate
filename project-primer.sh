#!/bin/bash

projectName=''
systemId=''
baseDir=''
appProdPort=''
appDevPort=''
mongoPort=''
projectDescription=''
regExValidHostname='(?=^.{1,253}$)(^(((?!-)[a-zA-Z0-9-]{1,63}(?<!-))|((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63})$)'

#Pass the desired length of the random string as a number. Ex: genrandom 5
function genrandom {
 date +%s | sha256sum | base64 | head -c $1 ; echo
}

function do_system_dependencies {
 echo "Installing system dependencies...\n"
 sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key C99B11DEB97541F0
 sudo apt-add-repository https://cli.github.com/packages
 sudo apt update
 sudo apt -y upgrade
 sudo apt install -y nodejs nmap whois rsync screen git build-essential npm nano gh
 npm install pm2 -g
}

function do_generate_pm2 {
 echo "Generating PM2 conf...\n"
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
  }" # > $baseDir/$projectName/system_confs/ecosystem.config.js
}

function do_generate_system_vars {
 echo "Generating system_vars.json file...\n"
 echo "
  {
   "username":"root",
   "homedir":\"$baseDir/$projectName\",
   "shell":"/bin/bash",
   "systemId": "$systemId"
  }" #> $baseDir/$projectName/system_confs/system_vars.json
}

function do_generate_mongod_conf {
 echo "Generating mongod.conf file...\n"
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
 " #> $baseDir/$projectName/system_confs/mongod.conf
}

function do_generate_readme {
 #Generate README
 echo "
  # $projectName
  $projectDescription
 " #> $baseDir/$projectName/README.md
}

function do_generate_package_json {
 #Generate package.json
 echo "
  {
   \"name\": \"$projectName\",
   \"version\": \"1.0.0\",
   \"description\": \"$projectDescription\",
   \"main\": \"index.js\",
   \"scripts\": {
    \"start\": \"pm2 start system_confs/ecosystem.config.js --env prod\",
    \"dev\": \"pm2 start system_confs/ecosystem.config.js --env dev\",
    \"stop-instance\": \"server/service.js -k\",
    \"status-instance\": \"pm2 status\",
    \"delete-instance\": \"server/service.js -d\",
    \"restart-instance\": \"server/service.js -r\",
    \"log-instance\": \"pm2 log\"
   },
   \"repository\": {
     \"type\": \"git\",
     \"url\": \"git+https://github.com/treestarsystems/$projectName.git\"
   },
   \"author\": \"Tree Star Systems\",
   \"license\": \"MIT\",
   \"private\": true,
   \"bugs\": {
     \"url\": \"https://github.com/treestarsystems/$projectName/issues\"
   },
   \"homepage\": \"https://treestarsystems.com/\",
   \"dependencies\": {
    \"axios\": \"^0.21.1\",
    \"bcryptjs\": \"^2.4.3\",
    \"body-parser\": \"^1.19.0\",
    \"compression\": \"1.7.4\",
    \"connect-mongo\": \"^3.2.0\",
    \"cors\": \"^2.8.5\",
    \"cron\": \"^1.8.2\",
    \"express\": \"^4.17.0\",
    \"express-handlebars\": \"^3.1.0\",
    \"express-session\": \"^1.17.1\",
    \"joi\": \"^17.3.0\",
    \"lodash\": \"^4.17.20\",
    \"minimist\": \"^1.2.5\",
    \"mongoose\": \"^5.11.11\",
    \"node-emoji\": \"^1.10.0\",
    \"nodemailer\": \"^6.4.17\"
   }
  }
 " #> $baseDir/$projectName/package.json
}

function do_generate_nginx_conf {
 echo "Generating NGINX Configuration..."
# modifiedSystemId = $()
 echo "
  #HTTP to HTTPS Redirect
  server {
      listen 80;
      listen [::]:80;
      server_name $systemId;
      if (\$host = $systemId) {
          return 301 https://\$host\$request_uri;
      }
      if (\$host = $systemId) {
          return 301 https://\$host\$request_uri;
      }
  }

  #Host/Vhost/Alias conf
  server {
       listen 443 ssl;
       listen [::]:443 ssl;
       # ssl_certificate     /etc/letsencrypt/live/$systemId/fullchain.pem;
       # ssl_certificate_key /etc/letsencrypt/live/$systemId/privkey.pem;
       server_name $systemId;

       proxy_set_header Host \$host;
       proxy_set_header X-Forwarded-Proto \$scheme;
       proxy_set_header X-Real-IP \$remote_addr;
       proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

       location / {
               proxy_pass http://127.0.0.1:$appProdPort/;
               proxy_http_version 1.1;
               proxy_set_header Upgrade \$http_upgrade;
               proxy_set_header Connection 'upgrade';
               proxy_set_header Host \$host;
               proxy_cache_bypass \$http_upgrade;
       }

       location /public/ {
               root /opt/$projectName/server/view;
               access_log off;
               expires max;
       }
  }
 " #> /etc/nginx/sites-enabled/default-test
}

function do_generate_core_js {
 echo "Generating core.js file...\n"
 #Uncomment for deployment
# sed -i -e "s/INSERTIONPOINT/\"projectName\": \"$projectName\",\\n \"dbServer\": \"mongodb\:\/\/localhost\:$mongoPort\/\?tls\=true\&tlsAllowInvalidCertificates\=true\",\\n \"dbName\": \"$projectName\"/g" ./static_files/core.js
 #Erase line for deployment
 sed "s/INSERTIONPOINT/\"projectName\": \"$projectName\",\\n \"dbServer\": \"mongodb\:\/\/localhost\:$mongoPort\/\?tls\=true\&tlsAllowInvalidCertificates\=true\",\\n \"dbName\": \"$projectName\"/g" ./static_files/core.js
} #>

function do_git {
 #Run authentication procedure. Check if already done some how? Maybe allow user to skip
# gh auth login --with-token < filename
 #Prompt for authToken
 read -e -p "Please enter your GitHub Auth Token? (Press Enter to Skip): " authToken
 if [ ! -z "$authToken" ]
 then
  randomString=$(genrandom 5)
  echo "$authToken" > /tmp/authtoken-$randomString
  gh auth login --with-token < /tmp/authtoken-$randomString
  ghAuthLoginExitCode=$(echo "$?")
  if  [ ! $ghAuthLoginExitCode == 0 ]
  then
   echo -e "\nIncorrect entry or service not available. Please check: \nhttps://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token\n"
  fi
 fi
 #Source: https://stackoverflow.com/a/49832505
# while [[ $projectName == "" ]] || [[ $projectName == "." ]] || [[ $projectName == ".." ]] || [ $(echo "${#projectName}") -gt 255 ] || [[ ! $projectName =~ ^[0-9a-zA-Z._-]+$ ]] || [[ ! $(echo $projectName | cut -c1-1) =~ ^[0-9a-zA-Z.]+$ ]]
# do
#  read -e -p "Enter A Valid Project Name (Valid Chars: Letter,Numbers,-,_): " projectName
# done

 #>
}

do_git
#function do_generate_ {

 #>
#}

#Just to test small bits of code at a time.
#function do_prompts_test {
 #Prompt for systemId
#}

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

 #Prompt for projectDescription
 read -e -p "Enter Project Description: " projectDescription

 #Prompt for systemId
 read -e -p "Enter A System ID (Valid Chars: Letter,Numbers,-,_): " systemId
 #Validate the input and keep asking until it is correct.
 #Source: https://stackoverflow.com/a/49832505
 while [[ ! $(echo $systemId | grep -P $regExValidHostname) == $systemId ]]
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

# do_generate_pm2
# do_generate_system_vars
# do_generate_mongod_conf
# do_generate_readme
# do_generate_package_json
# do_generate_core_js
 do_generate_nginx_conf
}

#do_prompts

