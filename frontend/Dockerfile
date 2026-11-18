FROM nginx:alpine
COPY --chmod=0644 nginx.conf /etc/nginx/conf.d/default.conf
COPY --chmod=0644 index.html style.css app.js /usr/share/nginx/html/
