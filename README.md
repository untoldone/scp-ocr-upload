## SCP/SFTP->OCR->Google Drive

This is a docker container that will accept a file uploaded via SCP/SFTP, will then run Tesseract OCR via OCRmyPDF, then will upload the results to a Google Drive folder via GDrive.

The original use case was to simplify the use of Brother scanners such as the Brother ASD-2700W. Scanners like these have a "one-touch" scan button which can scan to a local computer, a network share, an FTP site or an SFTP site. However, while Brother scanners ship with OCR software that can be used from the PC, the OCR software cannot be used by the "one-touch" scan button. Additionally, scanning requires a PC with drivers etc nearby.

This allows for the scanning of OCR-d PDFs via the "one-touch" scan functionality. It works by running an SSH server within a docker container, when a file is uploaded via SFTP to `/input`, the container will OCR and upload the resulting file to Google Drive.

### Setup

The container requires several environment variables:

* GDRIVE_AUTH_JSON: The JSON credentials of a GCP service account which owns a GDrive folder the resulting files will be uploaded to
* PARENT_FOLDER_ID: The programatic ID of the GDrive folder you will be uploading resulting files to
* SSH_ED25519_KEY: A SSH server's host ED25519 key
* SSH_RSA_KEY: A SSH server's host RSA key
* AUTHORIZED_KEY: Your SSH user's public key for authentication when uploading a file
* SSH_USERNAME (optional, default `ocr`): Your SSH username you will use to login with

#### Google Drive Setup

##### Create Service Account

This containers requires you setup a service account in Google Cloud Platform. You will first need a Google Cloud Platform account, then you can create a service account via the instructions at https://developers.google.com/identity/protocols/oauth2/service-account#creatinganaccount -- You don't need to grant the account any IAM permissions.

Once you have created the service account, click on that account in the GCP list of service accounts, and go to *Add Key*, then *Create New Key*, select *JSON* for the key type and click create. The contents of the JSON file will be used as your GDRIVE_AUTH_JSON environment variable and will also be used to setup a folder that can be shared.

##### Create Google Drive Folder

This process only supports Google Drive folders owned by service accounts (as opposed to normal google users). This describes how to create a folder for use here.

Get started by running `docker run -it --entrypoint bash untoldone/scp-ocr-upload:latest` -- this will put you in an environment with access to the `GDrive` command.

1. Run `mkdir -p /root/.gdrive`
2. Copy the contents of your GCP JSON credentials to `/root/.gdrive/creds.json`. It might be helpful to install a text editor of your choice to do this, e.g. `apt-get update; apt-get install -y vim`
3. Create a Google Drive directory you will share with your personal account via `gdrive --service-account creds.json mkdir Scans` (replace Scans with name of your choice)
4. Get Object ID via `gdrive --service-account creds.json list`. This should be saved and used for the `PARENT_FOLDER_ID` environment variable
5. Share the folder with your personal account via `gdrive --service-account creds.json share <Object ID from last step> --role writer --type user --email "<Your Gmail Email>"`

#### SSH Setup

You'll need to create two keys for your server to be passed in by environment variables. With a normal computer, this is generated for you, but since this is being run in a docker container, you must ensure they don't get lost if you upgrade the container in the future.

1. Get access to a machine with OpenSSH and `ssh-keygen` (or within the docker container used above for GDrive)
2. Generate a ssh_host_ed25519_key file via `ssh-keygen -t ed25519 -f ssh_host_ed25519_key -N ''`. The contents of the ssh_host_ed25519_key file will be used to set the SSH_ED25519_KEY environment variable
3. Generate a ssh_host_rsa_key file via `ssh-keygen -t rsa -b 4096 -f ssh_host_rsa_key -N ''`. The contents of the ssh_host_rsa_key file will be used to set the SSH_RSA_KEY environment variable
4. Pick an ssh public key for use for the authorized_keys file. This is what will be used to authenticate the user who is scp-ing pdf files. If you are using a Brother scanner, this may be downloaded at the Brother scanners admin website. If you are able to set your own public / private key -- you my generate one via `ssh-keygen` and then using the contents of the `~/.ssh/id_rsa.pub` file for the `AUTHORIZED_KEY` environment variable

#### Container Setup

This docker container exposes SFTP/ SSH on port 22. Run the container at an ip / url that your scanner or other device can reach over the network. The container expects input files to be SCP-d to `/input` on the container.

To test your setup, you can run:

    docker run -d --restart unless-stopped -p <SOME_EXTERNAL_PORT>:22 \
    	-e "SSH_USERNAME=brother" -e "AUTHORIZED_KEY=$(cat ~/.ssh/id_rsa.pub)" \
    	-e "GDRIVE_AUTH_JSON=$(cat ~/creds.json)" \
    	-e "PARENT_FOLDER_ID=<YOUR GDRIVE DIRECTORY OBJECT ID>" \
    	-e "SSH_ED25519_KEY=$(cat ~/ssh_host_ed25519_key)" \
    	-e "SSH_RSA_KEY=$(cat ~/ssh_host_rsa_key)" \
    	-it untoldone/scp-ocr-upload:latest

Once running, assuming you have your `~/.ssh/id_rsa` key added to your ssh-agent, you can run `scp -P <YOUR PORT> some_local_test_file.pdf brother@localhost:/input`. If everything's working correctly, you should see the file show up in the shared Google Drive folder within a few seconds assuming the pdf file isn't very big (allow longer for upload time otherwise).