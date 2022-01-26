##########################################
# This file includes some helper commands
##########################################

# Builds the Docker image
docker image build -t sqlpassion/sqlserver:2019-latest .

# Shows the built image
docker image ls

# Runs a Docker container from the customized image
docker run -p 1433:1433 --name sql2019 -d sqlpassion/sqlserver:2019-latest

# Interactive shell
docker exec -it sql2019 /bin/bash

# Push the image to the Docker repository
docker push sqlpassion/sqlserver:2019-latest

# Download the customized image from the Docker repository
docker pull sqlpassion/sqlserver:2019-latest

# Clean up
docker stop sql2019
docker rm sql2019
docker image rm sqlpassion/sqlserver:2019-latest