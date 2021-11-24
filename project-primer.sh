#!/bin/bash

systemUsername=$(whoami)
scriptDir=$(echo "$PWD")
gitHubAuthorName='Tree Star Systems'
gitHubAuthorEmail='info@treestarsystems.com'
projectName=''
systemId=''
baseDir='/opt'
appProdPort=''
appDevPort=''
mongoPort=''
projectDescription=''
regExValidHostname='(?=^.{1,253}$)(^(((?!-)[a-zA-Z0-9-]{1,63}(?<!-))|((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63})$)'
regExValidVisibility='(^|\s)\Kpublic(?=\s|$)|(^|\s)\Kprivate(?=\s|$)|(^|\s)\Kinternal(?=\s|$)'
regExValidMongoInstall='(^|\s)\Ky(?=\s|$)|(^|\s)\Kn(?=\s|$)'

#Pass the desired length of the random string as a number. Ex: genrandom 5
function genrandom {
 date +%s | sha256sum | base64 | head -c $1 ; echo
}

function do_system_dependencies {
 echo -e "Installing system dependencies..."
 sudo apt install -y software-properties-common aptitude
 sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key C99B11DEB97541F0
 sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4
 wget -qO - https://deb.nodesource.com/setup_14.x | bash -E
 sudo apt-add-repository https://cli.github.com/packages
 sudo aptitude update
 sudo aptitude -y upgrade
 sudo aptitude install -y nodejs
 sudo aptitude install -y nmap whois rsync screen build-essential nano nginx
 npm install -g pm2
}

function do_generate_pm2 {
 echo -e "Generating PM2 conf..."
 echo "
module.exports = {
 apps : [
  {
   name        : \"$projectName\",
   script      : \"server/index.js\",
   watch       : true,
   cwd         : \"$baseDir/$projectName\",
   instances   : \"1\",
   exec_mode   : \"cluster\",
   watch       : [\"./server\",\"./system_confs\"],
   ignore_watch        : [\"./log_storage\",\"./db_storage\",\"system_confs/system_conf.json\",\"server/view\"],
   out_file    : \"./log_storage/"$projectName"_out.log\",
   error_file  : \"./log_storage/"$projectName"_err.log\",
   pid_file    : \"./log_storage/pid/"$projectName"_id.pid\",
   log_date_format     : \"YYYY-MM-DD HH:mm Z\",
   kill_timeout : 60000,
   env: {
     \"INSTANCE_TYPE\": \"primary\",
     \"NODE_ENV\": \"prod\",
     \"PORT\": \"$appProdPort\",
     \"HOST\": \"0.0.0.0\"
   },
   env_dev : {
     \"INSTANCE_TYPE\": \"primary\",
     \"NODE_ENV\": \"dev\",
     \"PORT\": \"$appDevPort\",
     \"HOST\": \"0.0.0.0\"
   }
  },
  {
   name        : \"$projectName\",
   script      : \"server/index.js\",
   watch       : true,
   cwd         : \"$baseDir/$projectName\",
   instances   : \"-1\",
   exec_mode   : \"cluster\",
   watch       : [\"./server\",\"./system_confs\"],
   ignore_watch        : [\"./log_storage\",\"./db_storage\",\"system_confs/system_conf.json\",\"server/view\"],
   out_file    : \"./log_storage/"$projectName"_out.log\",
   error_file  : \"./log_storage/"$projectName"_err.log\",
   pid_file    : \"./log_storage/pid/"$projectName"_id.pid\",
   log_date_format     : \"YYYY-MM-DD HH:mm Z\",
   kill_timeout : 60000,
   env: {
     \"INSTANCE_TYPE\": \"clone\",
     \"NODE_ENV\": \"prod\",
     \"PORT\": \"$appProdPort\",
     \"HOST\": \"0.0.0.0\"
   },
   env_dev : {
     \"INSTANCE_TYPE\": \"clone\",
     \"NODE_ENV\": \"dev\",
     \"PORT\": \"$appDevPort\",
     \"HOST\": \"0.0.0.0\"
   }
  }
 ]
}" > $baseDir/$projectName/system_confs/ecosystem.config.js
}

function do_generate_system_vars {
 echo -e "Generating system_vars.json file..."
 echo "
{
 \"username\":\"$systemUsername\",
 \"homedir\":\"$baseDir/$projectName\",
 \"shell\":\"/bin/bash\",
 \"systemId\": \"$systemId\",
 \"tokenSecret\": \"$(genrandom 20)\"
}" > $baseDir/$projectName/system_confs/system_vars.json
}

function do_generate_mongod_conf {
 echo -e "Generating mongod.conf file..."
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
  timeStampFormat: \"iso8601-utc\"
  path: $baseDir/$projectName/log_storage/$projectName"_Mongod.log"
net:
  port: $mongoPort
  bindIp: 127.0.0.1,::1
  ipv6: true
  tls:
    mode: \"requireTLS\"
    certificateKeyFile: $baseDir/$projectName/system_confs/certs/$systemId".mongo.pem"
  compression:
    compressors: zstd,snappy
processManagement:
  fork: true
  pidFilePath: $baseDir/$projectName/log_storage/pid/$projectName"_Mongod.pid"
  timeZoneInfo: /usr/share/zoneinfo
setParameter:
  enableLocalhostAuthBypass: false
" > $baseDir/$projectName/system_confs/mongod.conf
}

function do_generate_readme {
 #Generate README
 echo -e "Generating README.md file..."
 echo -e "
# $projectName
Generated by [nodejs-boiler-plate](https://github.com/treestarsystems/nodejs-boiler-plate) script.  
## Description:  
$projectDescription  

## How to Run (as root): Impersonate root using sudo -i  
Run:
- Production
\`\`\`
npm start
\`\`\`

Save for startup: https://pm2.keymetrics.io/docs/usage/startup/

Once you started all the applications you want to manage using the lines above:
\`\`\`
pm2 save
pm2 startup systemd
\`\`\`

Other Process Commands:
- Development
\`\`\`
npm run dev
\`\`\`
- Stop Instance
\`\`\`
npm run stop-instance
\`\`\`
- Status of Instance
\`\`\`
npm run status-instance
\`\`\`
- JSON Output of Status of Instance
\`\`\`
npm run jsonstatus-instance
\`\`\`
- Reload Instance
\`\`\`
npm run reload-instance
\`\`\`
- Delete Instance
\`\`\`
npm run delete-instance
\`\`\`
- Show Instance Logs
\`\`\`
npm run log-instance
\`\`\`
 " > $baseDir/$projectName/README.md
}

function do_generate_package_json {
 #Generate package.json
 echo -e "Generating package.json file..."
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
  \"status-instance\": \"server/service.js -s\",
  \"jsonstatus-instance\": \"server/service.js -j\",
  \"delete-instance\": \"server/service.js -d\",
  \"reload-instance\": \"server/service.js -r\",
  \"log-instance\": \"pm2 log $projectName\"
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
  \"multer\": \"^1.4.2\",
  \"mz\": \"^2.7.0\",
  \"node-emoji\": \"^1.10.0\",
  \"nodemailer\": \"^6.4.17\"
 }
}
 " > $baseDir/$projectName/package.json
}

function do_generate_nginx_conf {
 cp $scriptDir/static_files/ssl-params.conf /etc/nginx/snippets/ssl-params.conf
 echo -e "Generating Temporary Self Signed Certificate..."
 openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout $baseDir/$projectName/system_confs/certs/$systemId.key -out $baseDir/$projectName/system_confs/certs/$systemId.pem -subj "/C=US/ST=GA/L=City/O=Tree Star Systems, LLC./OU=DEV/CN=$systemId"
 cat $baseDir/$projectName/system_confs/certs/$systemId.key > $baseDir/$projectName/system_confs/certs/$systemId.mongo.pem
 cat $baseDir/$projectName/system_confs/certs/$systemId.pem >> $baseDir/$projectName/system_confs/certs/$systemId.mongo.pem
 chmod 600 $baseDir/$projectName/system_confs/certs/$systemId.mongo.pem
 echo -e "Generating Diffie-Hellman Group. Please be patient..."
 openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
 echo -e "Generating NGINX Configuration..."
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
     ssl_certificate $baseDir/$projectName/system_confs/certs/$systemId.pem;
     ssl_certificate_key $baseDir/$projectName/system_confs/certs/$systemId.key;
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
             root $baseDir/$projectName/server/view;
             access_log off;
             expires max;
     }
     include snippets/ssl-params.conf;
}
 " > /etc/nginx/sites-enabled/default-$projectName
 nginx -t &>/dev/null
 nginxExitCode=$(echo $?)
 if [ "$nginxExitCode" == 0  ]
 then
  service nginx restart
 else
  echo -e "Issue with NGINX configuration. Please check using the \"nginx -t\" command..."
 fi
}

function do_generate_core_js {
 echo -e "Generating core.js file..."
 sed "s/INSERTIONPOINT/\"projectName\": \"$projectName\",\\n \"dbServer\": \"mongodb\:\/\/localhost\:$mongoPort\/$projectName\?tls\=true\&tlsAllowInvalidCertificates\=true\",\\n \"dbName\": \"$projectName\"/g" $scriptDir/static_files/core.js > $baseDir/$projectName/server/core/core.js
}

function do_generate_base_folders {
 echo -e "Generating base folders..."
 mkdir -p $baseDir/$projectName/{server/{core,controller/cron,view/{pages/{layouts,partials},public/{js,css,images},handlebars},model},system_confs/certs}
}

function do_static_files {
 cp $scriptDir/static_files/cronJobs.js $baseDir/$projectName/server/core/cronJobs.js
 cp $scriptDir/static_files/cron.js $baseDir/$projectName/server/controller/cron/cron.js
 cp $scriptDir/static_files/index.js $baseDir/$projectName/server/index.js
 cp $scriptDir/static_files/routes.js $baseDir/$projectName/server/controller/routes.js
 cp $scriptDir/static_files/service.js $baseDir/$projectName/server/service.js
 cp $scriptDir/static_files/app.js $baseDir/$projectName/server/app.js
 cp $scriptDir/static_files/helpers.js $baseDir/$projectName/server/view/handlebars/helpers.js
 cp $scriptDir/static_files/.gitignore $baseDir/$projectName/.gitignore
}

function do_mongo_install {
 echo "Installing MongoDB 4.4.x"
 wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
 echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
 sudo aptitude install -y mongodb-org
 do_generate_mongod_conf
}

function do_git {
 echo ""
 #MongoDB Install
 read -e -p "Would you like to install MongoDB 14.x? (y/n|Default: n): " mongoInstall
 #Default variable if blank
 if [ -z $mongoInstall ]
 then
  mongoInstall='n'
 fi
 #Validate the input and keep asking until it is correct.
 while [[ ! $(echo $mongoInstall | grep -P $regExValidMongoInstall) == $mongoInstall ]]
 do
  read -e -p "Enter A Valid Answer. (y/n|Default: n): " mongoInstall
  #Default variable if blank
  if [ -z $mongoInstall ]
  then
   mongoInstall='n'
  fi
 done

 randomString=$(genrandom 5)
 ghUsername=''
 #Run authentication procedure.
 #Prompt for username
 read -e -p "GitHub Username?: " ghUsername
 if [ ! -f "$ghUsername" ]
 then
  while [[ $ghUsername == "" ]]
  do
   read -e -p "GitHub Username?: " ghUsername
  done
 fi

 #Prompt for authToken
 echo -n "GitHub Auth Token?: "
 read -s ghToken
 if [ ! -f "$ghToken" ]
 then
  while [[ $ghToken == "" ]]
  do
   echo "GitHub Auth Token?: "
   read -s ghToken
  done
 fi
 echo " "
 #Repository visibility
 read -e -p "Repo Visibility? (public/private/internal|Default: public): " visibility
 #Default variable if blank
 if [ -z $visibility ]
 then
  visibility='public'
 fi
 #Validate the input and keep asking until it is correct.
 while [[ ! $(echo $visibility | grep -P $regExValidVisibility) == $visibility ]]
 do
  read -e -p "Enter A Valid Visibility String. (public/private/internal|Default: public): " visibility
  #Default variable if blank
  if [ $visibility == ""]
  then
   visibility='public'
  fi
 done

 cd $baseDir
 git init $projectName
 cd $baseDir/$projectName
 curl https://$ghUsername:$ghToken@api.github.com/user/repos -d "{\"name\":\"$projectName\",\"visibility\":\"$visibility\",\"description\":\"$projectDescription\"}"
 do_generate_base_folders
 if [ "$mongoInstall" == 'y' ]
 then
  do_mongo_install
 fi
 do_generate_pm2
 do_generate_system_vars
 do_generate_readme
 do_generate_package_json
 do_generate_core_js
 do_static_files
 git config user.name "$gitHubAuthorName"
 git config user.email "$gitHubAuthorEmail"
 git remote add origin https://$ghUsername:$ghToken@github.com/$ghUsername/$projectName.git
 git add .
 git commit -a -m "initial commit for $projectName"
 #A crude way of waiting for GitHub to create the repo. This is horrible.
 sleep 10
 git push  -u origin master
 npm i
}

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
 read -e -p "Enter The Base Installation Directory (Ex: /opt|Default: /opt): " baseDirInput
 #Default variable if blank
 if [ "$baseDir" == "" ]
 then
  baseDir='/opt'
 fi
 #Validate the input and keep asking until it is correct.
 while [[ ! -d $baseDir ]]
 do
  read -e -p "Enter A Valid Directory (Ex: /opt): " baseDir
  #Default variable if blank
  if [ "$baseDir" == "" ]
  then
   baseDir='/opt'
  fi
 done

 do_system_dependencies
 do_git
 do_generate_nginx_conf
}

do_prompts
