docker image build -t sqlserverbase:latest .
docker image ls

docker run -p 1433:1433 --name sql2019_new -d sqlserverbase:latest

docker stop sql2019_new
docker rm sql2019_new
docker image rm sqlserverbase:latest