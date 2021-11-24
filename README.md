# nodejs-boiler-plate
A script that creates the foundation for a Node.js App

## Download:
Put your self in the directory you would like this to run from using the cd command.
```
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install git gh
git clone https://github.com/treestarsystems/nodejs-boiler-plate.git
```
Once this has been cloned you can run "git pull" anytime and pull down updates of this script.

## Customizations:
Please open the script and edit the following defaults:  
gitHubAuthorName=Your Name  
gitHubAuthorEmail=Your Email

## Run:
Enter the directory and run the primer script. Just answer the questions.
```
./project-primer.sh
```
