FROM nginx:1.15-alpine
RUN apk add --no-cache curl
WORKDIR /usr/share/nginx/html/
COPY index.html .
EXPOSE 80
