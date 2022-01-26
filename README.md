# Docker

This repository contains some customized SQL Server Docker images.

## How to use it

The sqlpassion/sqlserver:2019-latest image acts as a base image for other images which will be released soon.

When you start up a container based on this image a backup of the `AdventureWorks2014` database is restored. You can access the container with the user "sa" and the password "passw0rd1!".

```shell
docker pull sqlpassion/sqlserver:2019-latest
docker run -p 1433:1433 --name sql2019 -d sqlpassion/sqlserver:2019-latest
```
