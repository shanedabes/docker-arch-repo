FROM golang:alpine AS build-env
ADD . /src
RUN cd /src && go build -o httpserver

# final stage
FROM alpine
WORKDIR /app
COPY --from=build-env /src/httpserver /app/
ENTRYPOINT ./httpserver
